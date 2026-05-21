terraform {
  # OpenTofu >= 1.6 (the `terraform {}` block is valid in OpenTofu for backwards compatibility)
  required_version = ">= 1.6"

  backend "azurerm" {
    resource_group_name  = "tf-backend"
    storage_account_name = "icornettblogbackend"
    container_name       = "tfstate"
    key                  = "workout-blog.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = var.cf_api_token
}

# Auto-generated — never stored in CI secrets or tfvars
resource "random_password" "pg" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "backend" {
  name                = "icornettblogbackend"
  resource_group_name = "tf-backend"
}

data "azurerm_key_vault" "existing_main" {
  name                = "workout-kv-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name = var.resource_group_name
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_key_vault" "main" {
  name                       = "workout-kv-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "Set", "Delete", "List", "Purge"]
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "workout-pg-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = var.pg_admin_login
  administrator_password = random_password.pg.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
}

# "0.0.0.0" start+end = Allow Azure services (ACI, etc.) — SSL still enforced
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "training_log" {
  name      = var.pg_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  value        = "postgresql://${var.pg_admin_login}:${random_password.pg.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.pg_database_name}?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id

  tags = { managed-by = "terraform" }
}

resource "azurerm_key_vault_secret" "pg_password" {
  name         = "pg-admin-password"
  value        = random_password.pg.result
  key_vault_id = azurerm_key_vault.main.id

  tags = { managed-by = "terraform" }
}

# ── Caddy cert storage (persists certs across ACI restarts → avoids LE rate limits) ──
resource "azurerm_storage_account" "caddy" {
  name                     = "workoutcaddy${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "caddy_data" {
  name                 = "caddy-data"
  storage_account_name = azurerm_storage_account.caddy.name
  quota                = 1
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "workout-law-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
}

locals {
  # Written to /etc/caddy/Caddyfile at container startup via command override.
  # CF_API_TOKEN injected as env var so it never appears in logs or config files.
  caddyfile_content = <<-CADDYFILE
    ${var.domain} {
      tls ${var.acme_email} {
        dns cloudflare {env.CF_API_TOKEN}
      }
      reverse_proxy localhost:4567
    }
  CADDYFILE
}

# ── Azure Container Instance — Caddy sidecar + Sinatra app ────────────────────
resource "azurerm_container_group" "blog" {
  name                = "training-log"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ip_address_type     = "Public"
  dns_name_label      = "workout-blog-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  os_type             = "Linux"
  restart_policy      = "Always"

  diagnostics {
    log_analytics {
      workspace_id  = azurerm_log_analytics_workspace.main.workspace_id
      workspace_key = azurerm_log_analytics_workspace.main.primary_shared_key
      log_type      = "ContainerInsights"
    }
  }

  image_registry_credential {
    server   = "ghcr.io"
    username = "icornett"
    password = var.ghcr_pat
  }

  # Caddy sidecar — terminates TLS via Let's Encrypt DNS-01 (Cloudflare), proxies to Sinatra
  # ghcr.io/caddy-dns/cloudflare includes the Cloudflare ACME DNS plugin
  container {
    name   = "caddy"
    image  = "ghcr.io/caddy-dns/cloudflare:latest"
    cpu    = "0.25"
    memory = "0.3"

    ports {
      port     = 443
      protocol = "TCP"
    }

    # Port 80 for HTTP→HTTPS redirect (Caddy handles this automatically)
    ports {
      port     = 80
      protocol = "TCP"
    }

    # Write Caddyfile from env var at startup, then start Caddy
    commands = ["/bin/sh", "-c", "printf '%s' \"$CADDYFILE\" > /etc/caddy/Caddyfile && caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"]

    environment_variables = {
      CADDYFILE = local.caddyfile_content
    }

    secure_environment_variables = {
      CF_API_TOKEN = var.cf_api_token
    }

    # Persist ACME certs/keys — prevents LE rate-limit hits on container restart
    volume {
      name                 = "caddy-data"
      mount_path           = "/data"
      share_name           = azurerm_storage_share.caddy_data.name
      storage_account_name = azurerm_storage_account.caddy.name
      storage_account_key  = azurerm_storage_account.caddy.primary_access_key
    }
  }

  # Sinatra app — listens on localhost:4567, not exposed publicly
  container {
    name   = "training-log"
    image  = "ghcr.io/icornett/training-log:${var.image_tag}"
    cpu    = "0.25"
    memory = "0.5"

    environment_variables = {
      RACK_ENV = "production"
      PORT     = "4567"
    }

    secure_environment_variables = {
      DATABASE_URL = azurerm_key_vault_secret.database_url.value
    }
  }
}

resource "cloudflare_dns_record" "blog" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "A"
  ttl     = 1
  content = azurerm_container_group.blog.ip_address
  proxied = true
  comment = "Managed by OpenTofu for the training-log origin"
}
