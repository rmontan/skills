<!--
Template for a single test-catalog entry. Copy the frontmatter + body below into
<catalog>/TEST-<NNNN>-<slug>.md and fill it in.

Status values:
  active   — test-run should run this
  draft    — being built, not yet confirmed to run cleanly
  retired  — no longer relevant (say why in Notes); keep the file for history
-->

---
id: TEST-0000
title: <one-line imperative summary of what this verifies>
tier: deterministic        # deterministic | ai-cheap | ai-strong
status: draft              # draft | active | retired
created: YYYY-MM-DD
author: <email or unknown>
areas: []                  # package/module/screen names, same vocabulary as the backlog
---

## What this verifies
<The behavior/invariant this check pins down. 1-3 sentences.>

## Why
<What this guards against — a domain invariant, a past incident, or "this is the part
that would embarrass us in production if it silently broke".>

## How to run
<!-- deterministic: the exact command -->
```
<command>
```

<!-- ai-cheap / ai-strong: delete the command block above and fill this instead -->
**Evidence capture:**
<Exact steps to gather what the grader sees — screenshot, payload, log excerpt.>

**Grading rubric (verbatim prompt to the grading model):**
```
<A short, explicit PASS/FAIL rubric. If this needs more than a paragraph to state,
the check is probably ai-strong, or should be split.>
```

## Fixtures / test data used
<Which throwaway accounts/datasets, per the test profile, and any reset step needed
before running this check.>

## Last run
- **Date:**
- **Result:** <pass | fail>
- **Evidence:** <link/path, or the raw output for a deterministic check>
- **REQ filed:** <REQ id if this run found a real defect, else "—">

## Notes
<Related TEST ids, REQ ids ([[REQ-0003]]), re-tiering history, anything else.>


<!-- ============================================================= -->
<!-- <catalog>/CATALOG.md index snippet — create the file with     -->
<!-- this header if it does not exist; append one row per check.   -->
<!-- ============================================================= -->

# Test Catalog

Index of all registered checks. Source of truth is each `TEST-*.md` file; this table
is a scannable summary maintained by the `test-intake` and `test-run` skills.

| ID | Tier | Title | Status | Last run | Result |
|----|------|-------|--------|----------|--------|
| [TEST-0000](TEST-0000-example.md) | deterministic | Example | draft | — | — |
