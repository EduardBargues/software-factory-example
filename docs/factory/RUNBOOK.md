# Factory Runbook

How to **operate, set up, and debug** the software factory. For *what the factory is and why*, see [`SPEC.md`](SPEC.md); for the decision to auto-chain, see [ADR-0005](../adr/0005-enable-pipeline-auto-chaining.md).

> The factory is **bootstrap, built by hand**. The agent tasks must never edit `.github/`, `.pre-commit-config.yaml`, or `.config/`, so every change in this runbook is a hand-authored PR through branch protection.

---

## 1. The automated flow

A collaborator-opened issue reaches a review-ready PR with **no manual labels**:

```
issue opened by a collaborator
        │  auto-label  (checks author is triage+)
        ▼
  agent:explore ──► read-only verdict comment
        │  on VERDICT: easy-call  (else: stop for a human)
        ▼
  agent:implement ──► builds, commits through the brakes, opens a DRAFT PR
        │  after the PR opens
        ▼
  agent:review ──► fixes what is safe, marks the PR READY
        │
        ▼
     HUMAN MERGES          ◄── the one remaining gate
```

**Two human gates remain:** (1) only a **collaborator-authored** issue auto-enters, and (2) a **human merges** every PR. Everything between is agent-driven. `needs-a-human` / `blocked` verdicts stop at the explore comment. Auto-merge is off.

| Stage | Workflow | Trigger | Hands off by |
|---|---|---|---|
| entry gate | `auto-label.yml` | `issues: opened` | adds `agent:explore` (if author is triage+) |
| explore | `agent-explore.yml` | `issues: labeled` | adds `agent:implement` on `easy-call` |
| implement | `agent-implement.yml` | `issues: labeled` | opens draft PR, adds `agent:review` |
| review | `agent-review.yml` | `pull_request: labeled` | marks PR ready |
| merge | — | human | — |

Labels accumulate as an **audit trail** (they are never removed).

---

## 2. Components

- **Workflows** — the four above, in `.github/workflows/`.
- **`run-agent`** (`.github/actions/run-agent/`) — the single swappable agent harness. Every task invokes Claude through here, so changing the model, CLI, or auth is a one-file change. v1 harness: the Claude Code CLI run headless (`claude -p`).
- **Brakes** — `ruff`, `mypy` (strict), `pytest` + security brakes `gitleaks`, `bandit`, `pip-audit`, all via `pre-commit`, plus `actionlint` on workflow files. The agents commit **through** the hook; a PR's own `brakes` CI re-runs them as the required status check.
- **Branch protection on `main`** — PR-only, `enforce_admins`, required check `brakes`, `delete_branch_on_merge`.

---

## 3. Authentication (GitHub OIDC → Anthropic WIF)

**No long-lived Claude credential is stored anywhere.** Per run, GitHub mints a short-lived **OIDC token**; the CLI exchanges it, via Anthropic **Workload Identity Federation**, for a short-lived Claude token scoped to this repo.

- The workflow grants `id-token: write`. `run-agent` requests an OIDC token with audience `https://api.anthropic.com`, writes it to a file, and exports `ANTHROPIC_IDENTITY_TOKEN_FILE`.
- With that file set and **no** `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`, the CLI performs the federation exchange and refreshes as needed.

### Repo secrets (identifiers, **not** credentials)

These are useless without a valid GitHub OIDC token from *this* repo. They are secrets only to keep the Anthropic org out of a public repo.

| Secret | What it is |
|---|---|
| `ANTHROPIC_FEDERATION_RULE_ID` | WIF federation rule (`fdrl_…`) |
| `ANTHROPIC_ORGANIZATION_ID` | Anthropic organization id |
| `ANTHROPIC_SERVICE_ACCOUNT_ID` | service account the token acts as (`svac_…`) |
| `ANTHROPIC_WORKSPACE_ID` | workspace the token is scoped to (`wrkspc_…`) |
| `FACTORY_PAT` | fine-grained PAT, this repo only — see §4 |

### The WIF federation rule

In the Anthropic console, the rule must accept this repo's GitHub OIDC identity:

- **Audience:** `https://api.anthropic.com`
- **Subject pattern:** `repo:<owner>@<owner_id>/<repo>@<repo_id>:*`
  GitHub embeds **numeric** owner/repo ids in the `sub`, so match by id, not name. The trailing `:*` covers both `ref:refs/heads/<branch>` (issue-triggered runs) **and** `pull_request` (PR-triggered runs) subjects — so review runs authenticate with the same rule.
- **OAuth scope:** `workspace:developer`.

---

## 4. FACTORY_PAT — why a PAT, and its scope

The built-in `GITHUB_TOKEN` **cannot trigger downstream workflows** (an anti-loop guard) and PRs it opens do not run CI. The factory *cascades* — each stage applies the next label, and implement opens a PR that must run its own brakes — so those writes use `FACTORY_PAT`:

- auto-label applies `agent:explore`; explore applies `agent:implement`; implement pushes the branch, opens the PR, applies `agent:review`; review pushes fixes and marks ready.
- Because the label is applied by the PAT's owner (a collaborator), the next workflow's `Authorize the labeler` check passes.

**Scope:** fine-grained, this repo only; read/write on Actions, Issues, Pull requests, Contents, Workflows; everything else no-access; with an expiry. Mint/rotate it with [`scripts/mint-factory-pat.sh`](../../scripts/mint-factory-pat.sh).

**Least-privilege note:** write-mode checkouts (implement, review) use `persist-credentials: false` so no token sits in `.git/config` for the agent (which has `Bash`) to read; the PAT is injected only in the push/label steps.

---

## 5. Operating it

- **Start work** — open an issue (as a collaborator it auto-enters), or apply `agent:explore` by hand to any existing issue.
- **Override a stage** — apply `agent:implement` or `agent:review` by hand to run that stage directly (e.g. after a `needs-a-human` verdict you judge safe).
- **Re-run a stage** — remove then re-add its label; re-adding an already-present label fires no event, so the remove is required.
- **Merge** — review marks the PR ready; you merge. This is the final gate.

---

## 6. Debugging

**Where to look first:** the repo's **Actions** tab, the failing workflow's run. `run-agent` captures the CLI's stdout/stderr and, on failure, prints them in collapsed groups (short-lived tokens redacted) — so a failure is visible, not a black box.

**Reproduce an agent locally:** run the same `claude -p "<prompt>" --model … --permission-mode … --allowedTools … --disallowedTools …` the task uses. For auth, set the four `ANTHROPIC_*` identifiers and point `ANTHROPIC_IDENTITY_TOKEN_FILE` at a token file; **unset** `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` first (even empty, they shadow federation).

**Anthropic auth logs** (console) show denied exchanges with a reason — the fastest way to diagnose a WIF problem.

| Symptom | Cause | Fix |
|---|---|---|
| Auth log: `match_subject_prefix` denied | WIF Subject pattern doesn't match the OIDC `sub` | set it to `repo:<owner>@<owner_id>/<repo>@<repo_id>:*` (numeric ids, trailing `:*`) |
| `Claude Code is not installed on this repository` | tried to use the Claude GitHub App action | use the raw `claude -p` CLI (the `run-agent` harness) |
| `easy-call` verdict doesn't auto-advance | agent wrapped the verdict in backticks | parser extracts the token regardless (PR #27); prompt also emits plain text (PR #29 / #16) |
| merged PR leaves its issue open | PR body says "Implements #N" — not a GitHub close keyword | use `Closes #N` *(open follow-up)* |
| `pip`/`pip-audit` 401 | a private index token (e.g. CodeArtifact) | `PIP_CONFIG_FILE` points at public PyPI (`.config/pip/pip.conf`) |
| a stage silently didn't run | `GITHUB_TOKEN` applied the label instead of `FACTORY_PAT` | apply triggering labels via `FACTORY_PAT` |

---

## 7. Known limitations

- **No factory-wide concurrency cap.** A single shared `concurrency` group is *not* used: GitHub keeps only one *pending* run per group and cancels earlier pending ones, which would silently **drop** queued factory work. Per-item groups dedup same-issue / same-PR runs; cross-issue fan-out is naturally low (sequential pipeline, single author). A hard cost cap needs a runner limit or external queue, not Actions concurrency.
- **"Implements #N"** in the implement PR template is not an auto-close keyword — merged PRs leave their issue open until closed by hand. *(Open follow-up.)*
- **Auto-merge is off** and deferred (criteria in [SPEC.md](SPEC.md) D8); a human merges every PR.
