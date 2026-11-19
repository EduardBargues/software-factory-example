---
name: update-workshop-skill
description: Extract vocabulary, key concepts, the instructor's decisions (situation / options / choice / why), and recommendations from a course lesson — both its written .md and its .txt video transcript — and write them into a named workshop course-help skill (e.g. course-wayfinder), under the lesson's module section.
---

You update a **workshop course-help skill** from a lesson file. These skills live at `workshops/.claude/skills/course-<workshop>/SKILL.md` and hold the distilled notes an agent consults when a user is stuck on a problem.

## Input

The user gives you **the target workshop skill name** — e.g. `course-wayfinder` or `course-domain-language`. This is the skill you will edit: `workshops/.claude/skills/<name>/SKILL.md`.

Its **corresponding workshop folder** is the top-level `NN-<suffix>` folder whose name matches the skill name minus the `course-` prefix (e.g. `course-wayfinder` → `02-wayfinder`, `course-domain-language` → `01-domain-language`). You process **every** lesson in that folder in one run.

Each lesson is a `NNN-slug.md` file (the written lesson). Many lessons also have a **sibling video transcript** at `NNN-slug.txt` — the instructor's verbatim narration, usually richer and more concrete than the written `.md`. Treat the `.md` + `.txt` pair as **one lesson**.

If the user names a workshop folder (or a single lesson file) instead of the skill, map it to the corresponding `course-<suffix>` skill. If that skill doesn't exist yet, create it from the template at the bottom of this document, then proceed.

## Purpose

A workshop skill is a **routing map** for problem-driven lookup, not an exhaustive knowledge base. Its consumer is an agent: when the user is stuck on a problem, the agent loads the matching workshop skill(s) via their frontmatter `description`, scans the **When it helps** entries to find a match, then follows the **Source** links to read the full lesson file (the primary source of truth) for depth.

Two consequences shape every entry you write:
- Keep entries **concise** — the depth lives in the linked lesson file, not here. Make the source link load-bearing.
- Key Concepts and Instructor Recommendations each carry a **"When it helps"** column: the real-world situation or symptom that should make the user (or agent) reach for this entry, phrased as the problem the user would describe ("Your team keeps renaming the same thing", "An agent invented terms you don't recognise"). This is what makes problem-driven matching work.

Do not remove or alter the skill's YAML frontmatter or its "how to use" preamble, except to **extend the `description`** as described under "Keep the frontmatter description current".

## Processing the folder

List every lesson in the corresponding workshop folder — each is a `NNN-slug.md`, optionally paired with a `NNN-slug.txt` transcript — and process them in filename order (by numeric prefix). The skill is its own record of what's done — there is no separate tracking file. A lesson is already captured if a `## <Module title>` section for it (the lesson's top-level `#` title) exists in the target skill.

**Check the `.md`/`.txt` pairing before you process, and fix any filename typo you find.** Pairing is by identical basename, so a one-character filename typo (e.g. `...neraly-impossible.md` next to `...nearly-impossible.txt`) silently orphans the transcript: the `.md` looks transcript-less and the `.txt` looks like a `.txt`-only lesson, and you lose the transcript's richer material with no error. So before processing, list the `.md` and `.txt` basenames and flag any `.txt` with no exact `.md` match (and vice versa). When an orphan is an obvious near-miss of a sibling (same numeric prefix, off by a typo), treat them as the intended pair, **rename the mistyped file yourself (e.g. with `git mv`) so the basenames match, then tell the user what you renamed**, and process them together rather than as two separate lessons. Don't merely flag it for the user — close the gap so the next run doesn't re-orphan it.

**Which name is authoritative — content first, then the `.txt`.** Decide the correct basename by **reading both files**, not by trusting either name blindly (the same instinct as the "look at the target before you overwrite it" rule): rename whichever file's name **contradicts its own content** (its `#` title / `problem` vs `solution` role / topic), leaving the file whose name already matches its content untouched. So if a `.txt` holds the *solution* walkthrough but is named `...-problem.txt`, rename the **`.txt`** to `...-solution.txt` — don't rename the correctly-named `.md`. Only when the two names differ by a **pure spelling typo** (same lesson role, same topic, e.g. `neraly` vs `nearly`) does content not disambiguate; there, treat the **`.txt` filename as the source of truth** and rename the `.md` to match it. Never rename a file so that two lessons collide on the same basename or a lesson's name stops matching its content.

Read the target skill first, then for each lesson (both its `NNN-slug.md` **and**, if present, its sibling `NNN-slug.txt` transcript):
1. **Already captured** (its module section exists) → skip it, unless the user explicitly asked to re-process, in which case enrich existing rows (never duplicate) and add any genuinely new entries.
2. **Not captured** → **read the `.md` and the `.txt` transcript together** and extract entries (below) from the union, then add the module section in the correct lesson-file position.

The transcript is the instructor's actual words — worked examples, emphasis, and asides the written `.md` only summarises — so treat it as a **primary source**, not an afterthought; much of a lesson's best material (named skills, decision trees, the "why" behind a rule) lives **only** in the transcript. Whenever a `.txt` exists, you must read it in full; skipping it is a defect. Take the **module title** from the `.md`'s top-level `#` heading, and **source-link entries to the `.md`** (its `.txt` transcript is a sibling with the same basename, there for anyone who wants the verbatim). (A lesson that has only a `.txt` and no `.md` uses the transcript as its source, with the module title taken from the transcript's filename, title-cased.)

A pure exercise/problem file that yields no entries gets **no section** — that is expected, and it's simply re-examined (a harmless no-op) on future runs.

Up front, tell the user the lay of the land — e.g. "7 of 9 modules already present; processing 2 new lessons: …". If every lesson is already captured and nothing new is found, say the skill is already up to date and make no changes.

## What to extract

For each candidate item in the lesson — drawn from **both the written `.md` and the `.txt` transcript** — apply the **inclusion bar**, then the **categorization procedure**, then the **granularity rule** below.

### Inclusion bar — four tests

Extract an item only if it passes **all four**:

1. **Transferable** — it applies beyond the lesson's example. Ask: *"Would this be useful in a different project, with a different domain?"* (Domain entities from the example app — e.g. "Refund Request" in a payments app — fail this test and are never extracted.)
2. **Durable** — it isn't tied to a specific tool version or a passing detail that will age out.
3. **Non-obvious** — a competent mid-level engineer wouldn't already treat it as default. Skip truisms like "write clear code" or "test your work."
4. **Load-bearing** — it's a point the instructor actually makes (often spelled out only in the spoken transcript), not an incidental aside.

If any test fails, skip the item.

### Always capture: course skills (override)

The inclusion bar has one standing exception. **Any skill the instructor teaches or uses — a named, invocable skill such as `/grill-with-docs`, `/grilling`, `/domain-modeling`, `/wayfinder`, `/to-spec`, `/prototype`, `/research` or `/wizard` — is always in scope,** even if it reads as tool-specific and would otherwise fail the Transferable or Durable test. The skills *are* what the course teaches; losing their names and definitions would gut these notes. Skill knowledge is the highest-priority thing to capture — when in doubt, include it.

For every such skill:
- Add a **Vocabulary** entry whose title is the skill's invocation including the leading slash (e.g. **`/grill-with-docs`**). Define what it does, what it layers on or calls, what artifacts it produces, and when to reach for it.
- If the lesson also gives guidance on *how* or *when* to use the skill, cross-list that as a **Key Concept** (the mechanism / why) or an **Instructor Recommendation** (the instruction), as usual.
- Never skip a skill or leave it as a passing mention — if a lesson names it, it gets its own Vocabulary row. When a later lesson adds detail about a skill already captured, enrich its existing row rather than dropping the detail.
- Before finishing a lesson, re-scan **both its `.md` and its `.txt` transcript** for every `/`-prefixed skill name and confirm each one has a row — instructors often name a skill only in the spoken transcript. A skill the instructor **teaches or actually uses** but doesn't capture is a defect, not an acceptable omission.
- **Exception — a bare mention is not a use.** A skill named only to say it is *not* needed here ("no grilling needed for this one"), or merely name-dropped in passing as belonging to another workshop without being taught or invoked in this lesson, does **not** require a row. Capturing it would add an empty, triggerless entry. Only skills that are taught, invoked, or given real guidance in the lesson get a Vocabulary row.

### Always capture: decision trees (override)

Instructors often present **decision trees** — a branching "if X do A, otherwise if Y do B, escalate to C" procedure for choosing between approaches (e.g. one-shot vs `/grill-with-docs` vs Wayfinder). These are among the highest-value things in the course and are **always extracted**, even if individual branches would otherwise read like ordinary recommendations.

Preserve the tree **as a structured block, not flattened into scattered rows** — the branching and its order *are* the content. Render it under the lesson's module section using the Decision-tree block in the Format section below, keeping the steps in the instructor's order and wording. You may still add a Vocabulary term for a label the tree introduces and a Key Concept for the "why" behind it, but the tree itself must appear as its own block. If a lesson is built around a decision tree, that block is the single most important thing to get right — scan every lesson, **including its `.txt` transcript, where the instructor often walks the tree aloud step by step**, before deciding it has none.

### Always capture: instructor decisions — the chain of thought (override)

Beyond branching decision *trees*, instructors constantly make **concrete decisions** in the moment — they hit a fork, weigh a few options aloud, pick one, and explain why. This reasoning is among the most valuable things in the course: it's how an experienced practitioner actually thinks, and it transfers directly to the user's own day-to-day problems. **Always extract these**, even when the specific choice would otherwise read as too tied to the example.

Capture each as a **Decision Log** entry, preserving the full chain of thought — **Situation → Options considered → Choice → Why** — as a structured block (see the Format section), not flattened into a single Do/Don't. The **alternatives the instructor rejected and their reasoning are the insight**; a bare "they did X" throws away everything useful. Give each a **"When it helps"** trigger: the kind of fork in the user's own work where seeing how the instructor reasoned would help.

The *why* usually lives in the spoken `.txt` transcript, where the instructor thinks out loud ("I could do A, but B is better because…") even when the written `.md` only states the final choice — so scan the transcript specifically for decisions and their rationale. Keep it general where you can: record the transferable reasoning, using the lesson's specifics only as the concrete illustration.

### Categorization — which section(s)

Decide the bucket by what the item *is*, applied in order:

- Names a **thing** you'd use in a sentence (a technique, artifact, or labelled concept)? → **Vocabulary**.
- A **claim about how things work** — cause/effect, a mental model, a "why" — with no action implied? → **Key Concept**.
- An **instruction to act or avoid** something? → **Instructor Recommendation** (Do or Don't).

An item may fit **more than one** section — that's fine, cross-list it (e.g. a named technique can be both a Vocabulary term and a Key Concept). When cross-listed, write each appearance **for its own section** rather than copy-pasting: the Vocabulary row **defines** the term, the Key Concept row **explains the mechanism / why**, the Recommendation row **gives the instruction** (with its "When it helps").

### Granularity

One entry per **atomic** idea. Split compound advice ("do X and Y") into separate entries when X and Y are independently useful; merge near-duplicates that say the same thing.

### The "When it helps" trigger

For every **Key Concept**, **Decision Log** entry, and **Instructor Recommendation**, extract a **"When it helps"** trigger: the concrete situation or symptom, in the user's words, that should make them reach for this entry. Vocabulary entries are definitional and do **not** get a trigger.

## Examples in entries

Lesson examples are allowed **only as inline illustrations** of a general concept — not as the subject of an entry. Write the general principle first, then optionally add a one-sentence example to make it concrete.

Good: `A technique where you generate edge-case sentences to stress-test a naming model before committing. E.g., testing "one purchase, two X, neither of which X'd anything" quickly reveals whether a term is ambiguous.`

Bad (a domain entity from the example app, not transferable vocabulary): `The event where a learner asks for their money back, with statuses Open, Approved, Declined.`

## Format

All of a lesson's entries live under a single **`## <Module title>`** section inside the workshop skill. The module title is the lesson's top-level `#` heading (e.g. `## Pruning the Glossary Solution`) — use the full distinct title so problem and solution files don't collide. Keep module sections in **lesson-file order** (by filename's numeric prefix); insert a new section at the correct position, not just at the end.

Within a module section, include only the groups that have entries, each introduced by a bold label and followed by a Markdown table, in this order: **Vocabulary**, **Key Concepts**, any **Decision-tree** block(s) (see below), any **Decision Log** block(s) (see below), **Do**, **Don't**.

**Vocabulary** is a three-column table (no trigger — it's definitional):

```
**Vocabulary**

| Term | Source | Description |
| --- | --- | --- |
| **Title** | [`module-tag`](path) | Definition. |
```

**Key Concepts** is a four-column table with a **When it helps** column second:

```
**Key Concepts**

| Concept | When it helps | Source | Description |
| --- | --- | --- | --- |
| **Title** | The situation/symptom, in the user's words | [`module-tag`](path) | One to three sentences. |
```

**Instructor Recommendations** split into **Do** (a practice to adopt) and **Don't** (a practice to avoid), each a four-column table shaped like Key Concepts (name column header `Recommendation`). Phrase a Don't's title in the negative ("Don't …", "Never …").

```
**Do**

| Recommendation | When it helps | Source | Description |
| --- | --- | --- | --- |

**Don't**

| Recommendation | When it helps | Source | Description |
| --- | --- | --- | --- |
```

A **Decision-tree block** (used whenever a lesson presents a branching choice procedure — see "Always capture: decision trees") is not a table. Render it as a bold label, a trigger + source line, then the branches as an ordered list:

```
**Decision tree — <short name of the decision>**

_When it helps:_ <the situation that sends the user to this tree>. _Source:_ [`<module-tag>`](path)

1. **<first question/condition>?** → <action to take, naming any skill involved>.
2. **Otherwise, <next condition>** → <action>.
3. **If <escalation condition>** → <action>.
```

A **Decision Log block** (used whenever the instructor makes a concrete decision and reasons through it — see "Always capture: instructor decisions") is not a table either. One block per decision: a bold label, a trigger + source line, then the chain of thought as a short labelled list:

```
**Decision — <short name of the decision>**

_When it helps:_ <the kind of fork in the user's own work this maps to>. _Source:_ [`<module-tag>`](path)

- **Situation:** <the fork the instructor faced>.
- **Options considered:** <the alternatives they weighed>.
- **Choice:** <what they picked>.
- **Why:** <their reasoning>.
```

Cell rules for every table:
- **Name cell**: the term, concept, or recommendation title, in bold.
- **When it helps cell** (Key Concepts and Recommendations only): the provoking situation or symptom, phrased as the problem the user would describe. May hold several situations joined by ` · `.
- **Source cell**: one or more Markdown links joined by ` · `, all to lessons **in this skill's own workshop**. The link target is a relative path from the skill file to the raw lesson: `../../../<workshop-folder>/<lesson-file>` (the skill sits three levels deep under `.claude/skills/<name>/`). The link text is a backticked tag of the lesson filename without its extension. Example: ``[`060-q-and-a`](../../../01-domain-language/060-q-and-a.md)``.
- **Description cell**: the explanation, kept concise since the linked lesson holds the depth.

Keep every cell free of unescaped `|` characters, since they break table cells.

### Enriching an existing row

When the idea you're extracting already has a row in the target section — often because a later lesson revisits it — grow that row instead of adding a duplicate:

- **Source cell**: append the new lesson's link so the cell lists *every* file where the idea appears, joined by ` · `.
- **When it helps cell**: append any genuinely new situation the later lesson surfaces, joined by ` · `. Skip it if the trigger is the same.
- **Description cell**: fold the later lesson's distinct facet into one coherent, **merged** description — not labelled sub-blocks. Provenance stays in the Source links.

An enriched row stays under the module where the idea was **first introduced**; you add the new source link there rather than moving it.

Only enrich when the later lesson adds something; if it merely repeats what's already captured, leave the row unchanged.

### Repetition across workshops is fine

Keep each workshop skill **self-contained**. An idea taught in more than one workshop gets its **own independent entry in each** workshop's skill, written from that workshop's angle and sourced **only to that workshop's lessons**. The same term, concept or recommendation may therefore appear — with a slightly different definition — in several skills, and that's expected and good, since its meaning shifts a little per workshop.

You do **not** need to open or cross-check other workshop skills while processing one: don't hunt for duplicates across workshops, don't add cross-workshop source links, and don't edit another workshop's skill. Only de-duplicate and enrich **within** the skill you're currently updating.

### Keep the frontmatter description current

The workshop skill's frontmatter `description` is the only thing the agent sees before loading it, so it carries all the routing weight. When a new module introduces problem areas or skills not yet reflected in the `description`, extend it with those triggers (a compact symptom list). Don't let the description go stale as the workshop grows.

## Rules

- Do not add entries for things that are out of scope, explicitly parked, or marked as "you're not going to need it" in the lesson.
- Do not summarise code diffs — extract the principle they illustrate, not the diff itself.
- Keep entries self-contained: a reader who hasn't taken the lesson should understand the entry.
- After writing, give a per-run summary: which workshop skill you updated, which lesson modules you added (and which were skipped as already-present), and how many entries were added per section.

## New-workshop skill template

When a workshop has no skill yet, create `workshops/.claude/skills/course-<workshop>/SKILL.md` with this shape, then add the lesson's module section:

```
---
name: course-<workshop>
description: Distilled notes from the "<Workshop Name>" workshop of the AI Software Factories course. Load when the user's problem involves <compact symptom list and skill names for this workshop>. May be loaded alongside other course-* skills when a problem spans workshops.
---

# <Workshop Name> — Course Notes

Distilled notes from the **<Workshop Name>** workshop. Use this when the user is stuck on a problem about <areas>: scan the **When it helps** entries to find a match, then follow the **Source** link to the raw lesson file for full depth. You may be loaded alongside other `course-*` skills when a problem spans workshops.

Entries are grouped by lesson (module). Each lesson lists its **Vocabulary**, **Key Concepts**, any **Decision Log** (the instructor's situation / options / choice / why), and **Instructor Recommendations (Do / Don't)** — only the groups that have entries are shown.
```
