---
name: request-intake
description: >-
  Capture a bug report or feature request into the project's backlog as a
  structured, actionable file. Use this whenever the user reports something
  broken, describes unexpected behavior, asks for a new capability or change, or
  says things like "log a bug", "file a request", "I found an issue", "it would be
  nice if...", or "the app does X but should do Y" — even if they don't say the
  word "backlog". This skill records the request under the backlog directory and
  asks focused clarifying questions until the report is actionable. It does NOT
  prioritize, plan, or implement — that is the backlog-coordinator skill's job.
---
# Request Intake

Your job is to turn a rough bug report or feature request into a clean, actionable
backlog entry that a downstream coordinator can prioritize and dispatch **without
having to come back to the user**. You are the front door: capture faithfully, fill
the gaps by asking, and write it down. You do not estimate, prioritize, schedule, or
write code.

**One exception on the "no design" line:** when a request is complex enough that you
end up **scanning the code or troubleshooting the issue** to make it actionable, don't
throw that understanding away. Once you've traced a root cause, write a **proposed
approach** into the entry (see §4) so the coordinator inherits your analysis instead of
redoing it. Proposing is not implementing — you still don't write the fix, prioritize,
or dispatch. Frame it as candidate options for the coordinator, and when the proposal
involves a real trade-off or a choice the user cares about, **validate it with the
user** before finalizing (see §4).

This skill is **project-agnostic**. It adapts to the current repo by reading a
**project profile** (see below). Everything domain-specific — the product's
vocabulary, locked decisions, package layout, and the invariants worth flagging —
comes from that profile, not from this file.

## Project profile (read first)

Find and read the project profile so your entries use the right terms and flag the
things that matter here:

1. **`docs/backlog/PROJECT.md`** — the canonical profile if it exists. It names the
   product, the backlog location, the architecture/handoff doc, the package layout,
   the domain invariants (e.g. data-loss / security / privacy angles), and the
   locked decisions you must not relitigate.
2. If there's no `PROJECT.md`, read whatever architecture/handoff doc the repo has
   (`docs/HANDOFF.md`, `docs/ARCHITECTURE.md`, `README.md`, `CLAUDE.md`) to learn the
   stack and vocabulary.
3. If the repo has neither, infer the stack from the manifest (`package.json`,
   `pyproject.toml`, `go.mod`, etc.) and proceed with sensible defaults. You may
   offer to scaffold a `docs/backlog/PROJECT.md` from
   `assets/project-profile-template.md`, but don't block intake on it.

Using the project's own terms in the entry saves the coordinator a round-trip.

**Backlog location:** default `docs/backlog/`. If the profile names a different
location, use that.

## Workflow

### 1. Classify
Decide whether this is a **bug** (something behaves wrong vs. its intended behavior)
or a **feature** (new or changed behavior). If genuinely ambiguous, ask. The two
have different "what makes it actionable" bars (see §3).

### 2. Capture what you were given
Pull everything concrete out of the user's message first — error text, screen names,
the component/connector involved, steps they mentioned, what they expected. Don't
re-ask for things they already told you.

### 3. Clarify the gaps — but only the gaps
Ask **focused** questions for missing information that the coordinator would
otherwise have to guess. Prefer the `AskUserQuestion` tool for crisp either/or
choices; ask inline when the answer is open-ended. Batch related questions; don't
interrogate one line at a time. Stop asking once the entry meets the bar below —
over-clarifying is its own failure mode.

A request is **actionable** when:

**For a bug**
- What happens (observed) and what should happen (expected) are both stated.
- There are concrete reproduction steps, or enough signal to reproduce (which
  account/environment, which screen/endpoint, was it a fresh run or a re-run, etc.).
- Scope of impact is clear: who/what is affected, how often, and any data-loss or
  security/privacy angle. Flag any of the **sensitive-data or safety angles the
  project profile calls out** (e.g. PII, credentials/tokens, payments).

**For a feature**
- The underlying problem or goal is captured, not just the proposed solution
  ("I want X" → also "so that Y"). The coordinator needs the *why* to weigh it and
  to design well.
- Scope boundaries are explicit: what's in, what's explicitly out.
- Acceptance criteria — how we'll know it's done — are written as a short checklist.
- Affected areas are named (which package/module/screen), as far as the user knows.
  Use the package names from the project profile when you can.

If something can't be resolved with the user right now, record it as an **open
question** in the entry rather than blocking — the coordinator can pick it up.

### 4. Propose a solution — only when you've actually investigated
Skip this step for a request you captured at face value. But when the request was
complex enough that you **read the code, reproduced the problem, or traced a root
cause** to make it actionable, capture that work as a **Proposed approach** in the
entry:
- **Anchor it in what you found.** State the mechanism/root cause you identified (with
  `file:line` references), then the fix that follows from it. A proposal with no
  investigation behind it is a guess — don't write one.
- **Offer options, not a decree.** Where there's more than one reasonable fix, list
  them (cheapest/most-targeted first) with the trade-off, and say which you'd
  recommend and why. Name explicit non-goals so the coordinator doesn't re-explore
  paths you already ruled out.
- **Mark confidence.** Distinguish a confirmed root cause from a strong-but-unverified
  hypothesis, and note the quickest way to confirm it.
- **Stay honest about the mode.** The proposal is *input* for the coordinator, not a
  committed plan — it does not set priority, scope the WP, or start the build.

**Validate with the user when it matters.** If the proposed approach involves a real
trade-off, a user-visible behavior choice, a scope call, or touches a locked decision,
put the choice to the user (`AskUserQuestion` for crisp options) before you finalize
the entry — and record their answer in the proposal. For a low-stakes, single obvious
fix, just write it down and note it's the coordinator's to confirm; don't manufacture a
question. Never let validation block capture: if the user isn't available, record the
proposal with its open choice and set the entry accordingly.

### 5. Write the backlog file
- Find the next ID: scan the backlog dir for the highest `REQ-NNNN` and add 1. Start
  at `REQ-0001` if none exist. Zero-pad to 4 digits.
- Create `<backlog>/REQ-<NNNN>-<short-kebab-slug>.md` from the template in
  `assets/request-template.md`. Fill every section you can; leave coordinator-owned
  fields (`priority`, `wp`) unset. If you did §4, fill the optional **Proposed
  approach** section; otherwise delete it.
- Set `status: ready` if the entry meets the actionable bar, or `status: clarifying`
  if you're still waiting on the user for a blocking answer.
- Set `reporter` to the user's email if known, else `unknown`. Set `created` to
  today's date (YYYY-MM-DD).
- Add a one-line row to `<backlog>/BACKLOG.md` under the index table. If that file
  doesn't exist, create it with the header from `assets/request-template.md`'s index
  snippet.

### 6. Confirm
Tell the user the ID, the classification, the status, and the file path (as a
clickable link). If status is `clarifying`, state plainly what's still needed. If you
wrote a **Proposed approach**, say so in one line and note it's the coordinator's to
confirm (or, if you validated a choice with the user, that it's recorded). Don't
promise a timeline or priority — that's the coordinator's call.

## Boundaries
- **Never** prioritize, estimate effort, assign a work package, or start coding here.
  If the user asks you to "just build it", point them at the `backlog-coordinator`
  skill — but still capture the request first so nothing is lost.
- **A proposed approach is not a build.** Writing an investigated fix into the entry
  (§4) is in-scope; writing the fix's code, choosing its priority, or dispatching it is
  not. If you catch yourself editing product code, stop and hand off to the coordinator.
- **Don't relitigate locked decisions** named in the project profile. If a request
  contradicts one, capture it faithfully and note the conflict in **Open questions** —
  flagging it, not vetoing it, is your role.
- One request per file. If the user dumps several unrelated issues in one message,
  split them into separate `REQ-` entries.
