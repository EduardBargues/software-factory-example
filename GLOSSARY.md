# Glossary — App (software-factory-example-python)

Repo-specific vocabulary for the application and its deploy. The shared,
repo-independent **factory** vocabulary (Factory, Task, Run, Verdict, Brake, Trust
ladder, FACTORY_PAT, …) now lives in the home repo's `GLOSSARY.md`; see the home
repo's `GLOSSARY-MAP.md` for the full map. Only terms unique to this repo belong
here. Use these exactly; avoid the listed alternatives.

## Deployment

- **Two-tier deploy** — the split between the **infra tier** (Terraform modules consumed from `software-factory-example-terraform`) and the **app-code tier** (e.g. a Lambda version/alias shift), mirroring a platform-team / product-team split. This repo owns the **persistent** deploy.
- **Apply-before-merge** — the infra-tier GitOps rule: plan → validate → human-triggered **apply on the PR branch** → merge **only** after apply succeeds, so `main` always reflects already-applied state. (Atlantis-style behavior, without installing Atlantis.)

## Testing

- **Seam** — the point at which behavior is tested. Prefer the highest seam and the fewest seams.
- **Port (hexagonal)** — an interface isolating the domain logic from AWS, so domain logic is tested with zero AWS; adapters (e.g. a DynamoDB store) are the only AWS-touching code.
- **Local AWS mock** — a Dockerized AWS emulator that Terraform can `apply` against for a local integration tier. Never authoritative for IAM.

## Application domain

_(App-domain terms for `src/` go here as they are coined — e.g. the grants domain. None recorded yet.)_
