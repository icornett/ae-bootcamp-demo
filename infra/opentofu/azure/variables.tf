variable "resource_group_name" {
  default = "icornett-ae-workout-blog"
}

variable "location" {
  # North Central US: cheapest D2ls_v5 spot (~$0.016/hr) — Cloudflare masks origin latency
  default = "northcentralus"
}

variable "ghcr_pat" {
  description = "GitHub PAT with read:packages scope — used by ACI to pull the private GHCR image"
  sensitive   = true
}

variable "pg_admin_login" {
  default = "pgadmin"
}

variable "pg_database_name" {
  default = "training_log"
}

variable "image_tag" {
  description = "Docker image tag to deploy — defaults to latest, but CI can pin any published tag"
  default     = "latest"
}

variable "domain" {
  description = "Public hostname for the blog (managed as a proxied Cloudflare A record)"
  default     = "gym.digitaldelirium.tech"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID that owns var.domain"
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME registration"
}

variable "cf_api_token" {
  description = "Cloudflare API token with DNS read/write access and zone read access"
  sensitive   = true
}
