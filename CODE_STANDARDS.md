# Code Standards

The **fuzzy** conventions the `agent:review` brake enforces — the ones a deterministic check can't express. The deterministic rules already live in the brakes (`ruff`, `mypy`, `pytest`, `gitleaks`, `bandit`, `pip-audit`); this file is only for what a human reviewer would catch but a linter can't.

**How to use this file**

- **Prefer a check over a rule.** When you catch a miss, first ask: *can this be a deterministic check* (a lint rule, a test, a custom script)? If yes, add the check — it guards the repo every time, where the review agent is probabilistic and may miss it again. Only put it here if it is genuinely fuzzy.
- **Keep it lean.** This file rots into stale, duplicated, or vague rules ("sediment" / "no-ops") as entries pile up. `/retro` prunes it: delete anything that doesn't change behavior, and push anything mechanizable down into a check.
- Agents that build or review a change **follow** these standards but must **not edit** this file — it is a guardrail, curated by a human or `/retro`.

## Standards

1. **Smallest correct change.** Implement exactly the ticket; don't refactor or reformat unrelated code. Match the surrounding code's naming, structure, and **comment density** — read as the existing code reads, neither over-commenting nor narrating.
2. **Use the glossary's terms exactly.** Names, comments, and messages use the vocabulary in [`GLOSSARY.md`](GLOSSARY.md); avoid the listed alternatives so humans and agents don't drift.
3. **Test behavior at the highest useful seam, with the fewest seams.** Assert on observable behavior, not implementation detail. A passing suite should actually notice a regression.
4. **Keep domain logic free of I/O and cloud SDKs (hexagonal).** The domain is testable with zero AWS; adapters are the only cloud-touching code. Depend on ports, not concrete services.
5. **Treat all external input as untrusted.** Validate and sanitize at the boundary; never interpolate untrusted input into a query, command, or template.
6. **Security-sensitive code gets extra scrutiny.** Anything that authenticates, verifies a signature, or decides access is never a silent change — flag it for a human, and it is never an auto-merge candidate.
7. **Errors are actionable.** A failure says what went wrong and how to proceed; no bare tracebacks or vague messages as the user-facing result.
8. **Dependencies are a liability.** Add one only when it clearly pays for itself; it must be reputable, actively maintained, and CVE-clean. Prefer the standard library.
