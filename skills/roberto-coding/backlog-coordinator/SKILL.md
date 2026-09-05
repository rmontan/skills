---
name: backlog-coordinator
description: >-
  Process a project's backlog: prioritize logged requests, turn them into work
  packages, dispatch them to coding agents for development + unit testing, then do
  the integration and integration testing — and (per project policy) push, open
  the PR, wait for CI, and merge. Use this whenever the user wants to "work the
  backlog", "build the next thing", "prioritize and dispatch", "process
  docs/backlog", "ship REQ-XXXX", or otherwise move recorded requests from idea to
  merged code. It reads entries written by the request-intake skill. Use
  request-intake instead when the user is *reporting* a new bug/feature rather than
  *acting on* the backlog.
---
# Backlog Coordinator

You are the engineering coordinator for this project. You take requests that the
`request-intake` skill recorded under the backlog directory, decide what to build and
in what order, write work packages, dispatch coding agents, verify and integrate
their work, and carry it through PR, CI, and merge.

This skill is **project-agnostic**. The mechanics that differ per repo — build/test
commands, how work is dispatched, which files only you may edit, the domain
invariants, and the merge policy — all come from a **project profile**, not from this
file. Read it first; don't hardcode assumptions.

## Project profile (read first, every run)

1. **`docs/backlog/PROJECT.md`** — the canonical profile if present. It defines the
   backlog location, the docs to read, the green-gate command, the dispatch mode, the
   coordinator-owned composition roots, the domain invariants, the locked decisions,
   and the delivery/merge policy. **This is the contract you operate under.**
2. Then read whatever it points to — typically a handoff/architecture doc, a
   work-package style guide, and integration/e2e/smoke docs.
3. If there's no `PROJECT.md`, infer what you can (stack from the manifest, backlog at
   `docs/backlog/`) and **operate conservatively**: default to dispatching via Claude
   subagents (the `Agent` tool), and to **stopping before push/PR/merge for human
   review** unless the user tells you otherwise. Offer to scaffold a `PROJECT.md` from
   the request-intake skill's `assets/project-profile-template.md`.

The mechanics below are described generically; `references/dispatch-playbook.md` has
the command-level recipes with the profile's values substituted in.

**Operating mode** comes from the profile's delivery policy. It may be *autonomous
through merge* (you may push, open PRs, wait for CI, and merge without pausing),
*open-PR-then-pause*, or *local-commits-only*. Whatever it is, the gates below are
what keep autonomy safe. The one thing you never skip is the green gate + trial merge
before you push.

## On-demand: list the ready queue (no dispatch)
When asked to show or list the open/ready requests — "what's in the backlog", "list
open reqs", "show the ready queue" — without a broader instruction to build or ship,
run a **read-only preview** instead of the full workflow below: step 1 (load +
overlap scan) and step 2 (prioritize), plus the bundling from step 4 and the
complexity scoring from step 5. Then stop.

- Don't create worktrees, dispatch agents, push, or write frontmatter back to any
  REQ — this is a preview, not a commitment. (Step 2's "write the priority back"
  instruction applies to the full workflow, not this mode.)
- Present a table: REQ id, title, priority, proposed WP grouping (which REQs you'd
  bundle into one WP and why — the file/area overlap from step 1's scan), and the
  **complexity score (1-5)** for the resulting WP per step 5's rubric. If the
  profile defines dispatch tiers, add which tier/model each WP would route to.
- End by asking which (if any) to actually build, or wait for a separate instruction
  to proceed — don't fall through into dispatching just because you already did the
  analysis.

## Workflow

### 0. Reconcile git state before reading anything
This is not optional and not covered by a clean `git status` — a clean working tree
says nothing about whether local `main` matches `origin/main`, whether another
worktree or process already has work in flight, or whether a `request-intake`
session left a filed REQ on a branch you're not looking at. Run this before reading a
single REQ:

```
git branch --show-current                   # are you even where you think you are?
git fetch origin
git log --oneline origin/main..main         # local-only commits — don't lose these
git log --oneline main..origin/main | wc -l # how far behind, if at all
git worktree list                           # other WPs, or a stray intake branch, already checked out?
```

Plus whatever this project uses to detect a live concurrent dispatch process (e.g.
`pgrep -af opencode` if the profile's dispatch mode is an external CLI).

- **If local `main` is behind `origin/main`:** fast-forward before doing anything
  else (`git merge --ff-only origin/main`, or rebase if you have local-only commits
  worth keeping — see the fast-forward-or-rebase recipe below).
- **If local `main` has commits `origin/main` lacks:** don't assume they're stale or
  yours. `request-intake` pushes each REQ to `origin/main` directly as its normal
  delivery path (mirroring `qa-intake`'s catalog policy), so this should be rare —
  but it falls back to a local-only commit when that push fails (auth, a rejected
  push it couldn't resolve), and it says so explicitly when it does. Read any such
  commits in; they may be a REQ that belongs in this run's backlog scan and never
  made it to `origin/main`. Never discard them to get to a "clean" state.
- **If `git worktree list` shows a branch that isn't a known WP** (e.g. a
  `request-intake` session's leftover staging branch from a failed push, or a
  detached-HEAD checkout with a branch someone anchored it to after the fact — see
  `request-intake`'s own §5): treat it the same as a local-only commit on `main` —
  read it in, don't ignore it because it's not where you expected to look.
- **If a live dispatch process is already running:** its worktree's REQ is already
  spoken for — don't re-read or re-dispatch it.

Only once local state is reconciled against `origin/main` (and you know what, if
anything, is running concurrently) should you move to step 1.

### 1. Load the backlog
On a mature backlog, `<backlog>/BACKLOG.md` is almost entirely closed-out history
(`done`/`wontfix`) that this step never uses — don't pull the whole file into
context to get a handful of live rows. Grep it for the non-terminal statuses
instead of reading it whole:

```
grep -E '\| (ready|in-progress|clarifying)' <backlog>/BACKLOG.md
```

Then read every `REQ-*.md` matching `status: ready` in full. Ignore `clarifying`
(intake isn't done), `done`, and `wontfix`. If an otherwise-good item has
unresolved **Open questions** that block design, either resolve them from the
codebase/docs yourself or, if they truly need the user, surface them and skip that
item for this run rather than guessing.

**Scan for file overlap across the `ready` set** before you prioritize: compare each
entry's `areas:` frontmatter (grep the codebase directly if an entry lacks one or the
field is stale) and flag any two or more `ready` REQs that touch the same file or a
tightly-scoped shared package. Also read each entry's Notes for a pre-existing
`Coordinator note` that already flags a batching or sequencing opportunity — a prior
run may have left one. Carry this overlap map into step 4; it's the main input for
deciding what to bundle.

### 2. Prioritize
Assign each `ready` item a priority `p0`–`p3` and order the run:
- **p0** data loss, security/privacy exposure, or app broken for all users.
- **p1** core correctness; blocks the project's main validation thread.
- **p2** meaningful improvement, not blocking.
- **p3** nice-to-have / cosmetic.

Tune these bands to the project's domain invariants (profile). Weigh impact against
effort and risk, and respect the profile's locked decisions — a request that
contradicts one is a `wontfix` (record the reason in the entry's Notes) unless the
user explicitly overrides. Write the chosen `priority` back into each entry's
frontmatter. Briefly tell the user the ranked plan before you start dispatching, so
they can interrupt — then proceed.

### 3. Weigh any proposed approach the entry carries
Some entries arrive with a **Proposed approach** section — the `request-intake` skill
writes one when it investigated the issue (read code, reproduced, traced a root cause).
When an item has one, don't skip past it and don't rubber-stamp it either:
- **Validate it against the codebase.** Check the root cause and the proposed fix still
  hold — files, line references, and assumptions drift. Confirm it doesn't collide with
  a locked decision or the domain invariants (profile).
- **You have more context than intake did** — the whole backlog, the composition roots,
  cross-REQ interactions, and the migration/schema picture. If that broader view turns
  up a **better solution** (simpler, lower-risk, avoids a conflict with another in-flight
  REQ, or a smaller diff), **do not just silently substitute it.** Surface both — the
  proposed approach and your alternative, with the trade-off and why yours is better —
  and **ask the user to confirm** which to build before you cut the WP. Use
  `AskUserQuestion` for a crisp choice.
- If validation confirms the proposed approach as-is, say so briefly and proceed — no
  need to invent an alternative or ask a needless question.
- If the entry has **no** proposed approach, design the fix yourself as usual; there's
  nothing to reconcile.

Record the outcome (approach confirmed as-is, or replaced with the user-approved
alternative — with a one-line reason) in the REQ before moving on, so the WP prompt and
the audit trail reflect what was actually decided.

### 4. Cut work packages
Group the prioritized work into WPs sized for one coding agent each:
- **Disjoint ownership.** Each WP owns a clear set of files/areas so parallel agents
  don't collide. The profile's **composition roots** are coordinator-owned; agents
  expose dependencies, you wire them (step 8). State this boundary in every WP prompt.
- **Schema rule.** Follow the profile's migration rule (typically additive-only, at
  most one schema-touching WP per parallel wave so migration numbers don't collide).
- Each WP prompt must state: the worktree + branch, the scope and ownership boundary,
  the acceptance criteria (copy from the REQ), the requirement to add **unit tests**
  for new logic, the green-gate requirement, **"commit locally; do NOT push or
  open a PR"** (you own integration), and the **definition-of-done checklist**
  (`references/dispatch-playbook.md` §2's Definition-of-done subsection) verbatim —
  it hands the agent the same self-check you'd otherwise have to run yourself at
  step 7, so gaps surface in the agent's own turn instead of a re-dispatch
  round-trip. **Calibrate item 5's per-criterion pinning-test rigor to the profile's
  domain invariants** — full weight for a WP touching a data-loss/security/privacy-
  critical path, lighter for a purely cosmetic or copy-only change (full reasoning,
  and the cost of over-applying it: that same playbook subsection).
- A WP usually maps to one REQ, but may bundle tightly-related REQs or split a large
  REQ. **REQs that share a file per the step 1 overlap scan are strong bundling
  candidates** — a coding agent that has already read and understood a file can apply
  several small changes to it in one pass more cheaply than two agents independently
  reviewing the same file in separate WPs. Bundle them unless doing so would break
  disjoint ownership or mix unrelated risk profiles (e.g. a data-loss-critical path
  bundled with a cosmetic change); if you choose to sequence instead of bundle, say
  why. Record the chosen `wp:` slug in each REQ's frontmatter and set its
  `status: in-progress`.
- **Default to holding `p2`/`p3` cosmetic or single-file REQs for bundling** rather
  than giving them a solo WP, even when nothing in the current wave overlaps them yet —
  wait for the next WP that touches their file/area rather than dispatching them alone.
  A solo WP pays the full worktree + dispatch + verify + trial-merge + PR + CI cost
  regardless of diff size; riding inside a WP that's paying that cost anyway is close
  to free. Only dispatch one solo if it's blocking or none is in sight for a while.
- **Fast path for small, low-risk REQs** — gate this on the fix's blast radius, not
  the REQ's priority label: single-file (or a file plus its test), doesn't touch a
  composition root, the schema, or a create/write-back/delivery code path. Priority
  measures urgency/impact of the *bug*, not risk of the *fix* — a `p1` classification
  or diagnosability fix (e.g. adding a missing entry to a reason-code taxonomy) can be
  just as low-risk as a `p3` cosmetic one, and should fast-path on the same terms.
  Conversely, anything touching create/write-back/delivery stays on the full dispatch
  path regardless of priority, even a `p2` — that's the data-loss-critical class where
  a wrong fix risks a duplicate or lost write to someone's real address book, not
  something to shortcut on urgency grounds alone. When it qualifies, the coordinator
  may implement it directly in the WP's worktree instead of writing a dispatch prompt
  and invoking an agent — skip straight from worktree setup to the change itself.
  Still run the full definition-of-done checklist yourself
  (`references/dispatch-playbook.md` §2's Definition-of-done subsection), still do
  the trial merge, and still go
  through PR → CI → merge exactly as for a dispatched WP — none of that is the
  expensive part; the round-trip through a separate agent process and its own
  self-verification pass is. Use judgement: if you're not confident you understand the
  fix as well as an agent that read the surrounding code would, dispatch instead.

### 5. Score complexity and pick an agent tier
Score every WP (not every REQ — a bundle gets one score for the group as delivered)
**1-5** on how demanding it is to build correctly:

- **1 — Trivial.** Cosmetic/copy, single file, no branching logic, no new
  abstraction, no composition-root/schema/domain-invariant touch. Usually fast-path
  eligible (step 4).
- **2 — Simple.** Small, well-scoped change, a couple of files, follows an existing
  pattern directly, no schema or composition-root touch, doesn't touch a
  domain-invariant-critical path.
- **3 — Moderate.** Several files/areas, or a straightforward additive schema
  change, or touches one domain-invariant-critical path but with clear precedent
  already in the codebase to follow.
- **4 — Complex.** Cross-cutting across multiple implementations behind one
  interface (e.g. every provider connector), a real design decision the REQ didn't
  already settle, or combines a composition-root change with a
  domain-invariant-critical path.
- **5 — Hard.** High ambiguity, novel design/architecture, concurrency or
  race-condition reasoning, or a bundle whose REQs interact in ways that must be
  reasoned about together rather than independently.

Bundling raises the score (more context, more surface to hold at once) but a bundle
is usually still cheaper than the sum of its parts dispatched solo — score what the
WP actually asks the agent to deliver, not the max of its parts taken naively, and
say why in one line.

Record the score in the WP prompt and in each covered REQ's Notes (`Coordinator
note: WP complexity N/5 — <one-line reason>`) so a later run doesn't re-derive it.

**If the profile defines dispatch tiers** (a mapping from complexity band to
mode/command/model — `references/dispatch-playbook.md` §2), the score is what
selects the tier in step 6: typically a cheap/fast model for 1-2, a mid-tier model
for 3-4, and the most capable (and most expensive) model reserved for 5 alone —
genuinely hard work, not "whatever the highest score in this wave happened to be."
If the profile has no tiers, the score is still worth recording — it's cheap, and
useful the next time someone reads this REQ — but route every WP through the
profile's single dispatch mode as before; don't invent a tier mapping the profile
doesn't have. If the user asks for tiered dispatch and the profile doesn't define
one, offer to write it (the request-intake template's Dispatch section has the
format) rather than guessing model names yourself.

### 6. Dispatch (dev + unit testing)
For each WP, per `references/dispatch-playbook.md`: create the dedicated worktree,
then run the coding agent from inside it using the profile's **dispatch mode** (an
external CLI such as opencode, or the `Agent` tool, or by-hand) — and, if the
profile defines tiers, the specific tier that step 5's complexity score selects. Launch
agents for disjoint scopes in parallel where it's safe; serialize anything that
shares files or the one schema slot. Agents commit locally and do not push.

**Cap concurrency regardless of dispatch mode** — dispatch in batches rather than
firing the whole wave at once (playbook §2 has the batch size and the reasoning).

**If the dispatch mode is opencode**, give each instance its own `XDG_DATA_HOME`
(playbook step 2) — opencode's session store is one shared global SQLite file with no
per-process isolation, and concurrent instances contend on it and crash mid-edit with
`Error: Failed to execute statement` (an opencode-internal failure, not a bad WP).

### 7. Verify each WP
Run this regardless of what the agent reported — step 4's definition-of-done checklist
makes the agent self-check first, which should shrink what you find here, but "the
agent says it self-checked" is still not the same as verified. Before integrating, for
each completed WP (see the playbook for commands):
- **Ownership check** — the agent only touched its declared scope; composition roots
  untouched.
- **Migration check** — per the profile's schema rule.
- **Green gate** — run the profile's install + gate command.
- **Trial 3-way merge** into a throwaway worktree from `origin/<main>` (branches often
  have a stale base) to catch conflicts early.
If a WP fails verification, re-dispatch with the specific failure as feedback rather
than hand-fixing silently; note what you did either way.

**Pause before re-dispatching after a failed agent.** If an agent fails to produce
working code (a no-op, garbage output, or a verification failure), do **not** resubmit
the WP to another agent — or the same agent again — without **asking the user first**.
Surface what happened (what the agent produced or didn't, the specific failure) and let
the user decide whether to re-dispatch, take it over by hand, or stop. Do not silently
loop the dispatch.

### 8. Integrate
Do the reserved composition-root wiring yourself (the files the profile marks
coordinator-owned). Resolve cross-WP conflicts. Keep these edits minimal and
coordinator-scoped.

### 9. Integration testing
This is your responsibility, not the per-WP agents'. Per the profile's integration /
smoke / e2e docs:
- Re-run the full green gate on the integrated tree.
- Run the smoke checks and, where the change touches the relevant pipeline/area, the
  integration / E2E harness the profile points to.
- Confirm the REQ's acceptance criteria actually pass end-to-end, including the
  **domain invariants** the profile lists. If anything fails, loop back to step 6/7
  for the responsible WP.

#### Live verification, before closing — not after
**If the profile defines a targeted live-test command** (one test or one area against
the real external service, rather than the full suite), run it for every REQ that
touches that integration, and do it *before* step 10 sets `status: done`.

A hermetic gate exercises every external integration against a fake, so it proves the
code is self-consistent with somebody's belief about the wire format. It cannot fail
when that belief is wrong. Only a live run can.

The failure mode to avoid is not skipping the live test outright — it is deferring it.
A full live suite is usually slow, quota-bound and noisy, so "verify live" becomes a
closing ritual, and requests accumulate in a half-closed status
(`merged (live test pending)` or similar) that no check enforces because no check
matches on it. Observed in practice: two requests parked that way for days, and when
the live tests were finally run they surfaced an active production outage the gate was
structurally incapable of seeing and no dashboard had flagged.

- Use the **targeted** command, not the full sweep. If the profile doesn't define one,
  say so in your report — making per-REQ live verification cheap is usually a small,
  high-value piece of harness work.
- Record what the run showed in whatever field the profile requires (e.g. a
  `live_test:` line), and record it **from the run's own output**, not from memory of
  it. A summary of a run nobody can re-read is a claim, not evidence.
- **Absence of failure is not a pass.** Confirm the test actually executed — a name
  typo, a build tag, or an empty package list can all produce a green-looking "no tests
  to run". Check the count, not just the exit code.
- If a live run is genuinely blocked (credentials expired, provider deferred, quota
  exhausted), say so explicitly in the report and leave the REQ open. Do not close it
  and rely on someone noticing later.

### 10. Push, PR, CI, merge (per profile policy)
Only if the profile's operating mode allows it; otherwise stop and hand off. When it
does:
- **Re-run step 0's `git fetch origin` + divergence check immediately before
  pushing**, not just at the start of the run — a wave can take a while, and another
  session (interactive `request-intake`, a peer coordinator) may have pushed or
  committed to local `main` while you were dispatching. If `origin/main` moved,
  rebase your branch onto it now, not after a rejected push forces the issue.
- **A WP branch built on top of local `main` inherits everything local `main` has
  that `origin/main` doesn't** — this should be rare now that `request-intake`
  pushes each REQ directly, but a failed push falls back to a local-only commit
  (and says so), and other local edits (docs closure notes, etc.) are still
  routine. GitHub squash-merges everything not already on the PR's base, so any of
  that rides along under your commit message with no warning. Before opening the
  PR, diff your branch against `origin/main`
  (`git diff --stat origin/main...<branch>`) and confirm it contains only what you
  intend to ship. If it doesn't, rebase onto `origin/main` first
  (`git rebase origin/main` — duplicate content is skipped automatically) so the
  other commits land on `origin/main` as themselves, separately, rather than
  disappearing into your PR's history.
- Push the branch; open the PR with `gh`, body ending in the profile's PR footer.
- Commits end with the profile's commit footer.
- Wait for CI to go green (the profile's CI workflow). If CI fails, fix or
  re-dispatch, then re-push — do not merge red.
- Merge once green. Then set each delivered REQ's `status: done` and update the
  `<backlog>/BACKLOG.md` index row.
- **Do not use a half-closed status to skip step 9's live verification.** If a REQ
  touches a live integration and the run hasn't happened, either run it now or leave
  the REQ open with the reason stated. A status like `merged (live test pending)` is a
  queue, not a resting place — and it typically sits outside whatever check enforces
  the closing rules, since those match on `done`.

### 11. Report
Summarize: which REQs shipped (with PR links), which were deferred and why, the
follow-up REQs filed per step 8's mandatory scan of each agent's own final report
(with their new REQ ids — this should already be done by the time you write this
summary, not triggered by the user asking for it), and the final backlog state.

## Boundaries
- **Don't relitigate locked decisions** (profile). Build within them.
- **Don't edit another WP's scope by hand** to paper over a failure — re-dispatch
  with feedback, so the fix is real and tested.
- **Never merge on red CI or a failing gate**, autonomy notwithstanding.
- **Schema discipline**: follow the profile's migration rule; never destructive.
- **Respect the merge policy.** If the profile says pause for human merge (or there's
  no profile), do not push/merge on your own.
- If the backlog has nothing `ready`, say so and stop — don't invent work.
