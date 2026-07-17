<!--
Template for a single backlog request. Copy the frontmatter + body below into
<backlog>/REQ-<NNNN>-<slug>.md and fill it in. Delete the bug-only or
feature-only sections that don't apply. Leave `priority` and `wp` for the
backlog-coordinator to set.

Status values:
  ready       — actionable; coordinator may pick it up
  clarifying  — waiting on the reporter for a blocking answer
  in-progress — coordinator has dispatched a work package (coordinator-set)
  in-review   — PR open / in CI (coordinator-set)
  done        — merged (coordinator-set)
  wontfix     — declined, with reason in Notes
-->

---
id: REQ-0000
title: <one-line imperative summary>
type: bug            # bug | feature
status: ready        # ready | clarifying | in-progress | in-review | done | wontfix
priority:            # set by backlog-coordinator: p0 | p1 | p2 | p3
created: YYYY-MM-DD
reporter: <email or unknown>
wp:                  # set by backlog-coordinator, e.g. wp-req0007
areas: []            # package/module names from the project profile
---

## Summary
<2-4 sentences. What is being asked / what is wrong, in plain terms.>

<!-- ===== BUG sections (delete if feature) ===== -->
## Steps to reproduce
1.
2.
3.

## Expected vs. actual
- **Expected:**
- **Actual:**

## Impact
<Who/what is affected, frequency, and any data-loss / security / privacy angle.
Call out explicitly any sensitive-data or safety concerns the project profile
flags (e.g. PII, credentials/tokens, payments).>

<!-- ===== FEATURE sections (delete if bug) ===== -->
## Problem / goal
<The underlying need. "As a <user> I want <X> so that <Y>." Capture the why,
not just the proposed solution.>

## Proposed behavior
<What the user is asking for. Note if this is one idea among options.>

## Out of scope
<What this request explicitly does NOT include.>

<!-- ===== Common sections ===== -->

<!-- Proposed approach — OPTIONAL. Include ONLY when intake actually investigated
     (read code / reproduced / traced a root cause). Delete this whole section for a
     request captured at face value. It is INPUT for the coordinator, not a committed
     plan: it does not set priority or scope the work package. See SKILL.md §4. -->
## Proposed approach
<Root cause / mechanism you found, with `file:line` refs. Then the fix that follows.
Offer options (cheapest/most-targeted first) with trade-offs and a recommendation;
name explicit non-goals. Mark confidence (confirmed vs. hypothesis) and the quickest
way to confirm. If you validated a choice with the user, record their decision here.>

## Acceptance criteria
- [ ]
- [ ]

## Open questions
<Anything unresolved with the reporter. The coordinator should resolve or decide
these before dispatch. Note any conflict with a locked decision (see the project
profile) here.>

## Notes
<Links, screenshots, related REQ ids ([[REQ-0003]]), error logs, context.>


<!-- ============================================================= -->
<!-- <backlog>/BACKLOG.md index snippet — create the file with     -->
<!-- this header if it does not exist; append one row per request. -->
<!-- ============================================================= -->

# Backlog

Index of all requests. Source of truth is each `REQ-*.md` file; this table is a
scannable summary maintained by the `request-intake` and `backlog-coordinator`
skills.

| ID | Type | Title | Status | Priority | WP |
|----|------|-------|--------|----------|----|
| [REQ-0000](REQ-0000-example.md) | bug | Example | ready | — | — |
