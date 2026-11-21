# software-factory-example

A reference **software factory**: an AI-agent pipeline that turns GitHub issues into reviewed, merged, and (eventually) deployed changes — with humans holding the gates that matter while trust is earned. See [`README.md`](README.md) for orientation.

Canonical design docs — read these before proposing changes, and use their terms exactly:

- [`docs/factory/SPEC.md`](docs/factory/SPEC.md) — spec for **the factory** (the agent pipeline; bootstrap, built by hand).
- [`docs/factory/RUNBOOK.md`](docs/factory/RUNBOOK.md) — how to **operate, set up, and debug** the factory.
- [`GLOSSARY.md`](GLOSSARY.md) — canonical factory vocabulary.
- [`docs/adr/`](docs/adr/) — Architecture Decision Records.

## Agent skills

### Issue tracker

Issues and specs are tracked in this repo's **GitHub Issues** (via the `gh` CLI). See `docs/agents/issue-tracker.md`.
