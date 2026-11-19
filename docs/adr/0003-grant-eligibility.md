# ADR-0003 — Grant elevated access only to an on-call human acknowledger of an incident-associated escalation

- **Status:** Accepted
- **Date:** 2026-11-19

## Situation

The app grants elevated access when someone acknowledges an incident.io escalation. We initially assumed "every acknowledger is an on-call engineer." Research into incident.io's actual model disproved that:

- An escalation walks an **escalation path** level by level; **any responder on the path can acknowledge** — primary on-call, secondary, or a manager.
- The acknowledgement `actor` can be a **`user`, an `api_key`, or a `workflow`** — not necessarily a human.
- incident.io **pages without creating an incident** for support/questions, so an escalation does not imply an incident.
- incident.io does **not** guarantee the acknowledger is on an on-call schedule.

For a system that hands out elevated access, trusting the acknowledgement blindly is the central security risk.

## Options

- **(1) Grant on any acknowledgement** — simplest, but grants access to automation actors, off-rotation people, and non-incident pages.
- **(2) Grant to any human User who acked** — rejects `api_key`/`workflow`, but still grants to anyone on the path and to non-incident pages.
- **(3) Grant only to an on-call human for an incident-associated escalation** — three gates: human User ∧ member of the escalated Team's on-call rotation ∧ the escalation has an associated Incident.

## Choice

**Option (3).** A Grant is created **only if all three gates hold**:

1. the `actor` is a **human User** (refuse `api_key` / `workflow`);
2. that User is a **current member of the escalated Team's on-call rotation** (verified via an incident.io API call — not assumed);
3. the Escalation has an **associated Incident** (`related_incidents[]` non-empty).

Any gate failing → **refuse and log**, no Grant. v1 grants a single fixed elevated-access level; severity-scoped levels are a later enrichment (an Incident is guaranteed present when granting, so adding severity scoping is non-breaking).

## Why

- The "acknowledger is on-call" property must be an **enforced guard**, not an assumption the domain can trust — incident.io won't guarantee it.
- Refusing non-human actors, off-rotation people, and non-incident pages closes the three ways elevated access could leak to the wrong principal or situation.
- Gate (2) requires an extra incident.io API round-trip; accepted cost for a permission system.

## Consequences

- A **manager** who sits on the escalation path but is not on the escalated Team's rotation is **denied** — intentional.
- A **support/question page** with no incident yields **no** elevated access.
- The app depends on an incident.io API credential (to verify rotation membership) in addition to the webhook signing secret — both kept in env/Vault, never in Git.
- Revisit if the business later wants path-level-dependent or severity-dependent grants, or access for non-rotation responders.
