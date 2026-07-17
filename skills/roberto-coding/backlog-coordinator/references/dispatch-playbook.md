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
2. Dispatching a coding agent
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

## 2. Dispatching a coding agent
Run from **inside** the WP's worktree. The agent commits locally; it does NOT push or
open a PR — integration is the coordinator's job.

Use the profile's `<dispatch>` mode:

- **External CLI** (e.g. opencode) — run the profile's command from inside the
  worktree, for example:
  ```bash
  cd .worktrees/<wp>
  opencode run "<work-package prompt>" -m <model> --dangerously-skip-permissions
  ```
- **Claude subagents** — launch the `Agent` tool (general-purpose) with the
  work-package prompt; have it commit locally in the worktree.
- **By hand** — implement the WP yourself in the worktree, committing locally.

The prompt must be self-contained and include: worktree/branch, scope + ownership
boundary, acceptance criteria, "add unit tests for new logic", the green-gate
requirement, and "commit locally; do not push/PR". Match the project's work-package
style guide if it has one.

Run agents for disjoint scopes in parallel; serialize anything sharing files or the
single schema-migration slot.

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
