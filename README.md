# software-factory-example

**A GitHub-native AI software factory.** Open an issue; get back a reviewed, merge-ready pull request — with no human writing the code, and humans holding only the gates that matter.

This repo is a working reference implementation: a label-triggered agent pipeline (powered by Claude Code) that turns tickets into merged, deployable changes, carrying real brakes from the first commit. It is deliberately small enough to read end-to-end and adapt to your own project.

> **Status:** built and auto-chaining end-to-end. A collaborator-opened issue flows explore → implement → review to a merge-ready PR with no manual labels. Two human gates remain: who may start a run, and who merges.

## What it does

```
issue  →  explore  →  implement  →  review  →  human merges  →  deploy
         (verdict)   (draft PR)   (fixes +                     (OIDC → AWS)
                                   marks ready)
```

A ticket becomes a pull request on its own. A read-only **explore** pass triages the issue and posts a verdict; **implement** builds the change and opens a draft PR; **review** fixes what is safe and flags the rest for a human; then a person makes the final merge call. Every step runs on GitHub Actions, and every commit goes through the brakes.

## Why it's different

- **Brakes before speed.** Three independent brakes gate every change (below). The rule is simple: *accelerate only once you can brake.*
- **Zero stored credentials.** The agent authenticates to Claude via GitHub OIDC → Anthropic Workload Identity Federation, and to AWS via OIDC-assumed IAM roles. No long-lived API keys or cloud keys live in the repo — GitHub mints a short-lived token per run.
- **Prompt-injection aware.** Issue and PR text is treated as **data, never instructions**. The explore pass runs read-only, so a malicious public issue can't make the factory run commands or leak secrets.
- **The agent can't weaken its own guardrails.** Agents are forbidden from editing `.github/`, the pre-commit hooks, or `.config/`, and may never commit with `--no-verify`. The factory's brakes are not something the factory can disable.
- **A trust ladder, not an on/off switch.** Human gates are removed one at a time, only after the logs show the agent reliably nails a hand-off. Today two gates remain; auto-merge is deliberately still off.
- **One swappable harness.** Every task invokes the agent through a single definition, so changing the model, CLI, or auth is a one-file change.

## The three brakes

Nothing reaches `main` that hasn't passed all three:

1. **Automated checks** — `ruff`, `mypy` (strict), `pytest` + coverage, plus the security brakes `gitleaks`, `bandit`, and `pip-audit`, run through a pre-commit hook the agent commits *through*.
2. **Automated review** — an `agent:review` run reviews the diff, fixes mechanical issues on the branch, and leaves only judgment calls for a human.
3. **Human review** — a person merges every pull request. Always, in v1.

## Security by default

- **No Claude credential stored** — GitHub OIDC is exchanged for a short-lived Claude token per run (Workload Identity Federation).
- **No AWS keys stored** — deploys assume scoped IAM roles via OIDC (a narrow read/plan role and a narrower deploy role).
- **Least privilege** — write-mode runs check out with no token left on disk; the automation PAT is fine-grained and scoped to this one repo.
- **Guarded entry** — only triage-or-above collaborators can start a run, so a stranger's issue on a public repo can't spend an agent.
- **Change-class awareness** — one-way-door and security-sensitive changes (auth, data migrations, infra) are never auto-merge candidates.

## Built for Python apps on AWS

Bring your own application. The factory targets a Python app deployed to AWS and ships a **two-tier deploy**: Terraform infrastructure with *apply-before-merge*, and application code that ships on merge via OIDC — reversible changes fast, one-way-door changes gated behind a human.

## How it's put together

| Path | What it is |
|---|---|
| [`docs/factory/SPEC.md`](docs/factory/SPEC.md) | The factory's design spec (bootstrap; built by hand) |
| [`docs/factory/RUNBOOK.md`](docs/factory/RUNBOOK.md) | How to operate, set up, and debug the factory |
| [`GLOSSARY.md`](GLOSSARY.md) | Canonical vocabulary (use these terms exactly) |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records |
| [`.github/workflows/`](.github/workflows/) | The pipeline: `auto-label`, `agent-explore`, `agent-implement`, `agent-review` |
| [`.github/actions/run-agent/`](.github/actions/run-agent/) | The single swappable agent harness |

## Architecture decisions

- [ADR-0001 — Single-repo, single-app topology](docs/adr/0001-single-repo-topology.md)
- [ADR-0005 — Enable explore→implement→review auto-chaining](docs/adr/0005-enable-pipeline-auto-chaining.md)

---

*The factory itself is **bootstrap work, built by hand** — it cannot build the pipeline that does not yet exist. Once the pipeline runs, the applications it builds are built by the factory.*
