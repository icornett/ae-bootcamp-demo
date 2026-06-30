# Patterns Discovered

Capture recurring implementation patterns and keep them updated over time.

## Pattern Template

### Pattern: [name]

Context:

- Where this pattern appears.

Problem:

- What issue this pattern solves.

Solution:

- Preferred approach.

Example:

```text
Add a concise example snippet or command sequence.
```

Related files:

- path/to/file
- path/to/another-file

---

## Example Pattern

### Pattern: Service initialization (empty array vs null)

Context:

- Service state initialization in app startup and test setup.

Problem:

- `null` initialization forces repeated nil checks and can cause runtime errors when consumers expect iterable collections.

Solution:

- Initialize list-like service state with an empty array to guarantee safe iteration and predictable defaults.

Example:

```ruby
# Preferred
service.items = []

# Avoid unless explicitly modeling absence
service.items = nil
```

Related files:

- blog/workouts.rb
- blog/spec/unit

---

### Pattern: Workflow-managed ephemeral SQL runner

Context:

- PR real-db validation and main deploy schema application.

Problem:

- Terraform-managed throwaway ACI resources create state churn and complicate cleanup for a short-lived seeding job.

Solution:

- Use GitHub Actions with Azure CLI to create a private Azure Container Instance for schema and seed execution.
- Feed schema and seed SQL into the container as base64-encoded environment variables, run the seed inside the container, then delete the container group in the same job.
- Pin the SQL runner image by digest to guarantee immutable execution semantics across runs.
- Keep the durable network resources in Terraform, but keep the ephemeral runner lifecycle in the workflow.

Example:

```bash
az container create ... --image "postgres:16-alpine@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416" --command-line "$SEED_COMMAND" \
    --secure-environment-variables DATABASE_URL="$DATABASE_URL" ...
```

Related files:

- .github/workflows/deploy.yaml
- README.md

---

### Pattern: Release dispatch to PR-gated deploy

Context:

- Release notifications from `training-log` arrive through `repository_dispatch` (`training-log-release`) in this infrastructure repo.

Problem:

- Deploying directly on dispatch bypasses PR validation and can promote submodule changes without preview verification.

Solution:

- Handle `repository_dispatch` by creating/updating a release PR and enabling auto-merge.
- Gate merge on PR checks, including preview deployment and real PostgreSQL Playwright journeys.
- Deploy only after merge via `push` to `main`.
- Close preview environments automatically on PR close (including merges).

Example:

```yaml
on:
    repository_dispatch:
        types: [training-log-release]

jobs:
    release-pr: {}
    enable-auto-merge: {}
    preview-deploy: {}
    real-db-e2e: {}
    close-preview: {}
    deploy:
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

Related files:

- .github/workflows/deploy.yaml
- README.md

---

### Pattern: Checkov-first infra gate with explicit exception comments

Context:

- OpenTofu infrastructure changes under infra/opentofu/azure are validated in CI before plan/deploy.

Problem:

- Security scanning can fail CI for either real misconfigurations or intentional architecture choices.

Solution:

- Fix remediable findings in Terraform first (for example: secret expiration_date and content_type).
- For intentional tradeoffs, use inline checkov skip comments directly on the resource with concrete rationale.
- Keep the rationale operational (what workload requires it and what future condition removes it).

Example:

```hcl
#checkov:skip=CKV_AZURE_189: Public network access remains required for GitHub-hosted runners and SWA-managed functions.
resource "azurerm_key_vault" "main" {
    ...
}
```

Related files:

- infra/opentofu/azure/main.tf
- .github/workflows/deploy.yaml

---

### Pattern: Private endpoint hardening without breaking public frontend

Context:

- Frontend remains publicly reachable via Cloudflare CNAME to Azure Static Web App.

Problem:

- Data-plane resources (Key Vault, PostgreSQL) should support private connectivity without changing public web routing.

Solution:

- Add a dedicated VNet and private-endpoint subnet.
- Add private DNS zones and VNet links for Key Vault and PostgreSQL.
- Add private endpoints for Key Vault and PostgreSQL.
- Leave Static Web App and Cloudflare records public for end-user traffic.

Example:

```hcl
resource "azurerm_private_endpoint" "key_vault" { ... }
resource "azurerm_private_endpoint" "postgresql" { ... }
```

Related files:

- infra/opentofu/azure/main.tf

---

### Pattern: Keep GitHub Actions on latest majors for Node runtime changes

Context:

- GitHub Actions runtime deprecations (Node 20 -> Node 24) can break or warn on older action majors.

Problem:

- Mixed or stale action pins cause deprecation warnings and eventual failures.

Solution:

- Use current majors across workflows and align job runtime node-version values to supported versions (22 or 24 here).
- Re-scan workflow files after updates to confirm no old pins remain.

Example:

```yaml
uses: actions/checkout@v7
uses: actions/setup-node@v6
uses: actions/github-script@v9
uses: azure/login@v3
uses: opentofu/setup-opentofu@v2
```

Related files:

- .github/workflows/deploy.yaml
- blog/.github/workflows/ci.yml

---

### Pattern: Topaz preflight lane (future feature)

Context:

- Infrastructure workflows depend on Azure connectivity and credentials for plan/apply.

Problem:

- Full Azure-backed validation can be slower and credential-sensitive for early iteration.

Solution:

- Add a non-blocking GitHub Actions lane using Topaz as a local Azure emulator for fast Terraform/OpenTofu preflight and RBAC behavior checks.
- Keep existing Azure-backed plan/deploy and real-database E2E jobs as the release gates.

Example:

```yaml
jobs:
    topaz-preflight:
        if: github.event_name == 'pull_request'
        continue-on-error: true
```

Related files:

- .github/workflows/deploy.yaml
- README.md

---

### Pattern: Infracost diagnostics toggle limitation

Context:

- Infracost VS Code extension diagnostics in this workspace.

Problem:

- Extension exposes a single diagnostics toggle that controls both FinOps and tag policy diagnostics.
- No tag-only suppression is available.

Solution:

- Disable inline Infracost diagnostics in workspace settings when tag findings are already covered by Terraform shared tagging (`local.common_tags`).
- Keep a clear note in README with re-enable instructions.

Example:

```json
"infracost.enableDiagnostics": false
```

Related files:

- .vscode/settings.json
- README.md

---

### Pattern: Centralized locals in locals.tf

Context:

- OpenTofu module files under `infra/opentofu/azure/`.

Problem:

- Scattered `locals` blocks in resource files make reuse and maintenance harder.
- Referencing undefined locals (for example shared tags) can pass unnoticed until validation.

Solution:

- Keep module-level local values in `locals.tf`.
- Use a shared `common_tags` local for consistent tagging.
- Set `Environment` to `production` in shared tags for this repo's deployed environment.

Example:

```hcl
locals {
    common_tags = {
        Service     = "workout-blog"
        Environment = "production"
    }

    key_vault_secret_expiration = timeadd(time_static.secret_expiry_anchor.rfc3339, "8760h")
}
```

Related files:

- infra/opentofu/azure/locals.tf
- infra/opentofu/azure/main.tf
