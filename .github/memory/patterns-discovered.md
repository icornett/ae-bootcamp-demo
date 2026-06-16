# Patterns Discovered

Capture recurring implementation patterns and keep them updated over time.

## Pattern Template

### Pattern: <name>

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

### Pattern: ACI diagnostics to Log Analytics

Context:

- Infrastructure for the production `training-log` multi-container Azure Container Instance group.

Problem:

- ACI runtime logs are transient when only queried directly from the container group, making historical troubleshooting difficult.

Solution:

- Provision an `azurerm_log_analytics_workspace` and attach it in `azurerm_container_group.diagnostics.log_analytics` with `log_type = "ContainerInsights"`.

Example:

```hcl
diagnostics {
 log_analytics {
  workspace_id  = azurerm_log_analytics_workspace.main.workspace_id
  workspace_key = azurerm_log_analytics_workspace.main.primary_shared_key
  log_type      = "ContainerInsights"
 }
}
```

Related files:

- infra/opentofu/azure/main.tf
- infra/opentofu/azure/variables.tf
- infra/opentofu/azure/output.tf

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
