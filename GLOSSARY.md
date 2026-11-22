# Glossary — Software Factory

Shared, canonical vocabulary for this project. Use these terms exactly; avoid the listed alternatives so the agent and the humans don't drift.

## Factory structure

- **Factory** — a system of agents that turns tickets, PRs, and schedules into merged (and eventually deployed) code on remote infrastructure. _This repo's factory is bespoke to a single application._
- **Service** — a slot in the factory filled by a product: ticket tracker, git host, runner, orchestrator, observability platform.
- **Ticket tracker** — where tickets live and the factory's human interface. Here: **GitHub Issues**. _Avoid: issue tracker, project board._
- **Git host** — where branches, PRs, and reviews live. Here: **GitHub**.
- **Runner** — the disposable machine a **run** executes on; nothing on it survives the run. Here: **GitHub Actions** ephemeral VMs. _Avoid: server, box, sandbox._
- **Orchestrator** — receives triggers, starts runs, records what's queued/in-flight/finished. Here: **GitHub Actions** (same product as the runner). _Avoid: dispatcher, scheduler._
- **Observability platform** — where runs' logs/traces are seen. Here: GitHub Actions run logs + the `/retro` task. _(Langfuse deferred.)_
- **Harness** — the coding agent/model a run drives. Here: **Claude Code**, behind a single swappable agent definition imported by every task.

## Work units

- **Task** — a kind of work the factory performs, defined once and run many times (a GitHub Actions workflow): explore, implement, review, deploy. _Avoid: job, workflow (in prose), action._
- **Trigger** — the event that starts a run: a label change, a clock, or another run.
- **Run** — one execution of a task on one runner, from trigger to finish, treated as a black box. A run never waits for a human; it ends, and a human's later change triggers a new run. _Avoid: session._
- **Verdict** — the explore run's classification of a ticket: `easy-call`, `needs-a-human`, or `blocked`.
- **Label (`agent:*`)** — both the trigger for a task and the hand-off between tasks; applying one is an **approval** only a triage-role-or-above collaborator can give.

## Quality & control

- **Brake** — a control that stops a bad change. The factory has three brakes, from cheapest to most expensive: automated check, automated review, human review.
- **Automated check** — the first brake; deterministic (ruff/mypy/pytest + gitleaks/bandit/pip-audit). It fails the same way every time. Push every mechanizable rule down to this layer.
- **Automated review** — the second brake; the `agent:review` run. It is an agent, so it is probabilistic; it can miss a thing it caught before.
- **Human review** — the third brake; a person before the merge. The most expensive brake; use `/retro` to move its catches down to a lower brake.
- **Bug** — a wrong change. A brake or a human finds it. _Avoid: defect._
- **Lint rule** — an automated check that encodes a rule the built-in checks cannot express. The preferred home for a mechanizable rule.
- **Coding standard (`CODING_STANDARDS.md`)** — a **fuzzy** rule the automated-review brake enforces, for a thing no check can express. Use it only when no check fits. Grown and pruned via `/retro`; build and review runs follow it but never edit it.
- **No-op** — a standard line you can delete with no change to the agent output. Cut it.
- **Sediment** — stale, duplicate, or contradictory standards. Prune them.
- **Trust ladder** — removing human gates one at a time as `/retro` shows the agent reliably handles a hand-off. v1 keeps **two gates manned** — collaborator-only entry and human merge — with explore→implement→review auto-chained ([ADR-0005](docs/adr/0005-enable-pipeline-auto-chaining.md)).
- **Two-way door / one-way door** — a reversible vs hard-to-reverse change; drives blast-radius and auto-merge eligibility.

## Feedback loop

- **Retro (`/retro`)** — the task that audits a run or a file. For each finding, it chooses one route: a check, a coding standard, or delete.
- **Lint rule ratchet** — the workflow to roll a new lint rule over an existing repo. Each day, find one failing case and open a PR to fix one. The repo gets safer each day, until the rule is safe everywhere.
- **Regression guard** — a test added with a bug fix. It stops the bug from a return.
- **Data source** — a part of the agent environment it reads to verify its work: logs, a database, the UI, the issue tracker. More and better data gives better output.

## Deployment

- **Two-tier deploy** — the split between the **infra tier** (Terraform) and the **app-code tier** (e.g. a Lambda version/alias shift), mirroring a platform-team / product-team split.
- **Apply-before-merge** — the infra-tier GitOps rule: plan → validate → human-triggered **apply on the PR branch** → merge **only** after apply succeeds, so `main` always reflects already-applied state. (Atlantis-style behavior, without installing Atlantis.)
- **FACTORY_PAT** — the fine-grained, single-repo, expiring GitHub token the tasks use to trigger downstream runs and open PRs (the built-in `GITHUB_TOKEN` can't).

## Testing

- **Seam** — the point at which behavior is tested. Prefer the highest seam and the fewest seams.
- **Port (hexagonal)** — an interface isolating the domain logic from AWS, so domain logic is tested with zero AWS; adapters (e.g. a DynamoDB store) are the only AWS-touching code.
- **Local AWS mock** — a Dockerized AWS emulator that Terraform can `apply` against for a local integration tier. Never authoritative for IAM.
