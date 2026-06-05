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

resource "random_password" "session_secret" {
  length  = 48
  special = false
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

# "0.0.0.0" start+end = Allow Azure services (SWA Functions, etc.) — SSL still enforced
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

resource "azurerm_key_vault_secret" "session_secret" {
  name         = "session-secret"
  value        = random_password.session_secret.result
  key_vault_id = azurerm_key_vault.main.id

  tags = { managed-by = "terraform" }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "workout-law-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
}

resource "azurerm_application_insights" "functions" {
  name                = "workout-ai-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
}

# ── Azure Static Web App — React/Vite SPA + managed Azure Functions v4 API ───
# Location must be one of the SWA-supported regions; northcentralus is not supported.
resource "azurerm_static_web_app" "main" {
  name                = "workout-swa-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "centralus"
  sku_tier            = "Standard"
  sku_size            = "Standard"

  # Injected into managed Functions at runtime
  app_settings = {
    DATABASE_URL                          = azurerm_key_vault_secret.database_url.value
    SESSION_SECRET                        = random_password.session_secret.result
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.functions.connection_string
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.functions.instrumentation_key
  }
}

resource "azurerm_static_web_app_custom_domain" "blog" {
  count             = var.enable_custom_domain ? 1 : 0
  static_web_app_id = azurerm_static_web_app.main.id
  domain_name       = var.domain
  validation_type   = "dns-txt-token"
}

# Cloudflare CNAME → SWA default hostname.
# Keep this DNS-only until Azure custom-domain validation completes.
resource "cloudflare_dns_record" "blog" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "CNAME"
  ttl     = 1
  content = azurerm_static_web_app.main.default_host_name
  proxied = var.cloudflare_proxied
  comment = "Managed by OpenTofu — CNAME for SWA custom-domain routing"
}

# Azure returns a domain verification token for SWA custom-domain binding.
# Publish it in Cloudflare to automate TXT-based domain validation.
resource "cloudflare_dns_record" "blog_validation" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = split(".", var.domain)[0]
  type    = "TXT"
  ttl     = 1
  content = "${azurerm_static_web_app_custom_domain.blog[0].validation_token}"
  comment = "Managed by OpenTofu — SWA custom-domain TXT validation token"
}
