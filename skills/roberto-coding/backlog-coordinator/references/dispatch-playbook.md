# Dispatch Playbook

Exact mechanics for dispatching, verifying, integrating, and merging a work package.
The values in angle brackets come from the **project profile**
(`docs/backlog/PROJECT.md`) and the docs it points to. When the profile and this file
disagree, the profile wins — re-read it.

Placeholders used below:
- `<gate>` — the profile's green-gate command (e.g. `pnpm -r typecheck && pnpm -r test && pnpm -r build`).
- `<install>` — the profile's install command (e.g. `pnpm install`).
- `<main>` — the default branch (usually `main`).
- `<migrations-dir>` / `<migration-rule>` — from the profile.
- `<composition-roots>` — the coordinator-owned files from the profile.
- `<dispatch>` — the profile's dispatch mode (external CLI, `Agent` tool, or by hand).

## Table of contents
1. Worktree setup
2. Dispatching a coding agent (opencode data-dir isolation, concurrency cap)
3. Verifying a finished WP
4. Trial 3-way merge
5. Integration (coordinator-owned wiring)
6. Integration testing
7. Push, PR, CI, merge
8. Updating the backlog

---

## 1. Worktree setup
One dedicated worktree per WP. Worktrees live under `.worktrees/` (gitignore it via
`.git/info/exclude` if it isn't already). Never share a working directory between
agents.

```bash
git fetch origin
git worktree add .worktrees/<wp> -b wp-<wp> origin/<main>
```
`<wp>` is the slug recorded in the REQ's `wp:` field, e.g. `req0007`.

**Fast path.** For a REQ that qualifies under the SKILL's fast-path rule (small,
low-risk, single-file, no composition-root/schema touch), skip §2 (dispatch) entirely:
make the change yourself in this same worktree, commit it, and go straight to §3.
Still run §3's verification even though you wrote the change — the gate rerun and the
named-criterion check catch mechanical slips a same-sitting self-review misses, and
they're the cheap part; the agent round-trip was the expensive part this path removes.

## 2. Dispatching a coding agent
Run from **inside** the WP's worktree. The agent commits locally; it does NOT push or
open a PR — integration is the coordinator's job.

Use the profile's `<dispatch>` mode:

- **External CLI** (e.g. opencode) — give the instance its **own isolated data dir**
  (see below — required, not optional), then run the profile's command from inside
  the worktree, for example:
  ```bash
  cd .worktrees/<wp>
  XDG_DATA_HOME="<isolated-data-dir-from-below>" opencode run "<work-package prompt>" -m <model> --dangerously-skip-permissions
  ```
- **Claude subagents** — launch the `Agent` tool (general-purpose) with the
  work-package prompt; have it commit locally in the worktree. **Do not pass
  `isolation: "worktree"` (or `"remote"`) on this call.** That parameter creates a
  *second*, harness-managed worktree (`.claude/worktrees/agent-<id>`, branch
  `worktree-agent-<id>`) and silently confines the agent's git/filesystem access to
  it — the WP prompt's instruction to `cd` into `.worktrees/<wp>` and commit on
  `wp-<wp>` then can't actually be followed, because step 1's worktree already
  provides the isolation this mode needs. Observed twice in one dispatch wave
  (2026-08-23): both agents committed real, correct work onto the auto-created
  branch instead of the assigned one, and one also produced a confusing early stub
  response before a real final report followed on the same task-id — plausibly the
  same conflict, not a separate bug. Leave `isolation` unset; if it happens anyway,
  recover with `git diff <base>..<agent-commit>` / `git cherry-pick` onto the
  correct WP branch, then re-run the full verification in §3 yourself before
  trusting it — don't take the agent's own gate/test claims for a worktree it
  couldn't actually reach as-instructed.
- **By hand** — implement the WP yourself in the worktree, committing locally.

The prompt must be self-contained and include: worktree/branch, scope + ownership
boundary, acceptance criteria, "add unit tests for new logic", the green-gate
requirement, "commit locally; do not push/PR", **and the definition-of-done checklist
below, verbatim.** Match the project's work-package style guide if it has one.

### Isolate opencode's data dir (required for the opencode dispatch mode)
opencode's session store (`~/.local/share/opencode/opencode.db`) is a single global
SQLite database with **no per-project or per-worktree isolation**. When several
opencode processes run concurrently against it, they contend for the same file and
one crashes with `Error: Failed to execute statement` — an opencode-internal crash in
its backing store, not a problem with the WP's work; it can happen mid-edit on an
otherwise-sane change. This has been observed with as few as 7 concurrent opencode
processes.

Give **every** opencode-dispatched WP its own store by pointing `XDG_DATA_HOME` at a
per-WP directory, seeded with the existing auth so the instance stays logged in. Do
this every time you dispatch via opencode, not just when running several in
parallel — it costs nothing when running solo and removes the failure mode entirely
when concurrent:

```bash
# from the repo root, before cd-ing into the worktree
OC_DATA="$(pwd)/.worktrees/.opencode-data/<wp>"
mkdir -p "$OC_DATA/opencode"
cp ~/.local/share/opencode/auth.json ~/.local/share/opencode/account.json "$OC_DATA/opencode/"

cd .worktrees/<wp>
XDG_DATA_HOME="$OC_DATA" opencode run "<work-package prompt>" -m <model> --dangerously-skip-permissions
```
`.worktrees/.opencode-data/<wp>` is a sibling of the WP worktrees, so it's covered by
the same `.worktrees/` gitignore/exclude entry from step 1 and needs no separate
cleanup — remove it along with `.worktrees/` (or per-WP as each worktree is torn
down).

### Cap concurrency
Even with isolated stores, don't fire every disjoint WP at once — each opencode/agent
process is a real CPU/memory/API-rate cost, and a large batch dying together (e.g.
overnight) is harder to triage. Dispatch in **batches of 2–3 concurrent WPs**,
letting a batch finish (or fail cleanly) before starting the next, unless the profile
specifies a different limit. Serialize anything sharing files or the single
schema-migration slot regardless of batch size.

### Definition of done — paste into every WP prompt verbatim

§3 below is the coordinator's own post-hoc verification checklist. Give the agent the
*same* checklist as part of its own definition of done, so it self-verifies before
handing back instead of the coordinator discovering the gap afterward and paying for a
re-dispatch round-trip. This is not belt-and-suspenders: across real dispatches, agents
have repeatedly reported "tests pass" or "no gaps" while under-reporting their own test
counts, missing named acceptance criteria, and once, twice in a row, renaming an
*existing* test to make an unmet criterion look covered. §3's checks exist because none
of that surfaced until the coordinator re-ran them independently — asking the agent to
run them first is strictly cheaper than a round-trip, and catches most of it before the
coordinator ever needs to look.

**Calibrate item 5's pinning-test rigor to risk, not uniformly.** The full
per-named-criterion pinning test is warranted whenever the WP touches a path the
profile's domain invariants call out (data-loss, security, privacy, or a similarly
load-bearing correctness path) — keep it at full strength there regardless of diff
size. For a purely cosmetic or copy-only change, a lighter check (or none) is
proportionate; forcing a bespoke pinning test onto a two-line CSS fix has, in practice,
cost more than the fix itself once a shifted line number cascades into unrelated
line-range-based waivers elsewhere in the same file. When in doubt, treat it as
load-bearing and keep the full checklist — this calibration is permission to go
lighter on low-stakes changes, not a default toward skipping it.

> Before you report this work package done:
> 1. Run `<install>` and `<gate>` yourself. If it fails, fix it and re-run — keep
>    iterating until it's actually green. Don't hand back a red or unverified result
>    on the theory that the coordinator will catch it; that costs a full round-trip.
> 2. If the profile records a test-count/coverage baseline, run its check command and
>    paste the output. Never hand-count or estimate your own test total — every WP
>    that has, under-reported.
> 3. For every **named** acceptance criterion in the REQ (a `Test...`-shaped bullet),
>    confirm the exact function exists in your delivered tree, e.g.:
>    `git grep -n -E '^func (TestNamedCriterionOne|TestNamedCriterionTwo)\('`
>    (substitute the real names, and the language's own idiom if not Go). If a
>    criterion is already covered by an existing test, say so explicitly and cite
>    it — do **not** rename an existing test to make it look like new coverage; that
>    gets caught and reverted, and costs more time than admitting it was covered.
> 4. If you deleted or renamed any test you didn't write this session, justify every
>    one in your report. An unexplained disappearance is treated as a verification
>    failure, not an oversight.
> 5. **If this work package's scope spans more than one implementation of the same
>    interface** (e.g. several provider/connector/adapter implementations behind one
>    seam), add a test **per implementation**, not one test against whichever one you
>    happened to exercise first. A fix proven against one implementation and silently
>    wrong for the others is the most expensive class of bug this process produces —
>    invisible to a single-target gate, and it only surfaces later, in someone else's
>    integration.
> 6. **If this work package's scope touches a live external integration** (a real
>    provider/API/service the gate deliberately fakes), write the live-only test now —
>    gated out of the regular run (e.g. a build tag) even though you cannot execute it
>    against the real service yourself. A green hermetic gate proves the code is
>    *correct*; it never proves it *works* against the real permissions/contract the
>    fakes stand in for. Leaving that test unwritten turns a one-line addition now into
>    a live-integration debt someone has to notice missing later, often only by running
>    the real thing by hand.
> 7. State plainly in your final report which of 1–6 applied and what you ran — not
>    just "tests pass" or "no gaps found." A claim without the command that backs it is
>    exactly what has gone wrong before.

## 3. Verifying a finished WP
From inside the WP's worktree:

```bash
# Ownership: only declared scope changed; composition roots untouched unless this WP owns them
git --no-pager diff --stat origin/<main>...HEAD

# Migrations: per <migration-rule> (e.g. additive only, at most one new file, correct next number)
ls <migrations-dir>

# Green gate
<install>
<gate>
```
A WP should add tests, never silently drop coverage (compare against the profile's
baseline test counts if it records them). If verification fails, re-dispatch with the
precise failure as feedback instead of hand-patching.

### Named acceptance tests and test renames
The coordinator must also verify the test-shaped criteria against the REQ, rather than
trusting the agent's final report:

```bash
# Replace the names with every named Test... criterion in the REQ.
git grep -n -E '^func (TestNamedCriterionOne|TestNamedCriterionTwo)\(' HEAD -- '*_test.go'

# Review every test declaration deleted from a touched test file.
git diff --unified=0 origin/main...HEAD -- '*_test.go' \
  | grep '^-' | grep -E '^-[[:space:]]*func Test' || true
```

Every named criterion must have a test function in the delivered tree. If the function
already existed on `origin/main`, verify that it already proves the criterion and record
that fact; do not ask the agent to duplicate or rename it. Every deleted `Test...`
declaration must be justified. An unexplained missing criterion or test disappearance is
a verification failure and should be returned to the WP with the precise finding.

## 4. Trial 3-way merge
Branches often have a stale base. Prove the merge is clean in a throwaway worktree
before touching `<main>`:

```bash
git worktree add .worktrees/trial-<wp> origin/<main>
cd .worktrees/trial-<wp>
git merge --no-ff --no-commit wp-<wp>   # inspect for conflicts; abort when done
git merge --abort
cd -
git worktree remove .worktrees/trial-<wp>
```
Resolve conflicts at the source (re-dispatch or coordinator wiring), not by force.

## 5. Integration (coordinator-owned wiring)
Only the coordinator edits the `<composition-roots>` named in the profile (e.g. a
worker/queue registry, a route-registration file). Keep these edits minimal — agents
expose dependencies; you connect them.

## 6. Integration testing
On the integrated tree (after wiring), beyond the green gate, run what the profile's
integration / smoke / e2e docs prescribe. Confirm the REQ's acceptance criteria pass
end-to-end and the profile's **domain invariants** still hold.

## 7. Push, PR, CI, merge
Only if the profile's operating mode permits — and only on green.

```bash
git push -u origin wp-<wp>
gh pr create --fill --base <main> --head wp-<wp>   # body ends with the profile's PR footer
gh pr checks --watch                               # wait for the profile's CI workflow
```
- Commit messages end with the profile's commit footer.
- If CI is red: diagnose, fix or re-dispatch, re-push. **Never merge red.**
- Merge when green:
```bash
gh pr merge --merge --delete-branch
```
- Clean up: `git worktree remove .worktrees/<wp>`.

## 8. Updating the backlog
After merge, for each delivered REQ:
- Set `status: done` in `<backlog>/REQ-<NNNN>-*.md`.
- Update its row in `<backlog>/BACKLOG.md` (status + PR link in Notes if useful).
- If the work surfaced new issues, file them as new `REQ-*.md` entries (same format
  as the request-intake template) so nothing is lost.

### A concurrent request-intake session can be writing to the same backlog
`request-intake` sessions run independently of the coordinator — a different
terminal, a different agent, often the user actively filing reports while you work
a wave. As of the current `request-intake` skill, each request it files is
committed atomically (REQ file + `BACKLOG.md` row, one commit) the moment it's
written, which closes most of the risk. But you can still observe a window between
"they wrote it" and "they committed it," and the reverse has already caused a real
incident once: a coordinator's own commit picked up an in-progress `BACKLOG.md`
row with no REQ file behind it (via a blanket `git add docs/backlog/BACKLOG.md`)
and shipped a `check-backlog`-failing `main`.

Before every coordinator commit that touches `<backlog>/BACKLOG.md` or any
`REQ-*.md` file:
- **Never `git add -A` or a bare `git add <path>` on a shared backlog file without
  checking first.** Run `git status --short <backlog>/` immediately before staging.
  If it shows untracked `REQ-*.md` files or a `BACKLOG.md` diff you didn't just
  make yourself, that's someone else's in-flight work — don't fold it into your
  commit on a guess.
- If it's safe and clearly complete (a well-formed REQ file with full frontmatter,
  matching its own `BACKLOG.md` row) and leaving it split across commits would
  itself leave `main` gate-red, committing it alongside yours is the right call —
  better than a broken `main` — but say so explicitly in the commit message rather
  than silently absorbing it.
- Otherwise, `git stash push -u -- docs/backlog/` before your own edits, make your
  clean commit, then `git stash pop` to restore their in-progress state exactly as
  you found it — never delete or overwrite content you didn't author without being
  asked.
- After any rebase/pull in the shared checkout, re-run `make check-backlog` before
  pushing — it's the one check that would have caught this class of break, and it's
  cheap enough to run on every backlog-touching commit, not just at wave boundaries.
