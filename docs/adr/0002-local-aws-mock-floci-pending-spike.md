# ADR-0002 — Local AWS mock for the integration tier: floci, pending a spike

- **Status:** Proposed (pending spike)
- **Date:** 2026-11-19

## Situation

The testing pyramid needs a local integration tier where `terraform apply` provisions the minimal serverless stack (Lambda + API Gateway HTTP API + DynamoDB) against a Dockerized AWS mock, so runs can drive the handler locally without touching real AWS. LocalStack was the default choice for this, but **LocalStack archived its open-source repo on 2026-03-23** and now requires an auth token with commercial/CI use behind a paid plan (and RDS was already Pro-gated). That change prompted a wave of 2026 alternatives.

## Options

- **floci** (`github.com/floci-io/floci`) — MIT, real Docker Lambda execution, HTTP API, DynamoDB, SQS, **real Postgres** for RDS, no paywalled services, runs Terraform/OpenTofu compat tests in CI. ~8 months old; IAM permissive by default; star count/marketing likely inflated.
- **MiniStack** (`github.com/ministackorg/ministack`) — MIT twin of floci; **real Postgres/MySQL containers**; claims terraform-aws-provider v6 support; IAM "not enforced" per its own docs.
- **moto server mode** (`moto_server`) — mature, fully free, but **weak on Lambda execution and SQS→Lambda event wiring**; can't faithfully run an event-driven stack.
- **Per-service emulators** — DynamoDB Local (official) + ElasticMQ for SQS; highest fidelity, but can't provision Lambda/APIGW, so they can't stand alone for a full `terraform apply`.
- **LocalStack** — most mature and most Terraform examples, but now paid for CI/commercial use and OSS repo archived.

## Choice

**Adopt floci for the integration tier, gated behind a one-hour spike.** Point floci at the real minimal Terraform and confirm `terraform apply` succeeds cleanly. If it passes: use floci, **pinned by image digest, dev/CI-only, never in the deployed path**. If the spike disappoints: fall back to **per-service emulators** (DynamoDB Local + ElasticMQ) for app-adapter integration, with the real-AWS tier carrying full-stack provisioning proof. MiniStack is the drop-in alternative if the spike favors its real-Postgres story.

## Why

- floci most directly targets the exact use case (`terraform apply` a Lambda+APIGW+DynamoDB stack locally), is MIT with no paywalled services, and actually runs Terraform compat tests in CI.
- The maturity and supply-chain risk (sub-1-year-old project, inflated marketing) is real, so a spike is the brake before committing — consistent with *accelerate only once you can brake*.
- **IAM is not enforced in any local mock.** Therefore a local-mock pass is **never** treated as IAM-validated; the real-AWS e2e tier is the sole authority on IAM and true fidelity. This neutralizes the biggest fidelity risk for a permission-granting app.

## Consequences

- A spike task must run before floci is wired into CI.
- The local mock image is pinned by digest and confined to dev/CI; production never depends on it.
- Least-privilege/IAM correctness is only ever asserted at the real-AWS tier.
- Revisit this ADR if floci's maintenance health deteriorates or the spike fails.
