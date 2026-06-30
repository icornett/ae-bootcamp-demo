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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
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

resource "random_password" "gdpr_maintenance_token" {
  length  = 48
  special = false
}

data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "backend" {
  name                = "icornettblogbackend"
  resource_group_name = "tf-backend"
}

resource "time_static" "secret_expiry_anchor" {}

data "azurerm_key_vault" "existing_main" {
  name                = "workout-kv-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name = var.resource_group_name
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Private endpoint network for data-plane resources.
resource "azurerm_virtual_network" "private_endpoints" {
  name                = "workout-vnet-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.60.0.0/16"]

  tags = local.common_tags
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.private_endpoints.name
  address_prefixes     = ["10.60.1.0/24"]
}

resource "azurerm_subnet" "sql_runner" {
  name                 = "sql-runner"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.private_endpoints.name
  address_prefixes     = ["10.60.2.0/24"]

  delegation {
    name = "aci-delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "private_subnets" {
  name                = "workout-private-subnets-nsg-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_subnets.id
}

resource "azurerm_subnet_network_security_group_association" "sql_runner" {
  subnet_id                 = azurerm_subnet.sql_runner.id
  network_security_group_id = azurerm_network_security_group.private_subnets.id
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "workout-kv-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.private_endpoints.id

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "workout-pg-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.private_endpoints.id

  tags = local.common_tags
}

resource "azurerm_key_vault" "main" {
  #checkov:skip=CKV_AZURE_189: Public network access remains required for GitHub-hosted runners and SWA-managed functions; private endpoints are added for controlled private connectivity paths.
  #checkov:skip=CKV_AZURE_109: Firewall/network ACL restrictions are intentionally deferred to keep CI and managed runtime secret retrieval working.
  name                       = "workout-kv-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  tags = local.common_tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  #checkov:skip=CKV_AZURE_136: Geo-redundant backups are disabled intentionally to control staging/dev costs.
  name                   = "workout-pg-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = var.pg_admin_login
  administrator_password = random_password.pg.result
  storage_mb             = 32768
  auto_grow_enabled      = true
  sku_name               = "B_Standard_B1ms"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "workout-kv-pe-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "workout-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "postgresql" {
  name                = "workout-pg-pe-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "workout-pg-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.main.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgresql.id]
  }

  tags = local.common_tags
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  #checkov:skip=CKV2_AZURE_26: This rule is disabled by default and only exists as explicit break-glass access; private endpoint connectivity is the secure default.
  count            = var.allow_azure_services_postgres ? 1 : 0
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_user_assigned_identity" "runtime" {
  count               = var.enable_user_assigned_identity ? 1 : 0
  name                = "workout-uai-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_role_assignment" "key_vault_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "key_vault_ci" {
  count                = var.key_vault_ci_object_id != null ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.key_vault_ci_object_id
}

resource "time_sleep" "key_vault_rbac_propagation" {
  create_duration = var.key_vault_rbac_wait_duration

  depends_on = [
    azurerm_role_assignment.key_vault_deployer,
    azurerm_role_assignment.key_vault_ci,
  ]
}

resource "azurerm_postgresql_flexible_server_database" "training_log" {
  name      = var.pg_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_key_vault_secret" "database_url" {
  name            = "database-url"
  value           = "postgresql://${var.pg_admin_login}:${random_password.pg.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.pg_database_name}?sslmode=require"
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "application/x-postgresql-connection-string"
  expiration_date = local.key_vault_secret_expiration

  tags = merge(local.common_tags, { managed-by = "opentofu" })

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "pg_password" {
  name            = "pg-admin-password"
  value           = random_password.pg.result
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = local.key_vault_secret_expiration

  tags = merge(local.common_tags, { managed-by = "opentofu" })

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "session_secret" {
  name            = "session-secret"
  value           = random_password.session_secret.result
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = local.key_vault_secret_expiration

  tags = merge(local.common_tags, { managed-by = "opentofu" })

  depends_on = [time_sleep.key_vault_rbac_propagation]
}


resource "azurerm_key_vault_secret" "gdpr_maintenance_token" {
  name            = "gdpr-maintenance-token"
  value           = random_password.gdpr_maintenance_token.result
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = local.key_vault_secret_expiration

  tags = merge(local.common_tags, { managed-by = "opentofu" })

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "workout-law-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = local.common_tags
}

resource "azurerm_application_insights" "functions" {
  name                       = "workout-ai-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  application_type           = "web"
  internet_ingestion_enabled = true
  internet_query_enabled     = true
  workspace_id               = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags
}

# ── Azure Static Web App — React/Vite SPA + managed Azure Functions v4 API ───
# Location must be one of the SWA-supported regions; northcentralus is not supported.
resource "azurerm_static_web_app" "main" {
  name                = "workout-swa-${substr(data.azurerm_client_config.current.subscription_id, 0, 8)}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "centralus"
  sku_tier            = "Standard"
  sku_size            = "Standard"

  identity {
    type = "SystemAssigned"
  }

  # Injected into managed Functions at runtime
  app_settings = {
    DATABASE_URL                          = azurerm_key_vault_secret.database_url.value
    SESSION_SECRET                        = random_password.session_secret.result
    GDPR_MAINTENANCE_TOKEN                = azurerm_key_vault_secret.gdpr_maintenance_token.value
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.functions.connection_string
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.functions.instrumentation_key
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "key_vault_swa" {
  count                = azurerm_static_web_app.main.identity[0].principal_id != null ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_static_web_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "key_vault_uai" {
  count                = var.enable_user_assigned_identity ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.runtime[0].principal_id
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
  count   = var.enable_custom_domain && var.manage_blog_validation_record ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = split(".", var.domain)[0]
  type    = "TXT"
  ttl     = 60
  content = azurerm_static_web_app_custom_domain.blog[0].validation_token
  comment = "Managed by OpenTofu — SWA custom-domain TXT validation token"
}
