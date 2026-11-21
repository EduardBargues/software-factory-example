# ADR-0005 — Enable explore→implement→review auto-chaining

- **Status:** Accepted
- **Date:** 2026-11-21

## Situation

The factory's v1 design ([`SPEC.md`](../factory/SPEC.md) D8) kept **all five human gates manned**: a human applied every `agent:*` label by hand and merged every PR. Story 11 anticipated removing gates "one at a time, starting with explore→implement auto-chaining, only after `/retro` shows the agent reliably nails that hand-off."

All three tasks (explore, implement, review) were then proven end-to-end on canary tickets — explore posts sound verdicts, implement opens clean draft PRs through the brakes, review fixes safely and surfaces real judgment calls. The manual label hand-offs between them had become pure typing, not judgment.

## Options

- **(a) Keep all gates manual** — maximum control; a human reads every verdict and types every label.
- **(b) Auto-chain explore→implement→review; keep entry + merge gates** — the agent's verdict drives the next label; a human still chooses what enters and what merges.
- **(c) Full autonomy** — also auto-merge on green.

## Choice

**(b).** The pipeline self-advances from a collaborator-opened issue to a review-ready PR with no manual labels. **Two human gates remain:**

1. **Entry** — a new `auto-label` workflow applies `agent:explore` only when the **issue author is a collaborator** (triage+). Non-collaborator issues never enter.
2. **Merge** — review marks the PR ready; a **human merges**. Auto-merge stays off entirely (option (c) deferred, criteria in SPEC D8).

The agent's own output is the hand-off signal: explore applies `agent:implement` only on a `VERDICT: easy-call` (other verdicts stop for a human); implement applies `agent:review` once the draft PR opens.

## Why

- **The verdict already *is* the decision.** explore classifies blast radius and door and emits `easy-call` / `needs-a-human` / `blocked`. On `easy-call` a human was adding no information by typing the next label; on the other verdicts, the chain still stops for a human — so judgment is preserved exactly where it matters.
- **The brakes are load-bearing, so acceleration is safe.** Every agent commit goes through pre-commit; every PR runs the required `brakes` check; review is itself a brake. "Accelerate only once you can brake" — we can brake.
- **The two kept gates cover the irreversible/outward risks.** Entry stops a public-repo stranger from spending agent runs; merge keeps a human on the one-way door to `main` (which will later feed deploy).

## Consequences

- **New entry filter.** `auto-label` is the single place that decides what enters the factory; the three agent workflows just react to labels. See [`RUNBOOK.md`](../factory/RUNBOOK.md) §1.
- **Cascade requires `FACTORY_PAT`.** A `GITHUB_TOKEN`-applied label can't trigger the next workflow, so every hand-off label is applied via `FACTORY_PAT`.
- **Labels accumulate** as an audit trail (not removed on hand-off).
- **No factory-wide serialization.** A single shared `concurrency` group was considered for cost but rejected: GitHub cancels earlier *pending* runs in a group, which would drop queued work. Per-item dedup stays. (RUNBOOK §7.)
- **Auto-merge remains the next rung**, gated on `/retro` evidence per SPEC D8 — this ADR does not enable it.
- SPEC D8, the Solution shape, and story 11 are updated to reflect this; the README "at a glance" no longer says "no auto-chaining."
