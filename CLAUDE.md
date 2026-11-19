# software-factory-example

A reference **software factory** (an AI-agent pipeline that turns GitHub issues into reviewed, merged, and deployed changes) whose first workload is a mock AWS serverless app: signed incident.io webhooks → temporary elevated-access grants. See [`README.md`](README.md) for orientation.

Canonical design docs — read these before proposing changes, and use their terms exactly:

- [`docs/factory/SPEC.md`](docs/factory/SPEC.md) — spec for **the factory** (the agent pipeline; bootstrap, built by hand).
- [`docs/app/SPEC.md`](docs/app/SPEC.md) — spec for **the app** (incident.io webhook → permission-grant; the factory's first workload, built *by* the factory).
- [`GLOSSARY.md`](GLOSSARY.md) — canonical domain + factory vocabulary.
- [`docs/adr/`](docs/adr/) — Architecture Decision Records.

## Agent skills

### Issue tracker

Issues and specs are tracked in this repo's **GitHub Issues** (via the `gh` CLI). See `docs/agents/issue-tracker.md`.
