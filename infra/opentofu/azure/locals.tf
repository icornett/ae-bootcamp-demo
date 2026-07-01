locals {
  common_tags = {
    Service     = "workout-blog"
    Environment = "Prod"
  }

  # Keep a stable one-year secret expiry window anchored at first apply.
  key_vault_secret_expiration = timeadd(time_static.secret_expiry_anchor.rfc3339, "8760h")

  # System-assigned identity can be absent during planning; guard indexing.
  swa_principal_id = try(azurerm_static_web_app.main.identity[0].principal_id, null)
}
