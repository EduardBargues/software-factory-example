# Spec — incident.io webhook → permission-grant app

> Status: **draft.**
> Scope: the first slice of the factory's initial workload — a serverless app that receives **signed incident.io webhooks** and records **temporary elevated-access grants** keyed on who acknowledged an escalation. All data is synthetic; no real incident.io tenant is connected.
> Source: produced by a grilling session; decisions captured below as Situation → Options → Choice → Why.
> Split from the original combined spec (2026-11-19).

**This spec is the factory's first workload — not bootstrap work.** It is **blocked by the factory being operational** (see [`docs/factory/SPEC.md`](../factory/SPEC.md)): brakes green, the four `agent:*` tasks runnable, labels gating. Once the factory is live, this spec becomes a `ready-for-agent` tracker issue that the factory builds via `/to-tickets` → explore → implement → review → merge → deploy. Building it end-to-end **with no human writing the code** is the factory's acceptance test.

---

## Problem Statement

I have a security-sensitive work application I can't copy: it grants temporary elevated AWS access to the on-call engineer who acknowledges an incident escalation. I need a **public, personal mock** that reproduces the work app's shape and security posture using synthetic data, so the factory has a realistic, security-sensitive workload to prove itself on.

The app is a **permission authority**: it records who holds elevated access and answers "does this person hold it *now*?" — it does **not** provision AWS access itself. Granting elevated access to the wrong actor, an off-rotation person, or a non-incident page is the core footgun; the eligibility rule must be an *enforced guard*, not an assumption.

## Solution

An AWS **Lambda behind API Gateway (HTTP API)** that receives **signed incident.io webhooks** and records **permission grants** in **DynamoDB**, keyed on who acknowledged an escalation. Infrastructure is declared in **Terraform** and deployed through the factory's two-tier deploy (see factory spec D4). The permission-decision logic sits behind a **hexagonal port** so it is unit-testable with zero AWS.

---

## User Stories

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

**The app's AWS resources (declared in Terraform, deployed via the factory's two-tier deploy)**

The app owns these resources; the *mechanism* that plans/applies/deploys them lives in the factory spec (D4). The app requires: a Lambda (handler), an API Gateway HTTP API (v2) route to it, and a DynamoDB table for Grants (with TTL configured as housekeeping only — see D11). SQS / Fargate / Aurora are out of scope.

---

## Implementation Decisions

Decisions are recorded as **Situation → Options → Choice → Why**. Full ADRs exist for grant eligibility and grant expiry.

### D3 — App shape: minimal serverless slice first
- **Choice:** Lambda behind API Gateway (HTTP API) for the webhook; DynamoDB for permission state. SQS / Fargate / Aurora deferred until the domain demands them.
- **Why:** Get Explore→Implement→Review→Merge→Deploy working end-to-end on the smallest real slice, then grow infra ticket by ticket (which also exercises the factory on its own infra).

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

---

## Out of Scope (v1)

Design each so adding it later is a **new task, not a refactor**:

- **Severity-scoped access levels** — v1 confers a single fixed level.
- **Manual revocation** — there is no actor for it; access ends only by time-expiry or incident-close.
- **Additional AWS services** — SQS, Fargate, Aurora/RDS Postgres.
- Connecting to the **real work incident.io**; all webhooks are synthetic/mock.

---

## Further Notes

**First actions (not open questions):**
1. **The floci spike** — a one-hour proof that `terraform apply` of the minimal stack (Lambda + API Gateway + DynamoDB) succeeds against floci. Adopt only if it passes; otherwise fall back to per-service emulators.
2. **Treat IAM and true fidelity as validated only at the real-AWS e2e tier.**

**Security posture:** public repo, synthetic data, but the signed-webhook signature-verification auth must replicate incident.io's real scheme. incident.io uses the **Svix** signing scheme: three headers — `webhook-id`, `webhook-timestamp`, `webhook-signature` — with an **HMAC-SHA256** over `"{id}.{timestamp}.{body}"`, emitted as a space-delimited `v1,<base64>` list (multiple entries during secret rotation; any match passes). The handler must: verify with a **constant-time** comparison, enforce a **timestamp window** on `webhook-timestamp` for **replay protection**, and keep the signing secret in env/Vault (never in code or Git). Secret-scanning, SAST, and CVE checks (factory brakes) are permanent. The acknowledgement itself arrives as `public_escalation.escalation_status_updated_v1` with `new_status == "acknowledged"`.
