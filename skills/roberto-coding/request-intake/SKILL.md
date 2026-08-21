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
  prioritize, plan, or implement — that is the backlog-coordinator skill's job. Also
  use this whenever the user wants to "process the queue", "drain the inbox", or work
  through items saved earlier by the request-queue skill.
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

**Inbox location:** `<backlog>/inbox/`. Items dropped there by the `request-queue`
skill are pending reports waiting to be turned into `REQ-*.md` entries — see §0.

## Workflow

### 0. Check the queue first
Before treating the conversation as the source of a new report, check whether you
were invoked to drain the queue — the user says "process the queue," "drain the
inbox," "work through what's queued," or similar — or whether `<backlog>/inbox/`
simply has files in it and the user hasn't pasted a fresh report of their own.

If there's queue work to do:
1. List `<backlog>/inbox/*.md`, oldest first (the filename timestamp sorts naturally).
2. Take the oldest (or the one the user names) and read it. Its body — the verbatim
   text under the frontmatter — is the report; treat it exactly as you'd treat a
   report the user just typed, and feed it into **step 2 (Capture what you were
   given)** below. Its `attachments:` frontmatter lists any screenshots saved
   alongside it in the same inbox directory; treat those as if the user had just
   attached them.
3. Run the rest of the workflow (§1–§6) normally against that content — classify,
   clarify with the user, propose if warranted, write the `REQ-*.md` file.
4. Once the `REQ-*.md` file is written, delete the queue `.md` file. If it had
   attachments, move them alongside the new REQ (e.g. reference them from the
   entry's **Notes** section with a relative path) rather than leaving orphans in
   `inbox/`.
5. If several items are queued, process one at a time and confirm each (§6) before
   moving to the next — don't silently batch through all of them unless the user
   explicitly asked you to process the whole queue in one pass.

If the inbox is empty and there's no fresh report either, say so and stop — nothing
to do. If there's both a fresh report in the conversation and a non-empty queue,
default to the fresh report (it's what the user is actively talking about) and
mention the queue has pending items, rather than silently ignoring either.

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

**Reserve the ID under a lock — don't just scan-then-write.** Two `request-intake`
sessions can run at the same time against the same backlog (different terminals,
different agents) — and so can a `backlog-coordinator` session, reading and
committing to the very same `BACKLOG.md` while you're mid-conversation with the
user. A bare "scan for highest, add 1" has a race: both sessions can scan before
either writes, see the same highest number, and collide on the same `REQ-NNNN`.
Use an atomic `mkdir` lock to close that window — and use the **same** critical
section to make the REQ file and its `BACKLOG.md` row appear together, atomically,
so nothing outside this skill ever observes one without the other:

1. Draft the full entry content first (frontmatter + body) so the only thing left to
   do under the lock is pick the number, write the file, update the index, and
   commit — keep the critical section short, but do not split it across a
   conversation turn.
2. Acquire the lock: retry-loop `mkdir <backlog>/.req-lock` (mkdir is atomic — it
   fails if the directory already exists, so exactly one concurrent session wins).
   - On failure, check the lock's age (`stat -c %Y <backlog>/.req-lock`, or `%m` on
     BSD/macOS `stat`). If it's older than 120 seconds, treat it as abandoned by a
     crashed/killed session, `rmdir` it, and retry the `mkdir` immediately.
   - Otherwise back off briefly (e.g. 1–2s) and retry. Don't spin tight.
3. **While holding the lock, do all four of the following before releasing it:**
   a. Scan the backlog dir for the highest `REQ-NNNN`, add 1 (start at `REQ-0001`
      if none exist, zero-pad to 4 digits), and write
      `<backlog>/REQ-<NNNN>-<short-kebab-slug>.md` with the full drafted content.
   b. Re-read `<backlog>/BACKLOG.md` fresh (don't reuse a copy read before you
      acquired the lock — another session may have committed to it in the
      meantime) and append the one-line index row under the table. If the file
      doesn't exist, create it with the header from
      `assets/request-template.md`'s index snippet.
   c. **If this is a git repository** (`git rev-parse --is-inside-work-tree`
      succeeds): commit the new REQ file and the `BACKLOG.md` change **together,
      in one commit, right now** — `git add <backlog>/REQ-<NNNN>-*.md
      <backlog>/BACKLOG.md && git commit -m "backlog: file REQ-<NNNN> — <short
      title>"` (match the project's own commit-message convention if
      `docs/backlog/PROJECT.md` or `CLAUDE.md` documents one). **Stage only those
      two paths — never `-A` or a bare `git add .`** A coordinator session may
      have unrelated uncommitted edits elsewhere in the tree (or even mid-edit in
      `BACKLOG.md` itself); an intake commit must never sweep those up. If
      `git diff --cached <backlog>/BACKLOG.md` shows anything beyond the one row
      you just appended, someone else's uncommitted edit is sitting in that file
      — reset just that path (`git restore --staged --worktree
      <backlog>/BACKLOG.md`), re-read it fresh, reapply only your row, and retry.
      If the commit itself fails (hook rejection, nothing staged, etc.), don't
      retry in a loop — surface the failure in your confirmation to the user
      instead of leaving the files staged-but-uncommitted indefinitely.
      If this is not a git repository, skip (c) silently and continue.
   d. Release the lock: `rmdir <backlog>/.req-lock`.

   Do this even if a step failed partway (wrap in a way that guarantees the lock
   is released) — a stuck lock blocks every session until the 120s staleness
   window passes.

**Why this matters beyond ID collisions:** the REQ file and its `BACKLOG.md` row
are one logical unit — `check-backlog`-style gates (and a coordinator reading the
index) treat a row with no file, or a file with no row, as broken state. Committing
them together, inside the same lock used for the ID reservation, means no other
process — another intake session or a coordinator mid-bookkeeping-commit — can ever
observe or accidentally commit half of this update. This replaces an earlier
version of this skill that left the file and row uncommitted for the rest of the
conversation (clarifying questions, proposed approach, confirmation); a coordinator
session committing its own `BACKLOG.md` changes in that window once picked up an
in-progress row with no backing file and shipped a broken `main`. **When draining a
queue** (§0), this means commit after *each* item, not batched at the end of the
run — a crash mid-queue must never leave more than one item's worth of uncommitted
backlog state.

- Fill every section you can in the template from `assets/request-template.md`; leave
  coordinator-owned fields (`priority`, `wp`) unset. If you did §4, fill the optional
  **Proposed approach** section; otherwise delete it.
- Set `status: ready` if the entry meets the actionable bar, or `status: clarifying`
  if you're still waiting on the user for a blocking answer.
- Set `reporter` to the user's email if known, else `unknown`. Set `created` to
  today's date (YYYY-MM-DD). When draining a queue item, carry over its `reporter:`
  and use its `queued:` date for `created` instead — that's when the report actually
  came in, not when you happened to process it.

### 6. Confirm
Tell the user the ID, the classification, the status, and the file path (as a
clickable link). If status is `clarifying`, state plainly what's still needed. If you
wrote a **Proposed approach**, say so in one line and note it's the coordinator's to
confirm (or, if you validated a choice with the user, that it's recorded). In a git
repo, mention that it's committed (not just written) — that's what makes it safe for
a coordinator to act on immediately. Don't promise a timeline or priority — that's
the coordinator's call.

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
- **Don't leave the inbox in a half-drained state.** A queue item is either still
  sitting in `<backlog>/inbox/` untouched, or it's been turned into a `REQ-*.md` file
  and removed from the inbox — never both a leftover queue file and a written REQ for
  the same report.
