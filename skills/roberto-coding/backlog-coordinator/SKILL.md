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

## Workflow

### 1. Load the backlog
Read `<backlog>/BACKLOG.md` and every `REQ-*.md` with `status: ready`. Ignore
`clarifying` (intake isn't done), `done`, and `wontfix`. If an otherwise-good item
has unresolved **Open questions** that block design, either resolve them from the
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
  expose dependencies, you wire them (step 7). State this boundary in every WP prompt.
- **Schema rule.** Follow the profile's migration rule (typically additive-only, at
  most one schema-touching WP per parallel wave so migration numbers don't collide).
- Each WP prompt must state: the worktree + branch, the scope and ownership boundary,
  the acceptance criteria (copy from the REQ), the requirement to add **unit tests**
  for new logic, the green-gate requirement, **"commit locally; do NOT push or
  open a PR"** (you own integration), and the **definition-of-done checklist**
  (`references/dispatch-playbook.md` §2) verbatim — it hands the agent the same
  self-check you'd otherwise have to run yourself at step 6, so gaps surface in the
  agent's own turn instead of a re-dispatch round-trip. **Calibrate item 5's per-criterion
  pinning-test rigor to the profile's domain invariants** — full weight for a WP touching
  a data-loss/security/privacy-critical path, lighter for a purely cosmetic or
  copy-only change. Applying the heavy version everywhere has a real cost beyond the
  agent's own time: a pinning test that shifts line numbers in a shared test file can
  cascade into unrelated edits (e.g. line-range duplication waivers) that have nothing
  to do with the fix.
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
- **Fast path for small, low-risk REQs** (`p2`/`p3`, single-file, doesn't touch a
  composition root or the schema): the coordinator may implement it directly in the
  WP's worktree instead of writing a dispatch prompt and invoking an agent — skip
  straight from worktree setup to the change itself. Still run the full definition-of-done
  checklist yourself (`references/dispatch-playbook.md` §2), still do the trial merge,
  and still go through PR → CI → merge exactly as for a dispatched WP — none of that is
  the expensive part; the round-trip through a separate agent process and its own
  self-verification pass is. Use judgement: if you're not confident you understand the
  fix as well as an agent that read the surrounding code would, dispatch instead.

### 5. Dispatch (dev + unit testing)
For each WP, per `references/dispatch-playbook.md`: create the dedicated worktree,
then run the coding agent from inside it using the profile's **dispatch mode** (an
external CLI such as opencode, or the `Agent` tool, or by-hand). Launch agents for
disjoint scopes in parallel where it's safe; serialize anything that shares files or
the one schema slot. Agents commit locally and do not push.

**If the dispatch mode is opencode**, give each instance its own `XDG_DATA_HOME`
(playbook step 2) — opencode's session store is one shared global SQLite file with no
per-process isolation, and concurrent instances contend on it and crash mid-edit with
`Error: Failed to execute statement` (an opencode-internal failure, not a bad WP).
Also cap concurrency to 2-3 WPs at a time rather than dispatching the whole wave at
once.

### 6. Verify each WP
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

### 7. Integrate
Do the reserved composition-root wiring yourself (the files the profile marks
coordinator-owned). Resolve cross-WP conflicts. Keep these edits minimal and
coordinator-scoped.

### 8. Integration testing
This is your responsibility, not the per-WP agents'. Per the profile's integration /
smoke / e2e docs:
- Re-run the full green gate on the integrated tree.
- Run the smoke checks and, where the change touches the relevant pipeline/area, the
  integration / E2E harness the profile points to.
- Confirm the REQ's acceptance criteria actually pass end-to-end, including the
  **domain invariants** the profile lists. If anything fails, loop back to step 5/6
  for the responsible WP.

### 9. Push, PR, CI, merge (per profile policy)
Only if the profile's operating mode allows it; otherwise stop and hand off. When it
does:
- Push the branch; open the PR with `gh`, body ending in the profile's PR footer.
- Commits end with the profile's commit footer.
- Wait for CI to go green (the profile's CI workflow). If CI fails, fix or
  re-dispatch, then re-push — do not merge red.
- Merge once green. Then set each delivered REQ's `status: done` and update the
  `<backlog>/BACKLOG.md` index row.

### 10. Report
Summarize: which REQs shipped (with PR links), which were deferred and why, any new
follow-up REQs the work surfaced (you may file these via the same backlog format),
and the final backlog state.

## Boundaries
- **Don't relitigate locked decisions** (profile). Build within them.
- **Don't edit another WP's scope by hand** to paper over a failure — re-dispatch
  with feedback, so the fix is real and tested.
- **Never merge on red CI or a failing gate**, autonomy notwithstanding.
- **Schema discipline**: follow the profile's migration rule; never destructive.
- **Respect the merge policy.** If the profile says pause for human merge (or there's
  no profile), do not push/merge on your own.
- If the backlog has nothing `ready`, say so and stop — don't invent work.
