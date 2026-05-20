# ── Outputs ───────────────────────────────────────────────────────────────────
output "aci_fqdn" {
  value       = azurerm_container_group.blog.fqdn
  description = "ACI public FQDN — set Cloudflare DNS A record to its IP, proxy enabled, SSL Full (Strict)"
}

output "aci_public_ip" {
  value       = azurerm_container_group.blog.ip_address
  description = "Point Cloudflare DNS A record for gym.digitaldelirium.tech at this IP"
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
