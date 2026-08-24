---
name: test-intake
description: >-
  Turn a testing gap or coverage request into a registered, repeatable check in the
  project's test catalog (separate from the product backlog) — deciding whether it can
  be a deterministic script (zero inference cost) or needs AI grading (and at which
  model tier), then building and verifying the actual runnable artifact. Use this when
  the user wants to "add a test for X", "write a regression test", "add this to the
  release suite", asks for "test coverage" of some flow, or says a part of the app is
  "not tested" / "still needs an automated test". Use request-intake instead when the
  ask is about a product bug or feature; use this skill when the ask is about a check
  that should keep being re-run to guard behavior. This is the authoring half of a pair
  with test-run, which runs the catalog and files bug REQs for what it finds broken.
---
# Test Intake

You are the front door for the project's **test suite** — a separate, repeatable
catalog of checks (`docs/testing/`) from the product backlog (`docs/backlog/`). Your
job: take a coverage gap, decide how cheaply it can be verified, build the actual
check, confirm it runs, and register it so `test-run` can find and run it later.

**Why this is a separate catalog from the backlog:** a REQ describes a one-time change
to ship. A TEST entry describes a standing check to keep re-running. Conflating them
means the backlog fills with entries that are never "done" in the normal sense, and a
coordinator prioritizing feature work has no reason to weigh "does this check still
pass" against "should we build X". Keep them apart. The one place they touch: **a
failing check becomes a REQ** (via `request-intake`, into the *product* backlog) — this
skill and `test-run` never patch application code to make a check pass.

## Test profile (read first)

Read **`docs/testing/PROJECT.md`** if it exists — it names the catalog location, the
tier → model mapping, the test fixtures/throwaway accounts, evidence-capture
conventions for AI-graded checks, and points back at the product's own
`docs/backlog/PROJECT.md` for build/verify commands and where failures get filed.

If it doesn't exist, offer to scaffold one from `assets/test-profile-template.md`, then
proceed conservatively: assume deterministic-only until told otherwise, and ask where
test fixtures/throwaway accounts live before writing anything that touches real data.

## Workflow

### 1. Understand the gap
What's not covered, and why it matters — tie it to a domain invariant, a past incident,
or "this is the thing that would embarrass us in production if it broke silently".
Don't ask for this if the user already said it; a bare "we should test X" is enough to
start investigating.

### 2. Choose the tier — bias toward deterministic

Ask, in this order, and stop at the first "yes":

1. **Can pass/fail be expressed as a code assertion against stable state?** (an exit
   code, a DB row count, a value read back from a real API call, an idempotency
   re-run producing the same identities) → **`deterministic`**. No model runs at
   check time — it's a script, and it costs nothing to re-run as often as you like.
2. **Is the check subjective but rubric-able** — layout looks right, copy reads
   sensibly, a screenshot matches an expected state — where a short, explicit rubric
   would let most reasonable graders agree? → **`ai-cheap`**. A fast/cheap model grades
   it against the rubric you write.
3. **Is grading genuinely judgment-heavy or high-stakes** — interpreting an ambiguous
   real-provider response, telling a subtle real regression apart from benign drift,
   anything where a wrong verdict is costly and a cheap model would plausibly get it
   wrong? → **`ai-strong`**. Reserve this tier; it's the expensive one.

Default to option 1 even when it takes more up-front work to express the assertion in
code — a deterministic check is free to run forever, an AI-graded one is not. Only
step up a tier when a stable assertion genuinely isn't expressible.

### 3. Build the artifact
- **`deterministic`** — write the actual script/test (a Go test in the project's
  existing harness, a shell script, whatever fits the stack). Run it now against
  current app state. If it fails immediately, that's a real finding — go to step 5.
- **`ai-cheap` / `ai-strong`** — write: the evidence-capture steps (how to get the
  screenshot / payload / log excerpt the grader will see — use the project's `run`
  skill or existing scripts, don't invent a new capture path if one exists), and the
  grading rubric as an explicit prompt with a clear PASS/FAIL contract. A rubric that
  can't be answered in one paragraph is a sign the check should be split or moved to
  `ai-strong`.

Use the project's own test fixtures / throwaway accounts (per the test profile) —
never a real user's data. If the profile says the fixture data is disposable, feel
free to reset it as needed to get a clean run.

### 4. Register the catalog entry
Same collision-safety concern as `request-intake`'s backlog: use an atomic `mkdir`
lock on `docs/testing/.test-lock` around scanning the highest `TEST-NNNN`, writing
`docs/testing/TEST-<NNNN>-<slug>.md` from `assets/test-case-template.md`, and
appending the row to `docs/testing/CATALOG.md` — then commit the entry, its artifact,
and the catalog row together in one commit if this is a git repository. Follow
`request-intake`'s SKILL.md §5 mechanics if you need the exact lock/retry recipe; the
principle is identical, just a different directory and ID prefix.

Set `status: active` once the check has run at least once successfully as a *check*
(even if the run itself found a failure — the check working is what matters here, not
the app passing it).

### 5. If it already fails
A brand-new check that fails against current app state is a real discovered defect,
not a broken test. Hand off to `request-intake` to file it as a REQ in the product
backlog, with the check's output as repro evidence. Record the REQ id in the TEST
entry's Notes. Do not edit application code yourself to make it pass.

### 6. Confirm
Tell the user: the TEST id, its tier (and why), the file paths for the artifact and
catalog entry, and whether it passed or found something (with the REQ id if so). If
git, confirm it's committed.

## Boundaries
- **Never edit product application code.** If the app is wrong, that's a REQ via
  `request-intake` — this skill only builds and registers checks.
- **Don't invent AI grading for something a script can assert.** The cost discipline
  is the point; a lazily-AI-graded check that could have been deterministic is a
  standing inference bill for no reason.
- **Don't duplicate an existing check.** Scan `docs/testing/CATALOG.md` for something
  that already covers the gap before writing a new one; extend it instead if it's a
  close match.
- One check per file, same as one request per REQ.
