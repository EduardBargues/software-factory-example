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

## 3. Authentication & tokens (how it works)

Two keyless/scoped token mechanisms — worth knowing when debugging a run. **Setting
them up** (the secrets, the WIF rule, minting the PAT) is the same for any factory
repo → see the hub's [**NEW-REPO-CHECKLIST**](https://github.com/EduardBargues/software-factory-example-home-repo/blob/main/docs/factory/NEW-REPO-CHECKLIST.md).

- **Claude auth (OIDC → Anthropic WIF).** No long-lived Claude key is stored. Per run GitHub mints a short-lived OIDC token (audience `https://api.anthropic.com`); `run-agent` writes it to a file and the CLI exchanges it, via a WIF **federation rule**, for a short-lived Claude token. The rule must match this repo's **immutable** subject `repo:<owner>@<owner_id>/<repo>@<repo_id>:*` (match by numeric id, not name; the `:*` covers both branch- and PR-triggered subjects). A mismatch shows `outcome: failure, reason: match_subject_prefix` in the Anthropic activity log.
- **FACTORY_PAT (cascade writes).** The built-in `GITHUB_TOKEN` can't trigger downstream workflows or make its PRs run CI, so the stage hand-offs (apply the next label, push, open the PR) use a fine-grained, **this-repo-only** PAT. The label is applied by the PAT owner (a collaborator), so the next stage's `Authorize the labeler` check passes. Write-mode checkouts use `persist-credentials: false` so no token sits in `.git/config` for the agent to read — the PAT is injected only at push/label steps. Mint/rotate with [`scripts/mint-factory-pat.sh`](../../scripts/mint-factory-pat.sh).

---

## 4. Operating it

- **Start work** — open an issue (as a collaborator it auto-enters), or apply `agent:explore` by hand to any existing issue.
- **Override a stage** — apply `agent:implement` or `agent:review` by hand to run that stage directly (e.g. after a `needs-a-human` verdict you judge safe).
- **Re-run a stage** — remove then re-add its label; re-adding an already-present label fires no event, so the remove is required.
- **Rebase a PR now** — add the `agent:rebase` label to a PR to rebase just that PR onto its base at once (the scheduled job rebases all open PRs each morning).
- **Merge** — review marks the PR ready; you merge. This is the final gate.

---

## 5. Debugging

**Where to look first:** the repo's **Actions** tab, the failing workflow's run. `run-agent` captures the CLI's stdout/stderr and, on failure, prints them in collapsed groups (short-lived tokens redacted) — so a failure is visible, not a black box.

**Reproduce an agent locally:** run the same `claude -p "<prompt>" --model … --permission-mode … --allowedTools … --disallowedTools …` the task uses. For auth, set the four `ANTHROPIC_*` identifiers and point `ANTHROPIC_IDENTITY_TOKEN_FILE` at a token file; **unset** `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` first (even empty, they shadow federation).

**Anthropic auth logs** (console) show denied exchanges with a reason — the fastest way to diagnose a WIF problem.

| Symptom | Cause | Fix |
|---|---|---|
| Auth log: `match_subject_prefix` denied | WIF Subject pattern doesn't match the OIDC `sub` | set it to `repo:<owner>@<owner_id>/<repo>@<repo_id>:*` (numeric ids, trailing `:*`) |
| `Claude Code is not installed on this repository` | tried to use the Claude GitHub App action | use the raw `claude -p` CLI (the `run-agent` harness) |
| `easy-call` verdict doesn't auto-advance | agent wrapped the verdict in backticks | parser extracts the token regardless (PR #27); prompt also emits plain text (PR #29 / #16) |
| merged PR leaves its issue open | PR body says "Implements #N" — not a GitHub close keyword | use `Closes #N` *(open follow-up)* |
| `pip`/`pip-audit` 401 | a token-gated private index | `PIP_CONFIG_FILE` points at public PyPI (`.config/pip/pip.conf`) |
| a stage silently didn't run | `GITHUB_TOKEN` applied the label instead of `FACTORY_PAT` | apply triggering labels via `FACTORY_PAT` |

---

## 6. Improving the factory (the retro loop)

The factory improves by turning each miss into a durable guardrail. Do not just fix the one case — move the rule down to the cheapest brake so it cannot recur.

**When to run it.** After a run gets something wrong that the brakes did not catch, or after you (the human reviewer) catch something the review run missed.

**Run `/retro`.** It is a human-invoked skill (`.claude/skills/retro`). Point it at the run's Actions logs or the merged PR. It audits the agent's environment and proposes improvements: navigation, automated checks, coding standards, steering files, tool economy, no-ops, and information access.

**Route each finding to the cheapest layer:**

| Finding | Route |
|---|---|
| Mechanical (a fixed pattern, a banned API, an import shape) | A **check** — a lint rule, a test, or a custom script. *Prefer this.* |
| Genuinely fuzzy (cross-file consistency, "matches the style") | A **coding standard** — a short line in `CODING_STANDARDS.md`. |
| A specific bug | A **regression guard** — a test, committed with the fix. |
| Process (about workflow, not the diff) | The spec or the config — not `CODING_STANDARDS.md`. |
| A no-op or a duplicate | **Delete** it. |

**Separate the fix from the guardrail.** Fix the bug in the feature PR. Build the guardrail in its own PR. The feature ships when it is correct; the guardrail protects every future PR.

**Roll out a new lint rule with the ratchet.** A new check often flags old code. Do not block on a big fix. Add the rule, then fix one case per day (the lint rule ratchet) until the rule is safe everywhere.

**Who owns what.** The implementer writes a first draft (it has the most context pressure). The review run enforces `CODING_STANDARDS.md` (it has a clean diff and spare context). `/retro` output, lint rules, and hooks live in `.github/` and config, so a human builds them — the agents cannot weaken their own brakes.

## 7. Known limitations

- **No factory-wide concurrency cap.** A single shared `concurrency` group is *not* used: GitHub keeps only one *pending* run per group and cancels earlier pending ones, which would silently **drop** queued factory work. Per-item groups dedup same-issue / same-PR runs; cross-issue fan-out is naturally low (sequential pipeline, single author). A hard cost cap needs a runner limit or external queue, not Actions concurrency.
- **"Implements #N"** in the implement PR template is not an auto-close keyword — merged PRs leave their issue open until closed by hand. *(Open follow-up.)*
- **Auto-merge is off** and deferred (criteria in [SPEC.md](SPEC.md) D8); a human merges every PR.
