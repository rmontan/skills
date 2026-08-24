---
name: release-gate
description: >-
  Run the project's registered test catalog (docs/testing/, built by test-intake) —
  every deterministic check first (plain scripts, zero inference cost), then AI-graded
  checks routed to a cheap or strong model per each check's own tier, to keep the
  suite's inference spend deliberate rather than incidental. Any failure is filed as a
  REQ via request-intake into the product backlog; this skill never edits application
  code itself. Use before a production deploy, or when asked to "run the release gate",
  "run the regression suite", "run the test suite", or "check the app before we
  deploy".
---
# Release Gate

You run the project's standing test catalog and report what broke. You do not fix
anything — a failure becomes a REQ in the product backlog (via `request-intake`) for
`backlog-coordinator` to pick up later. Your only output is a pass/fail report and,
for anything that failed, a filed REQ.

## Test profile (read first, every run)

Read **`docs/testing/PROJECT.md`** — the catalog location, the tier → model mapping,
fixture/throwaway-account setup, and the pointer to `docs/backlog/PROJECT.md` for how
this project's `request-intake` expects a filed defect to look. If this file doesn't
exist, say so and stop — point the user at `test-intake` to scaffold it; don't guess
at a catalog that isn't there.

## Workflow

### 1. Load the catalog
Read `docs/testing/CATALOG.md` and every `TEST-*.md` with `status: active`. Group by
tier: `deterministic`, `ai-cheap`, `ai-strong`.

### 2. Run every deterministic check — always, first, all of them
These cost nothing but wall-clock time. Run every one of them regardless of how many
there are or whether the user only asked about a specific area — there's no inference
cost to justify skipping any, and a partial deterministic run tells you less than a
full one for free. Capture pass/fail and the raw output per check.

### 3. Run AI-graded checks — only as scoped, cheap tier before strong tier
If the user asked for a full release-gate run, run both AI tiers. If they scoped the
ask (e.g. "just run the fast checks" or "skip the AI-graded ones"), respect that —
these are the ones with a real per-run cost, so don't run them speculatively.

For each check:
1. Follow its evidence-capture steps (screenshot, payload, log excerpt) exactly as
   written in the TEST entry.
2. Dispatch the grading to a model matched to the check's tier — a cheap/fast model
   for `ai-cheap`, a stronger model for `ai-strong` — with the check's stored rubric
   prompt and the captured evidence. Ask for a PASS/FAIL verdict plus a one-line
   reason; don't let the grader improvise scope beyond the written rubric.
3. Record the verdict and reason. If a verdict looks uncertain or hedged rather than a
   clean PASS/FAIL, say so in the final report rather than silently rounding it to
   one side — a borderline AI grade is a signal for a human look, not a result to bury.

**Minimize spend deliberately:** never promote a check to a stronger model than its
registered tier on your own judgment mid-run — if a cheap-tier grader seems to be
struggling with a specific check, that's a signal the check is mis-tiered (surface it
in the report as a candidate for `test-intake` to re-tier), not a reason to silently
spend more on this run.

### 4. File failures
For every check that failed (deterministic or AI-graded), invoke `request-intake` to
write a REQ into the **product** backlog (`docs/backlog/`, or wherever that project's
profile points) — not into the test catalog. Include: which TEST id found it, the
repro (command + output, or the evidence + rubric + verdict), and impact if apparent.
Do not edit application code to work around it. Record the resulting REQ id back into
the TEST entry's Notes.

### 5. Update the catalog
For every check run (pass or fail), update its `last_run:` field — date, result,
evidence link, REQ id if one was filed. Commit these updates (and any new REQs'
commits, if `request-intake` didn't already commit its own) if this is a git
repository.

### 6. Report
Summarize: deterministic N/N pass, AI-graded pass/fail counts by tier, any borderline
AI verdicts worth a human look, every new REQ id filed (with a one-line description
each), and roughly what this run cost in model calls (count, not exact tokens — the
point is visibility, not precision).

## Boundaries
- **Never edit application code.** Not even a one-line fix for an obviously trivial
  failure — file the REQ and stop, same discipline as `test-intake`.
- **Never skip a deterministic check to save time.** They're free; skipping one saves
  nothing meaningful and reduces coverage of the one thing you're actually there to
  check.
- **Never silently upgrade a check's model tier mid-run.** Re-tiering is `test-intake`'s
  job, informed by your report — not a call to make live.
- **If the catalog has nothing `active`, say so and stop** — don't invent checks to run.
