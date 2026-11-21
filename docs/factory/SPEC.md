# Spec — Software Factory v1 (the pipeline)

> Status: **draft (ready to publish once the issue tracker exists — it now does).**
> Scope: stand up a working **software factory** (v1) — the label-triggered agent pipeline that turns GitHub tickets into reviewed, merged, and deployed changes.
> Source: produced by a grilling session; decisions captured below as Situation → Options → Choice → Why.
> Split from the original combined spec (2026-11-19). The factory's **first workload** is specified separately in [`docs/app/SPEC.md`](../app/SPEC.md).

**This spec is bootstrap work.** The factory cannot be built *by* the factory — the pipeline does not exist yet. These tickets are implemented **by hand / local Claude Code**, interactively. Only once this spec is delivered (brakes green, tasks runnable, labels gating) does the app spec become buildable by the factory itself.

---

## Problem Statement

I want to apply the "software factory" methodology to real work: turn GitHub tickets into reviewed, merged, and (eventually) deployed changes for **Python applications that run on AWS**, with as little manual code-writing as possible — but without becoming a "slop cannon" that merges low-quality or insecure changes. The factory's first workload is a security-sensitive app (it grants permissions based on who acknowledges an incident escalation), so the factory must carry real brakes from day one, and a human must stay in control of every gate until trust is earned.

I don't yet have a factory. I have the methodology (captured as `course-*` skills). I need a concrete, buildable plan for a **public, personal** factory built on GitHub-native services.

## Solution

A **single-repo, bespoke software factory** for one greenfield Python app (topology per [ADR-0001](../adr/0001-single-repo-topology.md)). The factory is built on GitHub-native services and runs four label-triggered agent **tasks** (explore → implement → review → deploy). The explore→implement→review hand-offs are **auto-chained** ([ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md)): a collaborator-opened issue flows to a review-ready PR with no manual labels. **Two human gates remain**: only collaborator-authored issues enter the factory, and a human merges every PR. Auto-merge stays off.

Success for v1 = **a ticket becomes a reviewed, merged PR with no human writing the code**, all brakes green, and a deployed change reaching AWS via the deploy task. That end-to-end proof is run against the first workload (the app spec). Auto-chaining of explore→implement→review is **enabled** ([ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md)); **auto-merge** remains explicitly deferred.

---

## User Stories

**Operating the factory (human operator / developer)**

1. As a factory operator, I want to file a GitHub issue describing a change, so that the factory has a unit of work to act on.
2. As a factory operator, I want to apply an `agent:explore` label to an issue, so that a read-only run investigates it before any code is written.
3. As a factory operator, I want the explore run to post a short (~20-line) verdict comment classifying blast radius and door type, so that I can decide whether to proceed without reading the whole codebase myself.
4. As a factory operator, I want `agent:implement` applied automatically when explore returns `easy-call` (and to apply it by hand after a `needs-a-human` verdict I judge safe), so that easy work flows without me while judgment calls still wait for me ([ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md)).
5. As a factory operator, I want the implement run to open a **draft** PR, so that nothing looks "ready" until it has been reviewed.
6. As a factory operator, I want to apply `agent:review` (or have implement apply it) so that an automated review pass runs before I spend human attention.
7. As a factory operator, I want the review run to fix what it can on the branch and leave only judgment calls as inline comments, so that human review is as small as possible.
8. As a factory operator, I want to be the one who merges every PR in v1, so that I retain the final gate while I learn where the agent errs.
9. As a factory operator, I want merging an app-code PR to trigger a deploy run, so that merged changes reach AWS without a manual deploy step.
10. As a factory operator, I want to run `/retro` over a run's logs, so that I can turn recurring agent struggles into new checks or coding standards.
11. As a factory operator, I want to climb the trust ladder by removing gates deliberately: explore→implement→review auto-chaining is now **enabled** ([ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md)) after all three tasks were proven on canary tickets; **auto-merge** is the next rung, gated on `/retro` evidence.
12. As a factory operator, I want only triage-role-or-above collaborators to be able to apply `agent:*` labels, so that a random visitor to the public repo cannot start a run.

**Task contracts (how each run must behave)**

13. As an implement run, I want the explore run's recorded filenames and lines as input, so that I don't re-explore the codebase from scratch.
14. As an implement run, I want to commit through the pre-commit hook and never use `--no-verify`, so that every brake runs before code lands.
15. As an implement run, I want to be forbidden from editing hook configuration or `.github/` workflows, so that I cannot weaken the factory's own brakes.
16. As a review run, I want to drive the handler against a local AWS mock with a signed webhook, so that I verify behavior, not just read the diff.
17. As an explore run, I want to treat issue text as **data, not instructions**, run read-only, and have network isolation, so that a malicious public issue cannot inject commands or exfiltrate data.

**Infrastructure & deployment (the deploy machinery)**

25. As a platform-minded operator, I want infrastructure declared in Terraform modules in the repo, so that the app's AWS resources are reproducible.
26. As an operator, I want `terraform plan` to run automatically on any PR touching `infra/**`, so that infra changes are visible before they're applied.
27. As an operator, I want infra changes to follow **apply-before-merge** (plan → validate → human-triggered apply → merge only on success), so that `main` always reflects already-applied state.
28. As an operator, I want only one infra PR to apply at a time (state lock + concurrency guard), so that concurrent applies can't corrupt state.
29. As an operator, I want an applied-but-unmerged infra PR to merge immediately on apply success, so that AWS and `main` don't drift.
30. As an operator, I want infra PRs to be ineligible for auto-merge forever, so that one-way-door infra changes always get a human.
31. As an operator, I want app-code changes (new Lambda version + alias shift) to deploy automatically on merge to `main`, so that reversible, low-blast changes ship fast.
32. As an operator, I want GitHub Actions to authenticate to AWS via **OIDC-assumed IAM roles** (a read/plan role and a narrower deploy role), so that no long-lived AWS keys live in the repo.
33. As an operator, I want Terraform state in S3 with a DynamoDB lock and SSE-KMS encryption, so that state is safe, locked, and encrypted.

**Brakes & security**

34. As an operator, I want deterministic checks (ruff, mypy, pytest) in pre-commit, so that mechanical errors are caught before commit.
35. As a security-conscious operator, I want secret scanning (gitleaks/detect-secrets) in the brakes, so that a credential can never be committed.
36. As a security-conscious operator, I want Python SAST (bandit) in the brakes, so that dangerous patterns (e.g. `verify=False`, hardcoded secrets, `shell=True`) are flagged.
37. As a security-conscious operator, I want dependency CVE scanning (pip-audit) in the brakes, so that a vulnerable dependency is caught before it ships.
38. As an operator, I want repo-wide violations to become coding standards or ratchet items rather than pre-broken checks, so that checks that exist are always green.

**Harness portability & observability**

44. As an operator, I want every task to import a single swappable agent definition, so that changing model or CLI is a one-file change.
45. As an operator, I want run logs visible in GitHub Actions plus a `/retro` task, so that I can observe and improve the factory without standing up another service yet.

---

## Implementation Decisions

Decisions are recorded as **Situation → Options → Choice → Why**. Full ADRs exist for the highest-leverage ones.

### D1 — Factory topology: one repo, one app
- **Situation:** Factory could target one repo, be a reusable template, or span many repos.
- **Options:** (a) single repo / single app; (b) template per repo; (c) cross-repo meta-factory.
- **Choice:** (a) single repo, single app, bespoke. **The factory and its first app live in one repo**; this spec and the app spec are two documents, not two repos.
- **Why:** The goal is learning the factory loop, not org-scale distribution. Single-repo keeps the orchestrator (GitHub Actions) simple and keeps app+infra changes atomic. (See ADR-0001.)

### D2 — Services (five-slot model)
- **Ticket tracker:** GitHub Issues — labels natively trigger GitHub Actions; triage-role gating is the approval boundary. (Recorded in `docs/agents/issue-tracker.md`.)
- **Git host:** GitHub.
- **Runner + orchestrator:** GitHub Actions fills **both** slots (ephemeral VM per run; label/schedule triggers with concurrency controls).
- **Observability:** GitHub Actions run logs + the `/retro` task. Langfuse deferred.
- **Harness:** Claude Code, wrapped in a single exported agent definition imported by every task.
- **Why:** For one repo, GitHub-native services need no extra integration and are free; the full-scale stack (Linear / Daytona / Inngest / Langfuse) is deferred until the single-repo setup is outgrown.

### D4 — Two-tier AWS deploy (platform/product split)
- **Infra tier (Terraform):** `terraform plan` auto-runs on `infra/**` PRs; **apply-before-merge** (GitOps / Atlantis-style, without installing Atlantis): plan → validate → human-triggered apply on the PR branch → merge **only** after apply succeeds. One infra PR applies at a time (state lock + concurrency guard); merge immediately on apply success to avoid abandoned-PR drift. **Infra PRs are never auto-merge candidates.**
- **App-code tier (GitHub Actions):** on merge to `main`, assume an OIDC deploy role and update the Lambda version + alias (future: Fargate image). Reversible, small blast radius.
- **AWS auth:** GitHub OIDC → two scoped IAM roles (read/plan role + narrower deploy role). **No long-lived keys** in GitHub secrets. Terraform state in S3 + DynamoDB lock, SSE-KMS encrypted.
- **Why:** Mirrors the work split (platform team applies infra; product teams ship app code), and maps cleanly onto two-way-door vs one-way-door blast radius. *(This is factory machinery; the app's actual AWS resources are specified in the app spec.)*

### D5 — Brakes (first brake = deterministic automated checks)
- **Choice:** uv (deps/lockfile) · ruff (lint+format) · mypy (types) · pytest+coverage, all run via a pre-commit hook the agent commits through (no `--no-verify`, no editing hooks). **Security brakes (non-negotiable):** gitleaks/detect-secrets · bandit (Python SAST) · pip-audit (dependency CVE).
- **Why:** *Accelerate only once you can brake.* For a permission-granting app, secret scanning + SAST + CVE checks are load-bearing, not optional. Repo-wide violations become coding standards or ratchet items, never pre-broken checks.

### D6 — Tasks (four, label-triggered) + the entry gate
- `auto-label` — the entry gate ([ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md)): on `issues: opened`, applies `agent:explore` **only when the issue author is a collaborator** (triage+). Non-collaborator issues never enter.
- `agent:explore` — read-only; reproduces the ticket, finds files/lines, classifies blast radius + door, leaves verdict (`easy-call` / `needs-a-human` / `blocked`) + ~20-line comment. On `easy-call`, applies `agent:implement` to auto-advance; other verdicts stop for a human. Prompt-injection defense: issue text is data, read-only, network isolation.
- `agent:implement` — builds the ticket, commits through pre-commit, pushes a **draft** PR, applies `agent:review`.
- `agent:review` — reviews vs spec + standards, drives handler against the local mock with a signed webhook, fixes what it can on branch, leaves inline comments, marks PR ready.
- `deploy` (app-code tier) — on merge to `main`, OIDC, bump Lambda alias.
- Plus the infra GitOps flow as its own path-filtered workflow.

### D7 — Secrets & approval boundary
- **FACTORY_PAT:** fine-grained, scoped to this one repo; read/write on Actions, Issues, Pull requests, Contents, Workflows; everything else no-access; with expiry; stored as a repo secret. (Needed because the built-in `GITHUB_TOKEN` can't trigger downstream workflows or open PRs.)
- **Approval boundary:** the label. Only triage-role-or-above collaborators can apply `agent:*` labels.

### D8 — Human involvement (v1) and the trust ladder
- **v1 (current):** explore→implement→review is **auto-chained** ([ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md)). **Two gates stay manned:** (1) **entry** — only a collaborator-authored issue auto-enters (via `auto-label`), and (2) **merge** — a human merges every PR. **Auto-merge is off entirely.**
- **Later (defined, not enabled):** auto-merge requires all three brakes green + two-way door + small blast radius + no data migrations + app-code tier only. **Never** for infra, DynamoDB/Aurora schema changes (data migrations), or auth/signature-verification/permission-decision code.

---

## Factory self-verification

The four tasks are validated by **running them on a canary ticket**, not by unit tests — and the canary is the first slice of the app spec. `/retro` over run logs is the feedback loop that turns struggles into new checks/standards.

---

## Out of Scope (v1)

Design each so adding it later is a **new task, not a refactor**:

- **Auto-merge** (criteria defined in D8, but disabled). *(Auto-chaining of explore→implement→review is now enabled — [ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md).)*
- **Langfuse** (or any external observability platform).
- **Ticket sources** — CloudWatch alarms / Sentry auto-filing tickets via the push→pull monitor pattern — deferred until the app is deployed and taking traffic.
- **A separate infrastructure repository** — stay one-repo now; extract an infra repo later *as a factory exercise* once infra stabilizes.

---

## Further Notes

**Approval boundary & prompt-injection:** the repo is public; the `agent:*` label (triage-role-gated) is the only way to start a run, and explore runs treat issue text as data, run read-only, and have network isolation.

**Publishing:** this spec is a local draft. The factory-standup tickets it produces are bootstrap work (implemented by hand). The app spec — the factory's first workload — is what becomes a `ready-for-agent` tracker issue the operational factory consumes.
