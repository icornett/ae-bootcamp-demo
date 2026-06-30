# GitHub Copilot Instructions — workout-blog

## Repo Purpose

This workspace is centered on infrastructure and deployment automation for the `training-log` application.

- Infrastructure is defined in `infra/opentofu/azure/`.
- Deployment is orchestrated by `.github/workflows/deploy.yaml`.
- The application source is present in `blog/`.
- The API contract lives in `specs/openapi/blog-api.yaml`.

When working in this repository, treat infrastructure and deployment changes as the default concern unless the task explicitly targets files under `blog/`.

## Current Repository Layout

```text
workout-blog/
├── .github/
│   ├── agents/
│   ├── copilot-instructions.md
│   ├── memory/
│   └── workflows/
├── blog/
│   ├── .github/
│   ├── api/
│   ├── src/
│   ├── schema.sql
│   └── package.json
├── infra/
│   └── opentofu/
│       ├── azure/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── output.tf
│       │   └── .terraform.lock.hcl
│       └── vpn/
├── specs/
│   └── openapi/
│       └── blog-api.yaml
└── README.md
```

## Copilot Customizations In This Workspace

### Root-level agents

These agents are available in `.github/agents/` for the infrastructure workspace:

- `tdd-workflow.agent.md`
  Use for strict Red-Green-Refactor work on new features or failing tests.
- `copilot-customization.agent.md`
  Use for creating or updating Copilot instructions, agents, prompts, and related customization files.

### App-level agents

The application subtree in `blog/` has its own Copilot customizations under `blog/.github/`.
If the task is primarily about the web app or API code, check those app-specific agents and instructions before adding duplicate behavior at the root.

### Guidance for agent selection

- Use the root `tdd-workflow` agent when the task is test-driven and scoped to this repository.
- Use the root `copilot-customization` agent when editing Copilot customization files.
- Prefer root instructions for repo-wide guidance.
- Prefer `blog/.github/` customizations for tasks that are specific to the app subdirectory.

## Memory System

Repository memory for this workspace lives under `.github/memory/`.

Current committed memory files:

- `.github/memory/README.md`
- `.github/memory/patterns-discovered.md`
- `.github/memory/session-notes.md`

Scratch working notes live under `.github/memory/scratch/`.

Use this memory system as follows:

- Put durable repo-specific conventions in `patterns-discovered.md`.
- Put end-of-session summaries in `session-notes.md`.
- Put temporary working notes in `scratch/` when you need to track active findings.
- Keep this file focused on stable guidance, not session-specific notes.

## Infrastructure Stack

The currently deployed stack is defined by `infra/opentofu/azure/main.tf`.

- IaC: OpenTofu >= 1.6
- Providers: `hashicorp/azurerm ~> 3.90`, `hashicorp/random ~> 3.6`, `hashicorp/time ~> 0.11`, `cloudflare/cloudflare ~> 5.0`
- Frontend/API hosting: Azure Static Web App (Standard tier) with managed Azure Functions
- Database: Azure PostgreSQL Flexible Server 16
- Secrets: Azure Key Vault
- Private networking: Azure Private Endpoints + Private DNS zones for Key Vault and PostgreSQL
- Workflow-managed ephemeral Azure Container Instance SQL runner (Azure CLI) for one-off schema/init tasks
- Key Vault auth model: Azure RBAC with purge protection enabled
- Observability: Azure Application Insights backed by Azure Log Analytics Workspace
- DNS: Cloudflare CNAME record for the app domain

## Deployment Reality

Do not rely on older assumptions about ACI, Caddy, GHCR image polling, or image tags.
The current deployment flow is:

1. Validate the OpenAPI spec.
2. Run Checkov (`checkov-scan`) against `infra/opentofu/azure/` and publish SARIF.
3. Log in to Azure.
4. Run `tofu init` in `infra/opentofu/azure/`.
5. Apply infrastructure with custom domain enabled and `allow_azure_services_postgres=false`.
6. Wait for DNS propagation.
7. Seed schema (and PR test seed data) through a private Azure Container Instance SQL runner.
8. Deploy `blog/` and `blog/api/` with `Azure/static-web-apps-deploy@v1`.
9. Wait for Azure custom-domain status to become `Ready`.
10. Let the scheduled GDPR purge workflow call `/api/admin/purge-deleted-users` with the Key Vault-backed maintenance token.

Important current behavior:

- Cloudflare DNS is managed in OpenTofu.
- Custom domain binding is explicitly staged to avoid DNS propagation races.
- SWA deploy token is sourced from OpenTofu output `swa_api_key`.
- The GDPR purge cron reads `gdpr-maintenance-token` from Key Vault and calls the managed API endpoint directly.
- Checkov scan output is uploaded as SARIF for code scanning and as a build artifact.
- Some Checkov controls are intentionally skipped in Terraform with inline rationale for current CI/runtime constraints.
- PostgreSQL Azure-services firewall rule remains configurable (`allow_azure_services_postgres`) but should stay disabled for private-only connectivity.
- The SQL runner is created and destroyed from GitHub Actions with Azure CLI for schema and seed operations, so it does not need Terraform state entries.
- SQL runner executions use a digest-pinned image (`postgres:16-alpine@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416`) for immutable behavior.

## Working Conventions

### For infrastructure changes

- Make infrastructure edits in `infra/opentofu/azure/`.
- Keep changes minimal and aligned with current provider versions.
- Run `tofu validate` after editing the module.
- Run `checkov --framework terraform --directory infra/opentofu/azure --compact` before pushing infra changes.
- Use `tofu plan` for inspection when needed.
- Do not introduce Azure resources that contradict the current architecture without updating `README.md` and this file.

### For deployment changes

- Keep `.github/workflows/deploy.yaml` aligned with actual OpenTofu variables.
- When adding or removing required variables or secrets, update both `README.md` and this file.
- Keep the deploy flow aligned with the current single-pass apply plus post-apply health/validation gates.
- Keep `.github/workflows/purge-deleted-users.yaml` aligned with the Key Vault secret names and the managed API route.

### For application changes under `blog/`

- Expect app-specific guidance to live in `blog/.github/`.
- Avoid placing app-only instructions at the root unless they apply broadly across the whole workspace.

## Documentation Rules

When infrastructure shape changes, update the relevant documentation in the same change:

- `README.md` for human-facing infrastructure overview
- `.github/copilot-instructions.md` for Copilot-facing repo guidance
- `.github/memory/patterns-discovered.md` for durable implementation patterns when appropriate

Keep documentation current with:

- actual file paths
- actual deployed resources
- actual workflow inputs, secrets, and variables
- actual Copilot customization files present in the repo

## Safe Defaults For Copilot

- Assume infra work should start in `infra/opentofu/azure/` unless the user anchors elsewhere.
- Assume documentation changes should also touch `README.md` when user-facing behavior changes.
- Assume Copilot customization changes should inspect `.github/agents/`, `.github/memory/`, and any nearby `blog/.github/` files before editing.
- Do not describe deleted or legacy systems as if they are still active.

## Commands Commonly Used Here

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

Use these as inspection and validation commands. Production applies should go through GitHub Actions unless the user explicitly asks otherwise.
