# ── Outputs ───────────────────────────────────────────────────────────────────
output "swa_default_hostname" {
  value       = azurerm_static_web_app.main.default_host_name
  description = "SWA origin hostname — used as the Cloudflare CNAME target"
}

output "swa_name" {
  value       = azurerm_static_web_app.main.name
  description = "Static Web App resource name"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Primary resource group name"
}

output "swa_api_key" {
  value       = azurerm_static_web_app.main.api_key
  sensitive   = true
  description = "SWA deployment token — passed to the GitHub Actions SWA deploy action"
}

output "cloudflare_record_hostname" {
  value       = cloudflare_dns_record.blog.name
  description = "Cloudflare DNS hostname managed by OpenTofu"
}

output "cloudflare_dns_record_id" {
  value       = cloudflare_dns_record.blog.id
  description = "Cloudflare DNS record ID — used by Cloudflare API calls in CI/CD"
}

output "pg_server_fqdn" {
  value       = azurerm_postgresql_flexible_server.main.fqdn
  description = "PostgreSQL public FQDN — initialize schema with schema.sql after first apply"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault storing DATABASE_URL and SESSION_SECRET"
}

output "application_insights_name" {
  value       = azurerm_application_insights.functions.name
  description = "Application Insights resource collecting managed Functions telemetry"
}

output "application_insights_connection_string" {
  value       = azurerm_application_insights.functions.connection_string
  sensitive   = true
  description = "Connection string injected into SWA Functions runtime"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.workspace_id
  description = "Workspace ID backing Application Insights for log queries"
}
