variable "resource_group_name" {
  default = "icornett-ae-workout-blog"
}

variable "location" {
  # North Central US — existing PostgreSQL/Key Vault location; SWA is pinned to centralus separately
  default = "northcentralus"
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

variable "cf_api_token" {
  description = "Cloudflare API token with DNS read/write access and zone read access"
  sensitive   = true
}
