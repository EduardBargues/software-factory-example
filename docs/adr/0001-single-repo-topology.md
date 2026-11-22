# ADR-0001 — Single-repo, single-app factory topology

- **Status:** Superseded by home-repo `ADR-0001 — Multi-repo factory with a home-repo hub` (`software-factory-example-home-repo/docs/adr/0001-multi-repo-home-repo-topology.md`), 2026-11-22
- **Date:** 2026-11-19

> **Superseded.** The deferred "separate infra repo … consumed by the app repo" named in the Choice below has been taken: infra now lives in `software-factory-example-terraform`, and shared agent steering lives in a home-repo hub. This ADR is kept for history. See the superseding ADR for the current topology.

## Situation

I want to build a software factory for Python apps deployed to AWS, starting from a mock application. The factory could target one repo, be a reusable template that every new repo adopts, or be a cross-repo meta-factory operating over many repos. The infra could also live in a separate repository (mirroring how a platform team owns Terraform repos that product teams consume).

## Options

- **(a) One repo, one app** — the factory and the app live together; GitHub Actions is the orchestrator for a single repo; app and infra changes are atomic.
- **(b) Template per repo** — a scaffold plus task definitions so every new Python-app repo is born wired to the factory.
- **(c) Cross-repo meta-factory** — one orchestrator whose tasks run across many repos.
- **(separate infra repo)** — a dedicated Terraform repo with its own GitOps apply flow, consumed by the app repo.

## Choice

**(a) One repo, one app**, with **infra and app code co-located** (path-separated `infra/**` vs `src/**`). Extracting a separate infra repo is deferred and will be done later *as a factory exercise* once infra stabilizes.

## Why

- The goal is to learn the factory loop, not to distribute at org scale. Single-repo keeps the orchestrator (GitHub Actions) simple: label triggers, one FACTORY_PAT scope, no cross-repo webhooks.
- While the app is small, infra and code **co-evolve constantly** (e.g. "add a DynamoDB table **and** the code that reads it" is one logical change). One repo keeps that atomic; two repos would force coordinated PRs with ordering hazards.
- Path-filtered workflows already give the infra tier its own lifecycle (plan → apply-before-merge → merge) and its own OIDC role inside one repo — ~80% of the separation benefit without the cross-repo tax.
- Graduating to a separate infra repo later is itself a good proof that the factory can operate cross-repo.

## Consequences

- The factory design is captured in [`docs/factory/SPEC.md`](../factory/SPEC.md) (the pipeline, bootstrapped by hand); the application it builds lives in the **same repo** (`src/` + `infra/`). Keeping them together is a separation of *concern and lifecycle*, not of repository; splitting into two repos remains deferred per the Choice above.
- FACTORY_PAT is scoped to exactly one repo.
- Infra vs app lifecycles are distinguished by path filters, not repo boundaries.
- If faithfully reproducing the work's platform/product **repo** boundary later becomes a goal, revisit this ADR.
