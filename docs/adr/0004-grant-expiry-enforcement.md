# ADR-0004 — Grant expiry enforcement: on-read authority, incident-close webhook, TTL as housekeeping

- **Status:** Accepted
- **Date:** 2026-11-19

## Situation

A Grant confers temporary elevated access and must end when the associated Incident closes **or** 8 hours after the acknowledgement, whichever comes first (the rule used at work). Elevated access must not outlive that window. We needed to decide how expiry is *enforced*.

Decisive constraint: **DynamoDB TTL does not delete promptly.** Expired items remain **readable via reads/queries/scans for up to ~48h** until the background deleter removes them. AWS's own guidance is that applications must **filter expired items at read time**. So TTL can never be the security boundary on its own.

Also decided (ADR context): the mock app is a **permission authority**, not a provisioner — it records Grants and answers "does this person hold elevated access now?"; it does not assign AWS access. (In production the real app would add the User to an AWS IAM Identity Center group.)

## Options

- **(1) DynamoDB TTL alone** — rely on TTL deletion to expire access. Rejected: up to ~48h of access *after* the window, i.e. a security hole.
- **(2) Scheduled sweep** — a periodic job marks/deletes expired Grants and (if provisioning) revokes external access. Necessary only if access is provisioned externally; adds a moving part and a lag equal to the sweep interval.
- **(3) On-read validity check** — every access check re-evaluates the clock and the Grant's ended-state; TTL is only storage cleanup.

## Choice

**Option (3), composed of three parts:**

1. **Time cap — enforced on read.** A Grant is active iff `now < granted_at + 8h`, evaluated at every access check. No background sweep.
2. **Incident close — webhook-driven state change.** On `public_incident.incident_status_updated_v2` with status → closed, mark **all** Grants tied to that Incident's escalations `ended(incident_closed)`. Reads reject ended Grants.
3. **DynamoDB TTL — housekeeping only.** Set at/after `granted_at + 8h` to delete stale rows. Never the security boundary.

**Elevated access** is the **union** of a person's active Grant windows (each escalation ack → its own 8h window), bounded by incident-close which ends them all together.

## Why

- Because the permission authority answers every check live, **access cannot outlive its window** — the on-read check *is* the enforcement, and it's mandatory anyway given the ~48h TTL read-lag.
- Making the authority on-read means **no sweep is needed** (the big simplification the permission-authority model buys) and the TTL lag becomes **harmless**.
- Incident-close is event-driven, so access drops promptly when the incident ends rather than waiting out the 8h cap.

## Consequences

- Every consumer of "does X have elevated access?" **must** go through the app's read check (or replicate `now`-filtering + ended-flag); a raw table scan is not a valid access check.
- The app must subscribe to `incident_status_updated` (closed) in addition to `escalation_status_updated` (acknowledged) — a second webhook event type in v1.
- No manual-revoke path exists; if "kill this person's access now" is ever required, it's a new enrichment (and ADR).
- If the app later becomes a **provisioner** (real IAM Identity Center assignment), expiry would need active de-provisioning — a scheduled sweep/revoker would then become load-bearing and this ADR must be revisited.
