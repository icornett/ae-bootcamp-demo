locals {
  common_tags = {
    Service     = "workout-blog"
    Environment = "Prod"
  }

  # Keep a stable one-year secret expiry window anchored at first apply.
  key_vault_secret_expiration = timeadd(time_static.secret_expiry_anchor.rfc3339, "8760h")
}
