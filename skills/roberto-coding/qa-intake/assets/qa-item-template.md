<!--
Template for a single Q&A catalog entry. Copy the frontmatter + body below into
<catalog>/QA-<NNNN>-<slug>.md and fill it in.

Status values:
  draft    — written but not yet confirmed against the sources / reviewed
  active   — ready to use verbatim (or near-verbatim) with a customer
  retired  — no longer accurate/relevant (say why in Notes); keep the file for history
-->

---
id: QA-0000
question: <the question, phrased the way a customer would actually ask it>
category: <one of docs/qa/TAXONOMY.md's numbered categories, or a new one added there first>
audience: both              # helpdesk | presales | both
status: draft                # draft | active | retired
created: YYYY-MM-DD
author: <email or unknown>
sources: []                  # doc + section for every factual claim below, e.g. [docs/HANDOFF.md §4]
---

## Answer
<The direct answer, in plain language, 2-4 sentences. No internal jargon — write
it the way you'd actually say it to the person asking.>

## Website copy
<Optional. Only write this when the entry is actually meant to be published
publicly (a website FAQ, a help-center article) — most entries won't need it.
A shorter, standalone, marketing-safe rewrite of the Answer: no internal
numbers/config values, no jargon, safe for a stranger to read with zero
context. Still bound by the accuracy rule — ground it the same way.>

## Say more if
<Optional. A short follow-up script for a live agent, only if there's a likely
next question or a common misunderstanding worth heading off.>

## Notes
<Internal-only context: related QA/REQ ids, why the answer is worded this way,
anything that would help whoever re-verifies this entry later after a locked
decision changes.>


<!-- ============================================================= -->
<!-- <catalog>/CATALOG.md index snippet — create the file with     -->
<!-- this header if it does not exist; append one row per entry.   -->
<!-- ============================================================= -->

# Q&A Catalog

Index of all registered questions. Source of truth is each `QA-*.md` file; this
table is a scannable summary maintained by the `qa-intake` skill.

| ID | Category | Audience | Question | Status |
|----|----------|----------|----------|--------|
| [QA-0000](QA-0000-example.md) | <category> | both | Example question? | draft |
