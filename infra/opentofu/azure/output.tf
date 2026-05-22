# ── Outputs ───────────────────────────────────────────────────────────────────
output "swa_default_hostname" {
  value       = azurerm_static_web_app.main.default_host_name
  description = "SWA origin hostname — used as the Cloudflare CNAME target"
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

output "pg_server_fqdn" {
  value       = azurerm_postgresql_flexible_server.main.fqdn
  description = "PostgreSQL public FQDN — initialize schema with schema.sql after first apply"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault storing DATABASE_URL and SESSION_SECRET"
}
