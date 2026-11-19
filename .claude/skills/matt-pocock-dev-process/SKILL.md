---
name: matt-pocock-dev-process
description: Distilled knowledge from Matt Pocock's walkthrough "Watch me ship a 21,000-line feature with @mattpocock skills". Load when the user's problem involves an AI-coding development process end to end — grilling / domain modeling before building, choosing between one-shot vs grill-with-docs vs wayfinder, writing a glossary and ADRs, scenario-testing a name, prototyping for UX feel, reducing an agent's decision space, spec → tickets → AFK implement, reviewing a huge PR via stacked diffs and feature flags, ratcheting lint rules from review comments, running a retro over many sessions, or the smart-zone/dumb-zone context question. Built from the video transcript; may be loaded alongside other skills when a problem spans sources.
---

# Watch me ship a 21,000-line feature — Video Notes

Distilled knowledge from the video **"Watch me ship a 21,000-line feature with @mattpocock skills"**, by **Matt Pocock**. Use this when the user is stuck on a problem about running an AI-coding workflow end to end — aligning before building, domain modeling, prototyping, reducing the agent's decision space, reviewing large PRs, and feeding review back into the system: scan the **When it helps** entries to find a match, then follow the **Source** link to the transcript for full context.

**When the question is more detailed than the entries here, or this skill has no entry that covers it, read the full transcript (`./matt-pocock-dev-process.transcript.txt`) before answering.** These notes are a routing map, not the whole video — the transcript is the source of truth. Search it for the relevant part rather than guessing or filling the gap from general knowledge, and if the transcript doesn't address it either, say so plainly.

_Transcript provenance: **auto-generated captions** (expect mistranscribed names/terms — e.g. the captions render "Wayfinder" as "Wavefinder", "grill-with-docs" as "grill with docks", "glossary" as "glossery"; names below are corrected)._ _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)

## Summary

Matt Pocock walks through his real end-to-end process shipping a ~21,000-line feature (an in-place thumbnail-diagram editor) to his personal course-video-manager app. The spine is two skills: **grill-with-docs** at the start (where he spends most of his human effort doing domain modeling — nailing the *language* of the feature against a glossary and ADRs — and prototyping for UX feel) and **retro** at the end (reviewing the big PR and feeding what he dislikes back into coding standards, lint rules, and skill improvements). The throughline: humans are most valuable in the **alignment phase** (start) and **review/taste phase** (end); everything between — spec, tickets, AFK implementation — should be put "on rails" by removing the agent's decision space. Secondary themes: smart-zone vs dumb-zone context, reviewing a huge PR via stacked diffs and feature flags, and ratcheting lint rules over time.

**Vocabulary**

| Term | Source | Description |
| --- | --- | --- |
| **`/grill-with-docs`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Matt's grilling skill that brings the project's docs (glossary, ADRs) into context while it interrogates you about a feature. He uses it mainly for **domain modeling** — figuring out the language of the feature — and it can spin up background sub-agents (e.g. to prototype) while you keep grilling. His default starting point for non-trivial work. |
| **`/wayfinder`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A skill for work too large for one grilling session: it runs grilling over multiple sessions to develop a big concept and drive toward it. You "bail out" into Wayfinder from grill-with-docs if the work turns out larger than expected. |
| **`/prototype`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A skill that builds **multiple UI variants** of an approach so you can make feel-based decisions by trying them, not describing them. Runs as a background sub-agent during grilling. |
| **`/to-spec`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A user-invoked skill (must be at the very start of the prompt in Claude Code) that writes a **specification** — a "destination document" of user stories, implementation decisions, and out-of-scope notes — as a GitHub issue. |
| **`/to-tickets`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Breaks a spec into **tickets** (sub-issues), each scoping one session/sub-agent's work, with blocked-by relationships so they can be parallelized. |
| **`/implement-spec`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | An AFK skill that takes the spec + tickets and implements them locally, running tickets in parallel where possible, then produces a single review-ready PR (with a built-in code review against coding standards). |
| **`/retro`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A retrospective skill run over a chunk of work: it reads the locally-saved session transcripts plus your PR review comments (via the GitHub CLI) and returns a ranked list of improvements to your environment, standards, and skills. Matt's other main interaction point besides grilling. |
| **`/code-review`** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | The skill `implement-spec` runs to review the PR against coding standards; it flags hard violations and scope creep and fixes them. Noted to struggle on very large diffs with a single agent. |
| **Glossary (ubiquitous language)** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A file (here `glossary.mmd`, ~560 lines) defining every core concept in the project. Keeping it in the agent's context lets you communicate rich, precise intent in a few words; growing it *is* designing the feature and its data model. |
| **ADR (Architectural Decision Record)** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A record of *why* a decision was made (the glossary/code say what *is*; ADRs say *why*). Written for non-obvious, consequential decisions. They are the "fences" that stop future runs from guessing or wrongly reversing a mature decision. |
| **Scenario testing** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A technique for choosing a domain term: the agent lays out candidate names in a table and writes example sentences for each, scoring how naturally each reads — including "does it match my actual mental model / how I talk". |
| **Smart zone / dumb zone** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Beyond ~150k tokens an agent gets gradually worse because the relationships it must track grow quadratically. Matt (crediting Dex Horthy of HumanLayer/Factory) now frames it less as hallucination risk and more as a quality-and-cost optimization: fewer tokens → better, cheaper work. |
| **Two-way door / one-way door** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A two-way-door PR can be merged and reverted freely; a one-way door is hard to undo (touches data, external services, security). Definitions live in his PR skill; used to decide review rigor and merge order. |
| **Stacked diffs** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Breaking one massive PR into a sequence of smaller, independently-reviewable PRs — ideally a run of two-way doors ending in a single one-way door. |
| **Ratcheted lint rule** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | A deterministic rule you don't fully enforce on day one but tighten over time, driving a pattern out of the codebase gradually from a large existing baseline. |
| **Soft delete** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Marking a record archived instead of hard-deleting it, so valuable data can be recovered and links aren't broken ("not lossy"). Matt's default for valuable data, with an eventual cleanup cycle in multi-user apps. |
| **Compact** | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Squashing a conversation down to a small context. Near-free and safe once the conversation has been turned into a document (spec) — unlike dodgy auto-compact, which can drop something important at a bad moment. |

**Key Concepts**

| Concept | When it helps | Source | Description |
| --- | --- | --- | --- |
| **Prompt the "why", not the "what"** | Your agent keeps producing literal, uncreative solutions | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Give the agent the problem and the reason, not a prescribed solution. It then feels empowered to design a solution or discuss one; handing it a rigid "do X, Y, Z" suppresses creativity. |
| **Language-first: once you have the words, you have the app** | You don't know how to model a feature or what you're even building | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Nailing the domain language yields the data model — the names become tables, modules, and references. Loose language early becomes a precise, shared concept by the end of grilling, at which point "we've kind of built the feature." |
| **Align before building puts everything on rails** | Agent output is unpredictable and you keep redirecting mid-build | [`transcript`](./matt-pocock-dev-process.transcript.txt) | The alignment moment (ideally with teammates) fixes what you're building and its words; from there to human review the work is largely predictable. Strong up-front understanding beats correcting course later. |
| **Reduce the agent's decision space before AFK** | An AFK agent drifts or makes bad calls during implementation | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Every decision you leave open is a chance to choose badly. By implementation time the glossary, spec, tickets, and prototype should leave the agent almost nothing to decide — just "plug the two things together." |
| **Prototypes decide feel; a bad one teaches as much as a good one** | A decision is really about UX feel you can't judge from a description | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Build several variants and try them. Something you dislike often tells you more than something you like, giving the agent a rich view of what you actually want before any real build. |
| **ADRs guard fences (Chesterton's fence)** | You're about to change or remove mature code you don't fully understand | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Don't tear down a fence until you know why it was built. ADRs record the *why* behind mature decisions so future runs (and you) don't reverse them blindly. Investing in them during grilling compounds: future runs get better context. |
| **You drive the grilling, not the agent** | A grilling session feels endless and you don't know when to stop | [`transcript`](./matt-pocock-dev-process.transcript.txt) | You're in a conversation, not being interrogated. Stop when you're aligned ("yes, yes, yes"), and narrow focus on demand ("ask me one question at a time until I say otherwise"). Grilling is also a ritual that keeps you in touch with the codebase and surfaces backlog items. |
| **Review the system, not just the code** | You spot a pattern you dislike in agent-generated code | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Treat a disliked pattern as a hypothesis that your agent's environment is wrong, and turn it into a lint rule / coding standard / ADR so it can't recur — rather than just fixing this instance. Human review feeds automated review and checks. |
| **Humans are most valuable at the ends** | Deciding where to spend your own time in an agent workflow | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Matt's leverage is the **alignment phase** at the start (talk it through, prototype, agree the language and data model) and the **review/taste phase** at the end (impose standards, say "that looks bad, do this"). The middle runs AFK. |
| **Smart zone beats dumb zone — on quality and cost** | Long sessions are producing worse or very expensive work | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Current models don't need hard clears at 80–120k like older ones; past ~150k they just get gradually worse and far more expensive (re-running tokens once cache expires). Prefer doing work in the smart zone; spin up a clean sub-agent for a hard isolated problem instead of continuing a bloated one. |
| **Keep one shared editor and one search** | You're tempted to build a second, slightly different version of an existing UI | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Two subtly different editors/searches create constant "paper cuts" for users (often you). Extract a single shared component and reuse one search behavior everywhere. |

**Decision Log**

**Decision — Which skill to start a new piece of work with**

_When it helps:_ you're starting a new task and don't know whether to just let the agent build it or to do heavy up-front thinking. _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)
- **Situation:** A new, fuzzy feature ("edit a diagram in place beside my face") where he doesn't yet know how to build it.
- **Options considered:** One-shot it (no grilling); start with `/grill-with-docs`; go straight to `/wayfinder`.
- **Choice:** Start with `/grill-with-docs`.
- **Why:** The target *diff* is clearly too big to one-shot, so some alignment is needed — but start with grill-with-docs rather than Wayfinder, because if the work turns out smaller than feared you avoid Wayfinder's multi-session overhead, and you can always bail *up* into Wayfinder if it turns out larger.

**Decision — Mix the data-model streams, or keep them separate**

_When it helps:_ you must decide whether a new feature reuses a mature existing data model or gets its own. _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)
- **Situation:** The new thumbnail drawing could reuse the mature, heavily-coded diagram/diagram-snapshot model, or be modeled separately. A large, consequential, hard-to-feel decision — "the moment I'd reach out to colleagues."
- **Options considered:** Tie into / extend the existing diagram-snapshot model ("mix the streams"); or a separate model that only records where a drawing came from.
- **Choice:** Keep them separate, recording one nullable "started-from-snapshot" reference when you copy.
- **Why:** Both sides store the same scene format, so copying between them is trivial either way; the link you actually want is *provenance* (where a drawing came from), not a joined model; keeping them separate preserves flexibility and isn't lossy, and no concrete use case justified staying coupled.

**Decision — What to name the new concept**

_When it helps:_ you can't settle on a domain term and the candidates all feel slightly wrong. _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)
- **Situation:** The thumbnail's editable drawing is neither a "diagram" nor a "diagram snapshot" (snapshots are immutable); a name is needed that fits the glossary.
- **Options considered:** `thumbnail diagram`, `thumbnail diagram snapshot`, `thumbnail scene`, `thumbnail drawing` (scenario-tested in a table).
- **Choice:** `thumbnail diagram`, plus an ADR noting it's a diagram-but-not-a-real-diagram.
- **Why:** It's what he naturally says (matches his mental model); "scene" collides with an existing concept and is coding-vocabulary; "snapshot" implies immutability; "drawing" clashes with "diagram"; the fully-precise "thumbnail diagram snapshot" is too long. He weights "is it how you actually talk" above technical correctness.

**Decision — Which prototype variant to pursue**

_When it helps:_ you have several prototypes and must pick one to iterate. _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)
- **Situation:** The prototype skill produced three variants: A (face composited in the canvas, movable left/right), B, and C (a split view).
- **Options considered:** A, B, or C.
- **Choice:** Variant A; abandon B and C and iterate on A.
- **Why:** A matched what he'd imagined; B was worse than expected ("too large"); the split view forced manual eyeballing to line things up — bad UX. Trying them made the right call obvious in a way a description never could.

**Decision — How to review and ship the 21k-line PR**

_When it helps:_ you have one enormous PR you want to ship safely, as if to production. _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)
- **Situation:** `implement-spec` produced a single ~21,000-line PR; he wants to "cosplay production" and review it properly rather than merge it wholesale.
- **Options considered:** Merge the one big PR; or break it into stacked smaller PRs — a run of two-way doors ending in one one-way door — gated behind a feature flag.
- **Choice:** Stacked diffs with line-count estimates + a feature flag to ship the change "dark" and flip it on at the end.
- **Why:** Keeps production as close to the change as possible, makes each chunk independently reviewable and revertible, and turns one risky merge into many low-risk ones with a seamless final switch-on.

**Decision — What to do about the proliferation of agent-written comments**

_When it helps:_ agent output is littered with explanatory comments you dislike. _Source:_ [`transcript`](./matt-pocock-dev-process.transcript.txt)
- **Situation:** The new feature is ~18–20% comments vs a ~12% repo average, with thousands of existing instances; he sees comments as a large surface the agent must maintain and a "fig leaf" that lets workarounds survive.
- **Options considered:** Leave them; ban comments outright (the Lauren Tan stance); or a phased approach — trial a no-comments rule in certain folders, convert some comments to ADRs or test names, and delete the rest.
- **Choice:** The phased approach, pushing the agent to be aggressive (it found ~22 deletable and ~18 workarounds to redesign, 3 ADR candidates).
- **Why:** A comment next to a workaround usually marks code that should have been *designed* differently, not explained; but an immediate total ban is too big a change, so ratchet it folder-by-folder and convert genuine "why" into ADRs.

**Do**

| Recommendation | When it helps | Source | Description |
| --- | --- | --- | --- |
| **Grow the glossary and ADRs during grilling** | Working in a mature codebase and unsure where a new feature fits | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Figure out where the feature lives in the existing language; add new terms and record non-obvious decisions as ADRs *while grilling*. It compounds — future runs get richer context and better grilling. |
| **Use scenario testing to pick domain terms** | Stuck choosing between candidate names | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Have the agent tabulate candidates with example sentences and score them, explicitly weighting "does this match how I actually talk / my mental model." |
| **Prototype multiple options for feel-based decisions** | A choice hinges on how something looks or feels to use | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Build variants and try them before scheduling the real build; a disliked variant is informative. This human-in-the-loop prototyping shrinks the agent's later decision space. |
| **Compact the grilling into a spec, then implement AFK** | A big feature you want built over multiple sessions without babysitting | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Turn the aligned conversation into `/to-spec` + `/to-tickets`, compact (safe once it's a document), then `/implement-spec` AFK. The agent just connects glossary + spec + prototype. |
| **Turn review dislikes into ratcheted lint rules / standards** | You keep seeing a pattern you don't want to recur | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Prefer a deterministic rule you tighten over time (e.g. ban a footgun "outside shared utilities") over hand-fixing instances; raise the rest as issues — including issues against your own skills. |
| **Run a retro over many sessions + your review comments** | After a big chunk of work, or periodically, to improve the system | [`transcript`](./matt-pocock-dev-process.transcript.txt) | `/retro` reads the local session transcripts and your PR comments and returns a ranked improvement list (standards, lint rules, skill fixes). Save sessions to the cloud if you have a factory setup. |
| **Delegate a hard isolated problem to a fresh sub-agent** | A sub-agent is deep in its dumb zone (e.g. 260k tokens) on a new sub-problem | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Rather than pile a fresh bug onto a bloated context, kick off a clean sub-agent scoped to just that problem; delegate when you're context-constrained. |

**Don't**

| Recommendation | When it helps | Source | Description |
| --- | --- | --- | --- |
| **Don't remove a "fence" before you know why it's there** | Tempted to delete or reverse mature code/decisions you don't understand | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Chesterton's fence: understand the reason first. Keep ADRs so the reasons are recorded and future runs don't blindly reverse them. |
| **Don't hand the agent lots of decision space at implementation** | AFK runs produce bad or inconsistent choices | [`transcript`](./matt-pocock-dev-process.transcript.txt) | More open decisions = more chances to pick badly. Do the deciding up front (glossary, prototype, spec, tickets) and leave implementation nearly mechanical. |
| **Don't let explanatory comments proliferate** | Agent output is thick with comments | [`transcript`](./matt-pocock-dev-process.transcript.txt) | They're a large surface the agent must keep updating, often session-specific notes-to-self that live forever, and a fig leaf that lets workarounds survive. Design the code so the comment isn't needed, or move real "why" into an ADR or a test name. |
| **Don't let footgun patterns stay — design and lint them out** | You see `as`-casts, magic-string params, raw ignored `fetch`, etc. | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Replace footgun access with safer APIs (typed helpers/clients, a single source of truth) and enforce with a ratcheted lint rule, so the whole class of mistake is removed rather than re-reviewed. |
| **Don't let the agent auto-create ADRs for you** | The agent writes an ADR without being asked | [`transcript`](./matt-pocock-dev-process.transcript.txt) | Deciding to record an ADR is a judgment call Matt wants to make *during* grilling; he still accepts a good one, but the trigger to write it should be the human's, not an eager agent's. |
