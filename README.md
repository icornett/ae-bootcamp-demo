# workout-blog Infrastructure

This repository contains the infrastructure and deployment automation for the `training-log` Ruby/Sinatra application. The application code lives in `blog/`, while the production infrastructure is defined in `infra/opentofu/azure/` and deployed through GitHub Actions.

## What gets deployed

The OpenTofu module in `infra/opentofu/azure/` provisions the following resources:

- Azure Resource Group
- Azure Key Vault
- Azure PostgreSQL Flexible Server
- Azure PostgreSQL firewall rule allowing Azure-hosted clients
- Azure PostgreSQL database named `training_log`
- Azure Storage Account for Caddy state
- Azure File Share mounted at `/data` for persisted certificates
- Azure Container Instance container group named `training-log`
- `caddy` sidecar container for TLS termination and reverse proxying
- `training-log` application container pulled from `ghcr.io/icornett/training-log`
- Cloudflare proxied `A` record pointing the public hostname at the ACI public IP

## Runtime architecture

```text
Internet
  -> Cloudflare proxied DNS record
    -> Azure Container Instance public IP
      -> caddy container
        -> localhost:4567
          -> training-log container
            -> Azure PostgreSQL Flexible Server
```

Notes:

- Caddy obtains certificates from Let's Encrypt using the Cloudflare DNS challenge.
- Cloudflare also manages the public DNS record for the application hostname.
- The application container receives `DATABASE_URL` via a secure environment variable.
- PostgreSQL credentials are generated during apply and stored in Key Vault.
- The application image tag is configurable, so deploys can use `latest`, a commit SHA, or any other published tag.

## Module location

- Infrastructure code: `infra/opentofu/azure/`
- Deployment workflow: `.github/workflows/deploy.yaml`
- Application code: `blog/`
- API contract: `specs/openapi/blog-api.yaml`

## OpenTofu variables

The Azure module currently accepts these inputs:

| Variable | Default | Required | Purpose |
| --- | --- | --- | --- |
| `resource_group_name` | `icornett-ae-workout-blog` | No | Azure resource group name |
| `location` | `northcentralus` | No | Azure region for all deployed resources |
| `ghcr_pat` | none | Yes | GitHub token with `read:packages` so ACI can pull from GHCR |
| `pg_admin_login` | `pgadmin` | No | PostgreSQL admin username |
| `pg_database_name` | `training_log` | No | PostgreSQL database name |
| `image_tag` | `latest` | No | Container tag to deploy from `ghcr.io/icornett/training-log` |
| `domain` | `gym.digitaldelirium.tech` | No | Public hostname managed in Cloudflare |
| `cloudflare_zone_id` | none | Yes | Cloudflare zone ID for `domain` |
| `acme_email` | none | Yes | Email used for Let's Encrypt ACME registration |
| `cf_api_token` | none | Yes | Cloudflare API token with DNS read/write and zone read permissions |

Sensitive inputs:

- `ghcr_pat`
- `cf_api_token`

## OpenTofu outputs

After apply, the module exposes these outputs:

| Output | Description |
| --- | --- |
| `aci_fqdn` | Azure Container Instance FQDN backing the deployment |
| `aci_public_ip` | Origin IP used by the Cloudflare DNS record |
| `cloudflare_record_hostname` | Hostname managed by Cloudflare |
| `pg_server_fqdn` | PostgreSQL server FQDN |
| `image_repository` | Image repository, currently `ghcr.io/icornett/training-log` |
| `key_vault_name` | Azure Key Vault name storing generated secrets |

## GitHub Actions deployment

Production deployment is handled by `.github/workflows/deploy.yaml`.

Workflow behavior:

- Pull requests and pushes run OpenAPI validation.
- Pushes to `main` run the deploy job.
- `workflow_dispatch` can manually trigger a deployment with an optional `image_tag` input.
- After `tofu apply`, deployment installs `postgresql-client` and runs `blog/schema.sql` only if the `users` table is not present.

Required GitHub secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `GHCR_PAT`
- `CF_API_TOKEN`
- `CF_ZONE_ID`

Required GitHub variables:

- `ACME_EMAIL`

Optional GitHub variables:

- `DEPLOY_IMAGE_TAG`

Image tag selection order in the workflow:

1. `workflow_dispatch` input `image_tag`
2. Repository variable `DEPLOY_IMAGE_TAG`
3. `github.sha`

This lets you keep the environment pinned to `latest`, move to a release tag, or deploy a one-off SHA without editing the Tofu module.

Database seeding behavior:

1. Read `key_vault_name` from OpenTofu output.
2. Read `database-url` from Key Vault.
3. Check `to_regclass('public.users')`.
4. Run `blog/schema.sql` only when the schema is missing.

This protects deploys from re-running non-idempotent seed inserts on every release.

## GHCR latest change hooks

There are now two ways this repository detects GHCR latest digest changes:

- Local Git hook: `.githooks/pre-push` runs `scripts/check-ghcr-latest-digest.sh` and reports whether `ghcr.io/icornett/training-log:latest` changed since the last push.
- ACI automation hook: `.github/workflows/aci-refresh-on-ghcr-latest.yaml` runs every 15 minutes (and on manual trigger), detects digest changes, and restarts the `training-log` ACI container group when a new digest is published.

Local setup:

```bash
./bin/setup-hooks
```

Hook state is stored in `.git/ghcr/latest.digest`.

## Local commands

Useful commands when working on the infrastructure module:

```bash
cd infra/opentofu/azure
tofu init -backend=false
tofu validate
tofu plan \
  -var="ghcr_pat=$GHCR_PAT" \
  -var="cf_api_token=$CF_API_TOKEN" \
  -var="cloudflare_zone_id=$CF_ZONE_ID" \
  -var="acme_email=$ACME_EMAIL"
```

Use `tofu plan` for inspection. Production applies are intended to go through GitHub Actions.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yaml
├── blog/
│   ├── workouts.rb
│   ├── schema.sql
│   └── README.md
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

## Current deployment assumptions

- The application image is pulled directly from GHCR, not Azure Container Registry.
- The Azure container group is public, but all browser traffic is intended to flow through Cloudflare.
- SSL termination happens in the `caddy` sidecar, not in the app container.
- The container group runs two containers in a single ACI group: `caddy` and `training-log`.
- The current state backend is local unless you explicitly configure a remote backend.
