# ── Outputs ───────────────────────────────────────────────────────────────────
output "aci_fqdn" {
  value       = azurerm_container_group.blog.fqdn
  description = "ACI public FQDN backing the Cloudflare-managed hostname"
}

output "aci_public_ip" {
  value       = azurerm_container_group.blog.ip_address
  description = "Origin IP used by the Cloudflare DNS record"
}

output "cloudflare_record_hostname" {
  value       = cloudflare_dns_record.blog.name
  description = "Cloudflare DNS hostname managed by OpenTofu"
}

output "pg_server_fqdn" {
  value       = azurerm_postgresql_flexible_server.main.fqdn
  description = "PostgreSQL public FQDN — initialize schema with schema.sql after first apply"
}

output "image_repository" {
  value       = "ghcr.io/icornett/training-log"
  description = "GHCR image repository — pull with a PAT that has read:packages scope"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault storing DATABASE_URL"
}
