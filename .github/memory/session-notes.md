# Session Notes

## Purpose

Document completed development sessions for future reference. This file is committed to git as a historical record.

## Session Summary Template

### Session: <short session name>

Date: YYYY-MM-DD

#### What was accomplished

- Item
- Item

#### Key findings and decisions

- Finding
- Decision and rationale

#### Outcomes

- Delivered result
- Follow-up item

---

## Example Session Summary

### Session: OIDC Deploy Pipeline Fix

Date: 2026-05-19

#### What was accomplished

- Reviewed deploy workflow OIDC settings and Azure login configuration.
- Validated branch and trigger conditions for deployment job.
- Identified federated credential subject mismatch as primary failure cause.

#### Key findings and decisions

- OIDC workflow permissions were already correct (`id-token: write`).
- Azure app registration needed a federated credential matching the current repository and branch.
- Kept OIDC approach and avoided reverting to client secret authentication.

#### Outcomes

- Clear remediation steps documented for issuer, audience, and subject alignment.
- Faster triage path established for future `azure/login` failures.
