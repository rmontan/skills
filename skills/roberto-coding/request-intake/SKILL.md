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

### 0b. Structured-brief mode (skip clarification when the input is already actionable)
Some reports arrive already meeting the actionable bar in §3 — a finding from a code
review with `file:line` locations, a stated root cause, impact and fix direction; a
queue item that carries reproduction steps; a brief handed down by a coordinator that
is filing on the owner's behalf. Treat those as **structured briefs** and run a
shortened path:

- **Skip §3.** Do not re-ask for what the brief already states. The one legitimate
  question is a genuine owner-only choice (a product behaviour, a locked-decision
  conflict, a scope call); when the reporter is reachable, ask it; when they are not
  (see below), record it under **Open questions** with a recommended default and file
  with `status: ready`. Use `status: clarifying` only when the entry is unactionable
  without that answer.
- **Keep §4 to confirmation, not re-investigation.** Read the cited lines to check they
  still say what the brief claims and to write an accurate proposed approach; do not
  re-derive the finding or widen into a second review.
- **Pin the reading scope.** The project profile (`docs/backlog/PROJECT.md`), the
  template, and one recent `REQ-*.md` for format are enough. Do not browse the backlog
  or the archive looking for context the brief already supplies.
- **Cite the source.** Put where the brief came from in **Notes** (e.g. "found by the
  2026-09-04 read-only review, finding F-042"); never a path to an untracked or
  temporary file — a dead reference is the project's own named failure mode.

**When the reporter cannot answer.** A coordinator dispatching many intakes in parallel
(one subagent per finding) cannot relay `AskUserQuestion` prompts, and a subagent has
no human on the other end. If the invoking brief says the reporter is unreachable, or
you are running as a subagent, do not call `AskUserQuestion` at all — every choice the
skill would normally put to the user becomes an Open question with a recommended
default, and your final report names the ones that need the owner.

This mode is what made a 76-entry batch (2026-09-05) run at roughly 70–150 seconds per
entry: the slow parts of intake are the human round-trips and the re-investigation,
not the file write.

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

**Stage on a named ref before you commit — never a detached HEAD.** A repo that
dedicates a worktree to `main` (e.g. a standing coordinator worktree) will refuse
`git checkout main` from any other checkout (`fatal: 'main' is already used by
worktree at ...`). The silent-looking workaround — `git checkout origin/main` — does
not fail, but it lands on a **detached HEAD**: a commit made there is real, but no
branch points at it, so it survives only as long as the reflog does. Because this
step ends by pushing (below), that window is normally seconds, not sessions — but if
`main` is held elsewhere you still need *something* named to commit onto and push
from:
1. `git fetch origin` and check whether `main` is free (`git worktree list` — if no
   row shows `main` checked out elsewhere, it's yours to use normally).
2. If `main` is free: work on it, fast-forwarding to `origin/main` first if it's
   behind. If it's *ahead* of `origin/main` with commits that aren't yours, leave
   them alone (they're someone else's work mid-flight) and just add yours on top.
3. If `main` is held by another worktree: do **not** fall back to checking out
   `origin/main` directly. Create a real, named branch from it instead —
   `git checkout -b backlog-req-pending origin/main` (or reuse one you already made
   this session) — you'll push straight from it below and can discard it once pushed.

**Deliver with a direct push to `main` — no branch left open, no PR, no CI gate**,
unless the project's own `docs/backlog/PROJECT.md` says otherwise, **or the invoking
coordinator explicitly instructs commit-only for a batch** (its own brief forbids
subagents pushing, and it pushes the whole batch once at the end). In the commit-only
case, still commit under the lock exactly as below, skip the push, and say in your
confirmation (§6) that the commit is local on `main` and who is expected to push it. This mirrors
`qa-intake`'s delivery policy for its own catalog, for the same reason: a `REQ-*.md`
file plus its `BACKLOG.md` row is inert documentation nothing in `make gate` executes
as code, so gating it behind a branch/PR/CI cycle is ceremony that doesn't protect
anything — it only protects the *fix* a coordinator later builds from it, which still
goes through the full cycle at dispatch/integration time regardless. Leaving it
committed-but-unpushed instead is the actively worse option: it has caused real
incidents in practice — a REQ invisible to a coordinator reading only `origin/main`,
and (separately) local-only backlog commits getting swept into an unrelated PR's
history under GitHub's squash-merge, because they were sitting unpushed on the same
`main` a different push went out from. Pushing immediately removes the window both
failure modes need.

- If the project defines a fast, database-free backlog-consistency check (e.g. a
  `check-backlog` target), run it before pushing — cheap insurance against shipping a
  malformed `REQ-*.md`/`BACKLOG.md` pair straight to `main` with nothing else gating
  it. Skip silently if the project has none.
  - **A failure naming a file this session didn't just write is not necessarily a
    real defect — check whether it's committed before treating it as one.** Nothing
    stops a second request-intake session from doing this same workflow in the same
    shared checkout (this skill doesn't use a dedicated worktree the way WP dispatch
    does), and a mid-flight session's own drafted-but-not-yet-committed `REQ-*.md`
    looks, to a filesystem-level check, identical to a genuine orphan. Run
    `git status --porcelain -- <backlog>/` on the offending path(s): if it shows
    uncommitted (`??` or modified), it's very likely someone else's in-progress work,
    not a bug — **never edit, delete, "fix," or commit a file this session didn't
    create**, and don't let it block your own push (your own REQ + `BACKLOG.md` row
    stay staged/committed together as their own atomic unit regardless of what else
    is sitting uncommitted in the tree). Only treat the finding as real, and worth
    surfacing or fixing, once `git log -- <path>` shows it's actually committed.
    Confirmed happening in practice, 2026-09-04: a concurrent session's freshly
    written `REQ-0488` file tripped `check-backlog` for another session before it had
    committed; the file was legitimate and was committed (with its `BACKLOG.md` row)
    moments later.
- Push mechanics: `git fetch origin main && git rebase origin/main` (only if you
  weren't already at its tip) `&& git push origin HEAD:main`. Plain fast-forward,
  never `--force`. If it's rejected because `main` moved since your fetch, that's an
  ordinary push race — fetch, rebase, and retry, same as any other push, rather than
  forcing over someone else's commit.
- If the push keeps failing for a reason other than an ordinary race (auth, a
  server-side hook rejection), don't loop on it — say so plainly in your confirmation
  (§6) and leave the commit local rather than silently giving up on delivery. The
  entry still exists and is safe (it's a real commit on a named ref); it's just not
  on `origin/main` yet, and a human or a coordinator run needs to know that
  explicitly rather than assume every filed REQ made it there.

**Reserve the ID under a lock — don't just scan-then-write.** Two `request-intake`
sessions can run at the same time against the same backlog (different terminals,
different agents) — and so can a `backlog-coordinator` session, reading and
committing to the very same `BACKLOG.md` while you're mid-conversation with the
user. A bare "scan for highest, add 1" has a race: both sessions can scan before
either writes, see the same highest number, and collide on the same `REQ-NNNN`.

**This race is worse than one working directory.** The project convention is one
dedicated `git worktree` per work package (`.worktrees/<wp>`), and a local
`mkdir` lock scoped to `<backlog>/` only closes the window between sessions
sharing *that* directory. Two sibling worktrees each scanning their own checkout
of `docs/backlog/` can independently land on the same "highest + 1" — neither
sees the REQ the other just wrote, because it hasn't reached either of their
branches yet. That's a real collision that has happened in practice, not a
theoretical one.

**Reserve the number with this skill's `scripts/reserve-req-id.sh` instead of
scanning.**

> **The script ships with this skill — it is not in the target project.** Resolve it
> relative to this SKILL.md's own directory, not the repo you're filing into. Written
> bare as `scripts/reserve-req-id.sh`, it reads as repo-relative, and an agent working
> in a project checkout looks for `./scripts/reserve-req-id.sh`, doesn't find it, and
> silently falls back to scan-then-write — which is the exact collision this section
> exists to prevent. Confirmed happening in a real project (2026-08-26): every intake
> run there had been scanning, and nobody knew, because the fallback is quiet.
> If you genuinely cannot locate the script, **say so in your report** and note that
> the number was scanned rather than reserved.

It takes its lock on a counter file under the shared `.git` directory
(`git rev-parse --git-common-dir`) rather than inside any one worktree — every
worktree of the same clone already shares that directory, so the reservation is
visible to every sibling worktree immediately, regardless of which branch each
has checked out. Run it, then use the printed number for everything below.
`flock` makes the read-increment-write atomic, so the conflict window is
sub-second rather than however long a session takes to draft and commit. It does
not cover two genuinely separate clones (e.g. different machines) reserving at
the same instant — accepted as out of scope for now.

Still use the `mkdir` lock for the **rest** of the critical section below — making
the REQ file and its `BACKLOG.md` row appear together, atomically, so nothing
outside this skill ever observes one without the other:

1. Draft the full entry content first (frontmatter + body, with `id: REQ-XXXX` as a
   placeholder and the filename slug already chosen) to a temp file, so the only
   thing left to do under the lock is pick the number, write the file, update the
   index, and commit.
   **Run the whole critical section — steps 2 through 3.d below — as ONE shell
   invocation**, with a `trap` that releases the lock on EXIT. Not "a few quick tool
   calls": one script. Each tool call an agent makes while holding the lock is a
   model round-trip that can run tens of seconds, and past 120 s the lock reads as
   abandoned to every other session (step 2), which is exactly how two sessions end
   up editing `BACKLOG.md` at once. A single script holds the lock for seconds. Retry
   `git commit` inside the script (a few attempts, ~2 s apart) if it fails on
   `index.lock` — another session's commit in progress — rather than returning to
   the model to decide.
2. Acquire the lock: retry-loop `mkdir <backlog>/.req-lock` (mkdir is atomic — it
   fails if the directory already exists, so exactly one concurrent session wins).
   - On failure, check the lock's age (`stat -c %Y <backlog>/.req-lock`, or `%m` on
     BSD/macOS `stat`). If it's older than 120 seconds, treat it as abandoned by a
     crashed/killed session, `rmdir` it, and retry the `mkdir` immediately.
   - Otherwise back off briefly (e.g. 1–2s) and retry. Don't spin tight.
3. **While holding the lock, do all four of the following before releasing it:**
   a. Run **this skill's** `scripts/reserve-req-id.sh <backlog>` (see the note
      above — it is not in the target repo) to get the number (zero-pad to 4
      digits) and write `<backlog>/REQ-<NNNN>-<short-kebab-slug>.md` with the
      full drafted content. Run this *inside* the `mkdir` lock too, even though
      it has its own internal lock — that keeps the number reservation and the
      file write ordered against each other within this worktree, and costs
      nothing since the script returns in well under a second.
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
4. **After** releasing the lock (don't hold it across a network call), push per
   "Deliver with a direct push to `main`" above (skip if 3.c skipped — no git repo,
   nothing to push). The lock only needs to protect the local ID-reservation +
   atomic commit; the push race against `origin` is a separate, ordinary
   fetch/rebase/retry concern, same as any other push.

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

**Corrections go back under the lock.** If you notice a defect in your own entry or
index row after releasing the lock (a quoting artifact, a wrong slug, a typo in the
title), fix it by re-acquiring the lock and committing the fix as its own commit —
never by editing `docs/backlog/` in place while another session may be mid-commit.
Confirmed in a parallel batch (2026-09-05): one session fixed its own `BACKLOG.md` row
outside the lock, and a neighbouring session's `git add docs/backlog/BACKLOG.md`
swept that edit into *its* commit. The content ended up correct, but attributed to
the wrong commit, and only because the edit happened to be benign.

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
clickable link). When filing from a structured brief for a coordinator (§0b), keep it
to one line — ID, path, status, type, commit hash, and the single open question that
needs the owner, if any — and do not paste the entry body back. If status is `clarifying`, state plainly what's still needed. If you
wrote a **Proposed approach**, say so in one line and note it's the coordinator's to
confirm (or, if you validated a choice with the user, that it's recorded). In a git
repo, confirm it's **pushed to `origin/main`** (not just committed) — that's what
makes it safe for a coordinator reading `origin/main` to see and act on immediately,
without needing to know which checkout or branch it was filed from. If the push
didn't go through (§5's "if the push keeps failing" case), say so explicitly instead
— name the branch the commit is actually sitting on, and that someone still needs to
push it by hand. Don't promise a timeline or priority — that's the coordinator's call.

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
