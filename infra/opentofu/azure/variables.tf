variable "resource_group_name" {
  default = "icornett-ae-workout-blog"
}

variable "location" {
  # North Central US — existing PostgreSQL/Key Vault location; SWA is pinned to centralus separately
  default = "northcentralus"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for workspace-based Function telemetry"
  default     = 30
}

variable "pg_admin_login" {
  default = "pgadmin"
}

variable "pg_database_name" {
  default = "training_log"
}

variable "domain" {
  description = "Public hostname for the blog (managed as a proxied Cloudflare CNAME record to SWA)"
  default     = "gym.digitaldelirium.tech"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID that owns var.domain"
}

variable "cloudflare_proxied" {
  description = "Whether the Cloudflare CNAME should be proxied (default: true, disable only for initial domain validation)"
  default     = true
}

variable "enable_custom_domain" {
  description = "Whether to create the Azure Static Web App custom-domain binding"
  default     = true
}

variable "cf_api_token" {
  description = "Cloudflare API token with DNS read/write access and zone read access"
  sensitive   = true
}

variable "manage_blog_validation_record" {
  description = "Whether to manage the Cloudflare TXT record for SWA custom-domain TXT validation. Set to false once the custom domain is validated to stop unnecessary updates."
  type        = bool
  default     = true
}
