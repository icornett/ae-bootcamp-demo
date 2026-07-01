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

variable "key_vault_ci_object_id" {
  description = "Optional object ID for the CI/CD principal that needs Key Vault secret read permissions (for workflows such as purge token retrieval)."
  type        = string
  default     = null
}

variable "enable_user_assigned_identity" {
  description = "Create an optional user-assigned managed identity and grant Key Vault secret read access."
  type        = bool
  default     = false
}

variable "allow_azure_services_postgres" {
  description = "Adds the PostgreSQL 0.0.0.0/0.0.0.0 Azure-services firewall rule required for Azure Static Web App managed Functions (which cannot be VNet-integrated) to reach the server. Keep true while the API runs as SWA managed functions; disable only after migrating to a VNet-integrated compute option."
  type        = bool
  default     = false
}

variable "key_vault_rbac_wait_duration" {
  description = "Delay after Key Vault role assignments to allow RBAC propagation before secret reads/writes."
  type        = string
  default     = "30s"
}

variable "manage_key_vault_role_assignments" {
  description = "Whether Terraform should create/update Key Vault RBAC role assignments. Disable in CI when the deploy principal cannot manage role assignments."
  type        = bool
  default     = false
}

variable "bootstrap_runner_rbac" {
  description = "One-time bootstrap toggle: grant the GitHub deploy principal baseline RBAC using Terraform (run with elevated credentials)."
  type        = bool
  default     = false
}

variable "github_runner_object_id" {
  description = "Object ID of the GitHub Actions deploy service principal to bootstrap with RBAC permissions."
  type        = string
  default     = null
}