# Spec — Software Factory v1 for a Python / AWS serverless app

> Status: **draft (ready to publish once the factory repo + issue tracker exist)**
> Scope: stand up a working **software factory** (v1) and prove it end-to-end by having it build the first slice of its initial workload — a serverless **incident.io webhook → permission-grant** app.
> Source: produced by a grilling session; decisions captured below as Situation → Options → Choice → Why.

---

## Problem Statement

I want to apply the "software factory" methodology to real work: turn GitHub tickets into reviewed, merged, and (eventually) deployed changes for **Python applications that run on AWS**, with as little manual code-writing as possible — but without becoming a "slop cannon" that merges low-quality or insecure changes. The target app is security-sensitive (it grants permissions based on who acknowledges an incident escalation), so the factory must carry real brakes from day one, and a human must stay in control of every gate until trust is earned.

I don't yet have a factory. I have the methodology (captured as `course-*` skills) and a sensitive work application I can't copy. I need a concrete, buildable plan for a **public, personal mock** that reproduces the work app's shape and security posture using synthetic data.

## Solution

A **single-repo, bespoke software factory** for one greenfield Python app. The factory is built on GitHub-native services and runs four label-triggered agent **tasks** (explore → implement → review → deploy). For v1, **every human gate is manned**: a human applies each `agent:*` label by hand, reads each run's output, and merges every PR. No auto-chaining, no auto-merge.

The initial workload the factory builds is a mock of the work app: an AWS **Lambda behind API Gateway (HTTP API)** that receives **signed incident.io webhooks** and records **permission grants** in **DynamoDB**, keyed on who acknowledged an escalation. Infrastructure is declared in **Terraform** and deployed in **two tiers** mirroring a platform-team / product-team split.

Success for v1 = **a ticket becomes a reviewed, merged PR with no human writing the code**, all brakes green, and a deployed change reaching AWS via the deploy task. Full autonomy (auto-chaining, auto-merge) is explicitly deferred.

---

## User Stories

**Operating the factory (human operator / developer)**

1. As a factory operator, I want to file a GitHub issue describing a change, so that the factory has a unit of work to act on.
2. As a factory operator, I want to apply an `agent:explore` label to an issue, so that a read-only run investigates it before any code is written.
3. As a factory operator, I want the explore run to post a short (~20-line) verdict comment classifying blast radius and door type, so that I can decide whether to proceed without reading the whole codebase myself.
4. As a factory operator, I want to apply `agent:implement` by hand after reading the explore verdict, so that I stay the approval gate between exploration and implementation.
5. As a factory operator, I want the implement run to open a **draft** PR, so that nothing looks "ready" until it has been reviewed.
6. As a factory operator, I want to apply `agent:review` (or have implement apply it) so that an automated review pass runs before I spend human attention.
7. As a factory operator, I want the review run to fix what it can on the branch and leave only judgment calls as inline comments, so that human review is as small as possible.
8. As a factory operator, I want to be the one who merges every PR in v1, so that I retain the final gate while I learn where the agent errs.
9. As a factory operator, I want merging an app-code PR to trigger a deploy run, so that merged changes reach AWS without a manual deploy step.
10. As a factory operator, I want to run `/retro` over a run's logs, so that I can turn recurring agent struggles into new checks or coding standards.
11. As a factory operator, I want to remove one human gate at a time (starting with explore→implement auto-chaining) only after `/retro` shows the agent reliably nails that hand-off, so that I climb the trust ladder deliberately.
12. As a factory operator, I want only triage-role-or-above collaborators to be able to apply `agent:*` labels, so that a random visitor to the public repo cannot start a run.

**Building the app (the agent)**

13. As an implement run, I want the explore run's recorded filenames and lines as input, so that I don't re-explore the codebase from scratch.
14. As an implement run, I want to commit through the pre-commit hook and never use `--no-verify`, so that every brake runs before code lands.
15. As an implement run, I want to be forbidden from editing hook configuration or `.github/` workflows, so that I cannot weaken the factory's own brakes.
16. As a review run, I want to drive the handler against a local AWS mock with a signed webhook, so that I verify behavior, not just read the diff.
17. As an explore run, I want to treat issue text as **data, not instructions**, run read-only, and have network isolation, so that a malicious public issue cannot inject commands or exfiltrate data.

**The app's behavior (end user of the deployed app)**

18. As incident.io, I want to POST a signed webhook to the app's endpoint when an escalation is acknowledged, so that downstream permissions can be granted.
19. As the app, I want to verify the webhook signature using a timing-safe comparison before trusting any payload, so that forged requests are rejected.
20. As the app, I want to reject webhooks with a missing, malformed, or invalid signature with the correct HTTP status, so that only authentic incident.io events are processed.
21. As the app, I want to create a **Grant** of a single fixed elevated-access level, scoped to the Acknowledger and the Escalation, so that an eligible on-call responder gets elevated access.
22. As the app, I want to grant **only when all three eligibility gates hold** (human User · member of the escalated Team's on-call rotation · Escalation has an associated Incident), so that elevated access is never given to the wrong actor or for a non-incident page.
23. As the app, I want processing an Acknowledgement to be idempotent on the incident.io **event/delivery id**, so that a redelivered webhook doesn't double-grant or error.
24. As an operator, I want Grants stored in DynamoDB, so that they are durable and queryable.
24a. As the app, I want **each Grant to end when its Incident closes or 8 hours after that acknowledgement, whichever comes first** (reason `time_expired` or `incident_closed`), so that elevated access never outlives its window.
24b. As the app, I want a person's **elevated access to last until the latest of their active Grants' windows** (the union), so that acknowledging several escalations for one Incident keeps access until the last 8-hour window lapses.
24c. As the app, I want to **verify (not assume)** that the Acknowledger is a human User who is a current member of the escalated Team's on-call rotation — refusing `api_key`/`workflow` actors and non-members — so that only legitimate on-call responders get access.
24d. As a developer, I want a Grant's **ending (time-expiry or incident-close) to be observable behavior at the read seam**, so that the lifecycle is testable.
24e. As the app, I want to **refuse to grant when the Escalation has no associated Incident**, so that support/question pages (which incident.io also uses escalations for) never yield elevated access.
24f. As the app, I want **closing an Incident (`incident_status_updated` → closed) to end all Grants tied to that Incident's escalations at once**, so that access drops as soon as the incident is over.
24g. As a consumer, I want **elevated access evaluated at read time** (is there an active, non-ended Grant whose 8h window still covers `now`?), so that access is correct even though DynamoDB TTL deletion lags by up to ~48h.

**Infrastructure & deployment**

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

**Verification / testing**

39. As a developer, I want the permission-decision logic behind a hexagonal port, so that it can be unit-tested with zero AWS.
40. As a developer, I want unit/component tests to use mocked boto3 (moto or `botocore.Stubber`), so that they are fast and hermetic.
41. As a developer, I want a local integration tier that can `terraform apply` a Lambda+APIGW+DynamoDB stack against a local AWS mock, so that I can exercise the real Terraform and drive the handler locally.
42. As a developer, I want an end-to-end tier that runs against real AWS (ephemeral stack, real apply, real signed webhook), so that IAM and true AWS fidelity are validated where they actually hold.
43. As a security-conscious operator, I want local-mock passes to never be treated as IAM-validated, so that least-privilege bugs are only ever "proven" against real AWS.

**Harness portability & observability**

44. As an operator, I want every task to import a single swappable agent definition, so that changing model or CLI is a one-file change.
45. As an operator, I want run logs visible in GitHub Actions plus a `/retro` task, so that I can observe and improve the factory without standing up another service yet.

---

## Implementation Decisions

Decisions are recorded as **Situation → Options → Choice → Why**. Full ADRs exist for the two highest-leverage ones (topology; local AWS mock).

### D1 — Factory topology: one repo, one app
- **Situation:** Factory could target one repo, be a reusable template, or span many repos.
- **Options:** (a) single repo / single app; (b) template per repo; (c) cross-repo meta-factory.
- **Choice:** (a) single repo, single app, bespoke.
- **Why:** The goal is learning the factory loop, not org-scale distribution. Single-repo keeps the orchestrator (GitHub Actions) simple and keeps app+infra changes atomic. (See ADR-0001.)

### D2 — Services (five-slot model)
- **Ticket tracker:** GitHub Issues — labels natively trigger GitHub Actions; triage-role gating is the approval boundary.
- **Git host:** GitHub.
- **Runner + orchestrator:** GitHub Actions fills **both** slots (ephemeral VM per run; label/schedule triggers with concurrency controls).
- **Observability:** GitHub Actions run logs + the `/retro` task. Langfuse deferred.
- **Harness:** Claude Code, wrapped in a single exported agent definition imported by every task.
- **Why:** For one repo, GitHub-native services need no extra integration and are free; the full-scale stack (Linear / Daytona / Inngest / Langfuse) is deferred until the single-repo setup is outgrown.

### D3 — App shape: minimal serverless slice first
- **Choice:** Lambda behind API Gateway (HTTP API) for the webhook; DynamoDB for permission state. SQS / Fargate / Aurora deferred until the domain demands them.
- **Why:** Get Explore→Implement→Review→Merge→Deploy working end-to-end on the smallest real slice, then grow infra ticket by ticket (which also exercises the factory on its own infra).

### D4 — Two-tier AWS deploy (platform/product split)
- **Infra tier (Terraform):** `terraform plan` auto-runs on `infra/**` PRs; **apply-before-merge** (GitOps / Atlantis-style, without installing Atlantis): plan → validate → human-triggered apply on the PR branch → merge **only** after apply succeeds. One infra PR applies at a time (state lock + concurrency guard); merge immediately on apply success to avoid abandoned-PR drift. **Infra PRs are never auto-merge candidates.**
- **App-code tier (GitHub Actions):** on merge to `main`, assume an OIDC deploy role and update the Lambda version + alias (future: Fargate image). Reversible, small blast radius.
- **AWS auth:** GitHub OIDC → two scoped IAM roles (read/plan role + narrower deploy role). **No long-lived keys** in GitHub secrets. Terraform state in S3 + DynamoDB lock, SSE-KMS encrypted.
- **Why:** Mirrors the work split (platform team applies infra; product teams ship app code), and maps cleanly onto two-way-door vs one-way-door blast radius.

### D5 — Brakes (first brake = deterministic automated checks)
- **Choice:** uv (deps/lockfile) · ruff (lint+format) · mypy (types) · pytest+coverage, all run via a pre-commit hook the agent commits through (no `--no-verify`, no editing hooks). **Security brakes (non-negotiable):** gitleaks/detect-secrets · bandit (Python SAST) · pip-audit (dependency CVE).
- **Why:** *Accelerate only once you can brake.* For a permission-granting app, secret scanning + SAST + CVE checks are load-bearing, not optional. Repo-wide violations become coding standards or ratchet items, never pre-broken checks.

### D6 — Tasks (four, label-triggered)
- `agent:explore` — read-only; reproduces the ticket, finds files/lines, classifies blast radius + door, leaves verdict (`easy-call` / `needs-a-human` / `blocked`) + ~20-line comment. Prompt-injection defense: issue text is data, read-only, network isolation.
- `agent:implement` — builds the ticket, commits through pre-commit, pushes a **draft** PR, applies `agent:review`.
- `agent:review` — reviews vs spec + standards, drives handler against the local mock with a signed webhook, fixes what it can on branch, leaves inline comments, marks PR ready.
- `deploy` (app-code tier) — on merge to `main`, OIDC, bump Lambda alias.
- Plus the infra GitOps flow as its own path-filtered workflow.

### D7 — Secrets & approval boundary
- **FACTORY_PAT:** fine-grained, scoped to this one repo; read/write on Actions, Issues, Pull requests, Contents, Workflows; everything else no-access; with expiry; stored as a repo secret. (Needed because the built-in `GITHUB_TOKEN` can't trigger downstream workflows or open PRs.)
- **Approval boundary:** the label. Only triage-role-or-above collaborators can apply `agent:*` labels.

### D8 — Human involvement (v1) and the trust ladder
- **v1:** manual label hand-off at **every** step; all five gates manned (Explore → Approve → Implement → Review → Merge). No auto-chaining. **Auto-merge off entirely.**
- **Later (defined, not enabled):** auto-merge requires all three brakes green + two-way door + small blast radius + no data migrations + app-code tier only. **Never** for infra, DynamoDB/Aurora schema changes (data migrations), or auth/signature-verification/permission-decision code.

### D9 — App domain model (webhook → permission app)
- **Actors & structure:** A **Team** owns an **on-call rotation** whose **members** take turns being on call; the **on-call engineer** is the member currently active (the first responder). An **Acknowledger** is the **human User** who acked — *not* guaranteed to be an on-call engineer or even human; the app enforces eligibility (see D10).
- **Escalation / Acknowledgement:** an **Escalation** walks a Team's escalation path; an **Acknowledgement** arrives as `public_escalation.escalation_status_updated_v1` with `new_status == "acknowledged"`. The acknowledger's identity (`id`, `email`) is in `actor.user` / `events[].users[]`.
- **Grant is an entity with a lifecycle**, not a fire-and-forget write: `active → ended`, where `ended` carries a **reason** of `time_expired` (8h after that ack) or `incident_closed`. A Grant is keyed by **(Acknowledger, Escalation)** with its own 8h window. **Elevated access** is *derived* — a person holds it iff they have **≥1 active Grant** (the union of their windows). v1 grants a **single fixed elevated-access level** (severity-scoped levels deferred). *No manual revocation* — there is no actor for it.
- **Idempotency key:** the incident.io **event/delivery id** (not a hash of the body), so redelivered webhooks don't double-grant.
- **Severity vs priority:** severity lives on the **Incident** (`name`/`rank`, tenant-named — not fixed "SEV1/2/3"); the escalation carries only `priority`. v1 reads neither for scoping (fixed level); association with an Incident is a *gate*, not a scope input.
- **Expiry enforcement:** decided — see **D11** and **ADR-0004** (on-read check is the authority; incident-close is webhook-driven; DynamoDB TTL is housekeeping only).

### D10 — Grant eligibility (the security gate)
- **Rule:** create a Grant **only if all three hold** — (1) the `actor` is a **human User**; (2) that User is a **current member of the escalated Team's on-call rotation** (verified via an incident.io API call, not assumed); (3) the Escalation has an **associated Incident** (`related_incidents[]` non-empty). Otherwise, **refuse** (and log) — no Grant.
- **Consequences:** `api_key`/`workflow` actors are refused; a **manager** on the escalation path who is *not* on the rotation is refused; a page with **no incident** (support/question) yields no elevated access.
- **Situation → Options → Choice → Why:** the acknowledger could be anyone/anything on the path, and escalations exist without incidents. Options: grant on any ack / grant to any human / grant only to on-call human for an incident-associated escalation. **Choice:** the last. **Why:** for a permission-granting system the invariant must be an *enforced guard*, not an assumption — granting elevated access to a non-human actor, an off-rotation person, or a non-incident page is the core footgun. (See ADR-0003.)

### D11 — Grant expiry enforcement
- **Access model:** the app is a **permission authority**, not a provisioner. It records Grants and answers "does this person hold elevated access *now*?"; it does **not** provision AWS access. (In production the real app would assign the User to an **AWS IAM Identity Center** group — out of scope for the mock.)
- **Mechanism (three parts):**
  1. **Time cap — enforced on read.** A Grant's 8h window is checked at read time (`now < granted_at + 8h`). No background sweep.
  2. **Incident close — webhook-driven.** `public_incident.incident_status_updated_v2` (status → closed) marks **all** Grants tied to that Incident's escalations as `ended(incident_closed)`; reads reject ended Grants.
  3. **DynamoDB TTL — housekeeping only.** Set at/after `granted_at + 8h` to delete stale rows; **never** the security boundary.
- **Why on-read is the authority:** DynamoDB TTL deletion lags (expired items remain **readable for up to ~48h**), so a read-time check is **mandatory** for correctness regardless — which makes a sweep unnecessary and the TTL lag harmless. (See ADR-0004.)
- **Elevated access** is the **union** of a person's active Grant windows; multiple acked escalations for one Incident extend effective access until the latest window lapses (or the Incident closes, ending all of them).

---

## Testing Decisions

**What makes a good test here:** it exercises **external behavior at a seam**, not implementation details. Prefer the **highest seam** and the **fewest seams**.

### Seams (to confirm with the operator)
- **Primary seam — the Lambda handler entrypoint.** Construct an API Gateway HTTP API (v2) event carrying a **signed** incident.io payload, invoke the handler, assert the HTTP response **and** the resulting permission grant in DynamoDB. This one seam covers signature verification, payload parsing, the permission decision, and persistence.
- **Secondary seam — the permission-decision domain port.** Pure logic (acknowledger + escalation context → grant decision) behind a hexagonal port, unit-tested with **zero AWS**.
- Persistence is reached through a `PermissionStore` port whose DynamoDB adapter is the only AWS-touching code; it is covered at the integration tier, not mocked away in behavior tests.

### Tiers
- **Unit / component:** pytest + mocked boto3 (moto or `botocore.Stubber`); domain logic needs no AWS at all.
- **Integration (local):** `terraform apply` a Lambda+APIGW+DynamoDB stack against a **local AWS mock** (floci, **pending a one-hour spike**; fallback: per-service emulators — DynamoDB Local + ElasticMQ; MiniStack as drop-in alternative). Drive the handler with a signed webhook. The local mock is **pinned by image digest, dev/CI-only, never in the deployed path**. (See ADR-0002.)
- **End-to-end:** real AWS — ephemeral stack, real `terraform apply`, real signed webhook. **This tier is the sole authority on IAM and true fidelity;** a local-mock pass is never treated as IAM-validated.

### Factory self-verification
The four tasks are validated by **running them on a canary ticket**, not by unit tests. `/retro` over run logs is the feedback loop that turns struggles into new checks/standards.

---

## Out of Scope (v1)

Design each so adding it later is a **new task, not a refactor**:

- **Auto-chaining** of tasks and **auto-merge** (criteria defined in D8, but disabled).
- **Langfuse** (or any external observability platform).
- **Ticket sources** — CloudWatch alarms / Sentry auto-filing tickets via the push→pull monitor pattern — deferred until the app is deployed and taking traffic.
- **Additional AWS services** — SQS, Fargate, Aurora/RDS Postgres.
- **A separate infrastructure repository** — stay one-repo now; extract an infra repo later *as a factory exercise* once infra stabilizes.
- Connecting to the **real work incident.io**; all webhooks are synthetic/mock.

---

## Further Notes

**First actions (not open questions):**
1. **The floci spike** — a one-hour proof that `terraform apply` of the minimal stack (Lambda + API Gateway + DynamoDB) succeeds against floci. Adopt only if it passes; otherwise fall back to per-service emulators.
2. **Treat IAM and true fidelity as validated only at the real-AWS e2e tier.**

**Security posture:** public repo, synthetic data, but the signed-webhook signature-verification auth must replicate incident.io's real scheme. incident.io uses the **Svix** signing scheme: three headers — `webhook-id`, `webhook-timestamp`, `webhook-signature` — with an **HMAC-SHA256** over `"{id}.{timestamp}.{body}"`, emitted as a space-delimited `v1,<base64>` list (multiple entries during secret rotation; any match passes). The handler must: verify with a **constant-time** comparison, enforce a **timestamp window** on `webhook-timestamp` for **replay protection**, and keep the signing secret in env/Vault (never in code or Git). Secret-scanning, SAST, and CVE checks are permanent brakes. The acknowledgement itself arrives as `public_escalation.escalation_status_updated_v1` with `new_status == "acknowledged"`.

**Publishing:** this spec is a local draft. To publish it as a tracker issue with the `ready-for-agent` label, first create the factory repo (with a remote) and run `/setup-matt-pocock-skills` to record the issue tracker and triage-label vocabulary.
