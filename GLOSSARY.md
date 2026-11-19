# Glossary — Software Factory

Shared, canonical vocabulary for this project. Use these terms exactly; avoid the listed alternatives so the agent and the humans don't drift.

## App domain (the webhook → permission app)

- **Team** — a group of engineers. Every Team owns an on-call rotation.
- **On-call rotation** — a Team's roster of engineers who take turns being on call; its **members** are those engineers. Every Team has one.
- **On-call engineer** — the member currently on call for a Team: the **first responder** an Escalation pages first. _Narrower than "rotation member": at any moment one member is the active on-call engineer._
- **Escalation** — incident.io paging someone to respond, walking a Team's escalation path level by level until acknowledged. May or may not be associated with an Incident.
- **Acknowledgement** — the event of an Acknowledger accepting ("acking") an Escalation (an escalation status change to `acknowledged`). Delivered to the app as a **signed** incident.io webhook.
- **Acknowledger** — the **human User** who acknowledged an Escalation. _Not guaranteed to be an on-call engineer or even human — the app enforces that (see Grant eligibility). Avoid: responder, on-call (ambiguous alone)._
- **Incident** — a declared disruption being responded to. An Escalation may or may not have one; **an associated Incident is required for a Grant** (escalations without an incident are support/questions and earn no elevated access).
- **Alert** — an upstream signal that can trigger an Escalation. The app does not read Alert data (only correlation ids). _Named for context; not modeled._
- **Elevated access** — the privileged capability a Grant confers on its Acknowledger while the Grant is **active**. In production: membership in a specific **AWS IAM Identity Center** group. In this app — a permission **authority**, not a provisioner — it is a single named access level the app **asserts** and consumers **check**, not something provisioned in AWS. A person has elevated access **iff** they hold **≥1 active Grant** _at the moment of the check_ — the **union** of their Grant windows.
- **Grant** — a time-boxed conferral of **elevated access**, keyed by **(Acknowledger, Escalation)** and created only when **Grant eligibility** holds. A Grant is **active** from creation until it **ends**, with reason `time_expired` (**8 hours** after that acknowledgement) or `incident_closed` (whichever comes first). There is **no manual revocation**. Several escalations acked by one person for the same Incident yield several overlapping Grants; their **union** is how long that person keeps elevated access. v1 confers a single fixed level. _Temporary by rule: access cannot outlive its window._
- **Grant eligibility** — the rule that an Acknowledger receives a Grant **only if all three hold**: (1) the actor is a **human User**; (2) that User is a **current member of the escalated Team's on-call rotation**; (3) the Escalation has an **associated Incident**. A manager (or anyone) not on that rotation, and any `api_key`/`workflow` actor, is refused.

## Factory structure

- **Factory** — a system of agents that turns tickets, PRs, and schedules into merged (and eventually deployed) code on remote infrastructure. _This repo's factory is bespoke to one app._
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

- **Brake** — a control that stops bad changes. The three brakes: **automated checks** (deterministic: ruff/mypy/pytest + gitleaks/bandit/pip-audit), **automated review** (the `agent:review` run), **human review** (a person before merge).
- **Trust ladder** — removing human gates one at a time as `/retro` shows the agent reliably handles a hand-off. v1 has all five gates manned.
- **Two-way door / one-way door** — a reversible vs hard-to-reverse change; drives blast-radius and auto-merge eligibility.

## Deployment

- **Two-tier deploy** — the split between the **infra tier** (Terraform) and the **app-code tier** (Lambda version/alias), mirroring a platform-team / product-team split.
- **Apply-before-merge** — the infra-tier GitOps rule: plan → validate → human-triggered **apply on the PR branch** → merge **only** after apply succeeds, so `main` always reflects already-applied state. (Atlantis-style behavior, without installing Atlantis.)
- **FACTORY_PAT** — the fine-grained, single-repo, expiring GitHub token the tasks use to trigger downstream runs and open PRs (the built-in `GITHUB_TOKEN` can't).

## Testing

- **Seam** — the point at which behavior is tested. Prefer the highest seam and the fewest seams.
- **Port (hexagonal)** — an interface isolating the domain (permission decision) from AWS, so domain logic is tested with zero AWS; adapters (e.g. the DynamoDB `PermissionStore`) are the only AWS-touching code.
- **Local AWS mock** — a Dockerized emulator (floci, pending spike) that Terraform can `apply` against for the local integration tier. Never authoritative for IAM.
