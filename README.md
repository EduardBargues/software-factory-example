# software-factory-example

A reference **software factory**: an AI-agent pipeline that turns GitHub issues into reviewed, merged, and (eventually) deployed changes — with a human at every gate until trust is earned.

The factory's first workload is a **mock of a real work application**: an AWS serverless service that receives **signed [incident.io](https://incident.io) webhooks** and grants **temporary elevated access** to the on-call engineer who acknowledges an escalation. All data is synthetic; no real incident.io tenant is connected.

> Status: **design captured, pre-implementation.** The `docs/` specs, glossary, and ADRs are settled; code is next. The design is split into **two specs** — one for the factory (built by hand), one for the app (built by the factory) — but **one repo** (see ADR-0001).

## What's here

| Path | What it is |
|---|---|
| [`docs/factory/SPEC.md`](docs/factory/SPEC.md) | Spec for **the factory itself** — the agent pipeline (bootstrap; built by hand) |
| [`docs/app/SPEC.md`](docs/app/SPEC.md) | Spec for **the app** — the incident.io webhook → permission-grant workload (built *by* the factory) |
| [`GLOSSARY.md`](GLOSSARY.md) | Canonical domain + factory vocabulary (use these terms exactly) |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records |

## The factory at a glance

- **Services:** GitHub Issues (tickets) · GitHub (host) · GitHub Actions (runner **and** orchestrator) · Actions logs + `/retro` (observability) · Claude Code (harness, behind one swappable definition).
- **Tasks:** `agent:explore` → `agent:implement` → `agent:review` → `deploy`, label-triggered. v1 keeps **all five human gates manned** (no auto-chaining, no auto-merge).
- **Brakes:** `ruff` · `mypy` · `pytest` + security brakes `gitleaks` · `bandit` · `pip-audit`, all via pre-commit.

## The app at a glance

- **Shape:** AWS **Lambda** behind **API Gateway (HTTP API)**, state in **DynamoDB**. Infra in **Terraform**; two-tier deploy (GitOps apply-before-merge for infra, merge-then-ship for app code) with **GitHub OIDC** (no long-lived keys).
- **Core rule — Grant eligibility ([ADR-0003](docs/adr/0003-grant-eligibility.md)):** grant elevated access **only if** the acknowledger is a **human user**, a **member of the escalated team's on-call rotation**, and the escalation has an **associated incident**.
- **Expiry ([ADR-0004](docs/adr/0004-grant-expiry-enforcement.md)):** a grant ends at **incident-close or 8h, whichever first**; enforced by an **on-read check** (DynamoDB TTL is housekeeping only).

## Architecture decisions

- [ADR-0001 — Single-repo, single-app topology](docs/adr/0001-single-repo-topology.md)
- [ADR-0002 — Local AWS mock: floci, pending a spike](docs/adr/0002-local-aws-mock-floci-pending-spike.md)
- [ADR-0003 — Grant eligibility (the security gate)](docs/adr/0003-grant-eligibility.md)
- [ADR-0004 — Grant expiry enforcement](docs/adr/0004-grant-expiry-enforcement.md)
