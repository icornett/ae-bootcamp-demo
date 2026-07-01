# workout-blog Infrastructure

This repository contains the infrastructure and deployment automation for the `training-log` app.

- Frontend: Vite/React static site in `blog/`
- API: Azure Functions v4 (TypeScript) in `blog/api/`
- Infrastructure: OpenTofu in `infra/opentofu/azure/`
- Deployment: GitHub Actions in `.github/workflows/deploy.yaml`

## What gets deployed

The OpenTofu module provisions:

- Azure Resource Group
- Azure Key Vault
- Azure PostgreSQL Flexible Server (plus DB and optional Azure-services firewall rule)
- Azure Log Analytics Workspace
- Azure Application Insights (workspace-based)
- Azure Static Web App (Standard tier) hosting the SPA and managed Functions
- Cloudflare CNAME record for the public hostname
- Optional SWA custom-domain binding (controlled by variable)

## Runtime architecture

```text
Internet
  -> Cloudflare DNS / proxy
    -> Azure Static Web App
      -> Managed Azure Functions (blog/api)
        -> Azure PostgreSQL Flexible Server

Observability:
Managed Functions -> Application Insights -> Log Analytics Workspace
```

## Security posture

- PostgreSQL is treated as private data-plane infrastructure; CI and deploy flows keep `allow_azure_services_postgres=false`.
- Schema and seed SQL run inside a private Azure Container Instance attached to the delegated `sql-runner` subnet, rather than from the public GitHub-hosted runner network path.
- GitHub-hosted runners use Azure control-plane APIs only (create/poll/log/delete container group) and do not require direct PostgreSQL network reachability.
- SQL runner image is pinned by digest (`postgres:16-alpine@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416`) so CI behavior is immutable and auditable across runs.
- Ephemeral SQL runners are workflow-managed and deleted after execution to minimize long-lived attack surface and Terraform state churn.

## Module location

- Infrastructure code: `infra/opentofu/azure/`
- Deployment workflow: `.github/workflows/deploy.yaml`
- Application code: `blog/`
- API contract: `specs/openapi/blog-api.yaml`

## OpenTofu variables

| Variable | Default | Required | Purpose |
| --- | --- | --- | --- |
| `resource_group_name` | `icornett-ae-workout-blog` | No | Azure resource group name |
| `location` | `northcentralus` | No | Azure region for RG, PostgreSQL, Key Vault, and monitoring resources |
| `log_analytics_retention_days` | `30` | No | Log retention for workspace-based telemetry |
| `pg_admin_login` | `pgadmin` | No | PostgreSQL admin username |
| `pg_database_name` | `training_log` | No | PostgreSQL database name |
| `domain` | `gym.digitaldelirium.tech` | No | Public hostname managed in Cloudflare |
| `cloudflare_zone_id` | none | Yes | Cloudflare zone ID containing `domain` |
| `cloudflare_proxied` | `true` | No | Whether Cloudflare proxy is enabled for the CNAME |
| `enable_custom_domain` | `true` | No | Whether Azure SWA custom-domain binding is created |
| `cf_api_token` | none | Yes | Cloudflare API token with DNS read/write + zone read |
| `manage_blog_validation_record` | `true` | No | Whether OpenTofu manages the SWA TXT validation record in Cloudflare |
| `allow_azure_services_postgres` | `false` | No | Keeps/removes PostgreSQL `0.0.0.0` Azure-services firewall rule (recommended: keep disabled for private-only connectivity) |
| `enable_user_assigned_identity` | `false` | No | Create an optional user-assigned managed identity with Key Vault secret read rights |
| `key_vault_ci_object_id` | `null` | No | Optional CI/CD principal object ID to grant Key Vault secret read access |
| `key_vault_rbac_wait_duration` | `30s` | No | RBAC propagation delay before Key Vault secret reads/writes |
| `manage_key_vault_role_assignments` | `false` | No | Whether OpenTofu creates/updates Key Vault RBAC role assignments (requires `Microsoft.Authorization/roleAssignments/write`) |
| `bootstrap_runner_rbac` | `false` | No | One-time pure-IaC bootstrap toggle that grants baseline RBAC to the GitHub deploy principal |
| `github_runner_object_id` | `null` | No | Object ID of the GitHub deploy service principal used when `bootstrap_runner_rbac=true` |

Sensitive inputs:

- `cf_api_token`

## OpenTofu outputs

| Output | Description |
| --- | --- |
| `swa_default_hostname` | SWA origin hostname used by Cloudflare CNAME |
| `swa_name` | Static Web App resource name |
| `resource_group_name` | Resource group used by the deployment |
| `swa_api_key` | SWA deployment token used by GitHub Actions |
| `cloudflare_record_hostname` | Public hostname managed by Cloudflare |
| `pg_server_fqdn` | PostgreSQL server FQDN |
| `key_vault_name` | Key Vault storing `database-url`, `pg-admin-password`, `session-secret`, and `gdpr-maintenance-token` |
| `swa_principal_id` | Static Web App system-assigned managed identity principal ID |
| `application_insights_name` | App Insights resource collecting Functions telemetry |
| `application_insights_connection_string` | Connection string injected into managed Functions |
| `log_analytics_workspace_id` | Workspace ID backing App Insights |
| `runtime_user_assigned_identity_id` | Optional user-assigned managed identity resource ID |
| `runtime_user_assigned_identity_principal_id` | Optional user-assigned managed identity principal ID |

## GitHub Actions deployment

Production deployment is handled by `.github/workflows/deploy.yaml`.

Workflow behavior:

- Pull requests and pushes run OpenAPI validation.
- Pull requests run `tofu plan` with domain/proxy creation disabled.
- Pull requests from the same repository also deploy to the Azure Static Web Apps preview environment.
- Pull requests from the same repository also seed a dedicated Playwright user in PostgreSQL and run real-database Playwright journeys against the preview URL.
- Real-database test results (videos, screenshots, traces) are published as artifacts for inspection.
- PR preview, real-db E2E, and `main` deploy jobs refresh the `blog` submodule to the latest `main` revision before building and deploying.
- `repository_dispatch` events of type `training-log-release` create/update a release PR and enable auto-merge.
- Pushes to `main` run a single OpenTofu apply with private-only PostgreSQL access, followed by DNS wait, private SQL runner seeding, and SWA deployment.
- A dedicated scheduled workflow calls the GDPR purge endpoint daily to hard-delete users whose deletion retention window has expired.

SQL runner behavior (private-only path):

1. PR real-db E2E always uses a private Azure Container Instance SQL runner to apply schema and test seed data.
2. Main deploy always uses the same private SQL runner path to apply schema updates.
3. GitHub-hosted runners interact only with Azure control-plane APIs; no public SQL endpoint is required.
4. The SQL runner uses a digest-pinned image (`postgres:16-alpine@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416`) for immutable supply-chain behavior.
5. The SQL runner is intentionally workflow-managed so it does not create Terraform state churn.

Main deploy phases:

- Single Terraform apply with `enable_custom_domain=true`, `cloudflare_proxied=true` (enabled by default), `allow_azure_services_postgres=false`, `manage_blog_validation_record=false`, and `manage_key_vault_role_assignments=true`.
- Pre-apply RBAC fail-fast gate verifies the deploy principal has `User Access Administrator` (or `Owner`) on the resource group and `Key Vault Secrets Officer` on the Key Vault.
- Wait for DNS propagation (`dig` CNAME check).
- Apply PostgreSQL schema through a private SQL runner ACI.
- Build the Vite app in GitHub Actions with Node 24.
- Deploy the prebuilt static site plus Functions using `Azure/static-web-apps-deploy@v1` with app build skipping enabled.
- Wait for Azure custom-domain binding to reach `Ready` state (handles TXT validation automatically).
- Purge Cloudflare cache via API to serve fresh content.

Preview environment notes:

- PR deploys go to the SWA preview environment created by `Azure/static-web-apps-deploy@v1`.
- Preview environments do not support custom domains, so use the autogenerated SWA preview URL for testing.
- The preview deploy uses the same app and API build steps as production, but it does not publish Cloudflare DNS changes.
- Preview environments are closed automatically when a PR is closed, including merged PRs.

Database seeding behavior:

1. Read `key_vault_name` from OpenTofu output.
2. Read `database-url` from Key Vault.
3. Launch private ACI SQL runner in the delegated `sql-runner` subnet.
4. Run SQL with the digest-pinned SQL runner image for immutable execution.
5. Apply `blog/schema.sql` (plus E2E seed SQL in PR real-db lane), then delete the container group.

Scheduled purge behavior:

1. GitHub Actions runs `.github/workflows/purge-deleted-users.yaml` on a daily cron and on manual dispatch.
2. The workflow reads the deployed hostname from OpenTofu remote state.
3. The workflow reads `gdpr-maintenance-token` from Key Vault.
4. The workflow `POST`s to `/api/admin/purge-deleted-users` with the maintenance header expected by the Azure Function.
5. The run summary records how many soft-deleted users were purged and the retention cutoff used for the run.

## Required GitHub secrets

- `AZURE_CREDENTIALS`
- `AZURE_CLIENT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_SECRET`
- `CF_API_TOKEN`
- `CF_ZONE_ID`

## Infracost diagnostics note

- Workspace setting `.vscode/settings.json` currently sets `infracost.enableDiagnostics=false`.
- Reason: the Infracost VS Code extension exposes one diagnostics toggle for both FinOps and tag policy findings; it does not provide a tag-only suppression switch.
- Our Terraform tagging is enforced through shared locals (`local.common_tags`), so inline Infracost tag diagnostics were disabled to avoid duplicate/noisy findings.
- To re-enable Infracost diagnostics later, set `infracost.enableDiagnostics` back to `true` in `.vscode/settings.json`.

## Local commands

Useful commands when working on the infrastructure module:

```bash
cd infra/opentofu/azure
tofu init -backend=false
tofu validate
tofu plan \
  -var="cf_api_token=$CF_API_TOKEN" \
  -var="cloudflare_zone_id=$CF_ZONE_ID" \
  -var="cloudflare_proxied=false" \
  -var="enable_custom_domain=false"
```

Use `tofu plan` for inspection. Production applies are intended to go through GitHub Actions.

## Pure-IaC RBAC bootstrap (one-time)

To avoid manual Azure CLI permission grants, run a one-time elevated Terraform apply that bootstraps the GitHub deploy principal:

```bash
cd infra/opentofu/azure
tofu apply \
  -var="bootstrap_runner_rbac=true" \
  -var="github_runner_object_id=<github-deploy-sp-object-id>" \
  -var="manage_key_vault_role_assignments=true" \
  -var="key_vault_ci_object_id=<github-deploy-sp-object-id>" \
  -var="cf_api_token=$CF_API_TOKEN" \
  -var="cloudflare_zone_id=$CF_ZONE_ID"
```

After bootstrap, set `bootstrap_runner_rbac=false` (default) for normal runs.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yaml
├── blog/
│   ├── api/
│   ├── src/
│   ├── schema.sql
│   └── package.json
├── infra/
│   └── opentofu/
│       └── azure/
│           ├── main.tf
│           ├── variables.tf
│           ├── output.tf
│           └── .terraform.lock.hcl
└── specs/
    └── openapi/
        └── blog-api.yaml
```
