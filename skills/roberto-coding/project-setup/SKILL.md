---
name: project-setup
description: >-
  Bootstrap a brand-new development project for multi-agent (Claude + opencode)
  collaboration. Use this when the user is starting a new project / repo from
  scratch and says things like "set up a new project", "scaffold a repo",
  "initialize a project", "bootstrap the environment", or "get a project ready for
  the agents". It interviews the user for the initial specs, lays down the shared
  directory tree and contract docs, writes the project profile that the
  request-intake and backlog-coordinator skills read, and initializes git. It does
  NOT implement features or process a backlog — that's request-intake (capture) and
  backlog-coordinator (build).
---

# Project Setup

Your job is to take an empty (or near-empty) directory and turn it into a project
that the **Claude + opencode** agent workflow can operate on immediately. The output
is a shared contract on disk: a directory tree, a handful of docs both toolchains
read, a filled-in project profile, and an initialized git repo.

The end state should be: the user can run `request-intake` to log the first request
and `backlog-coordinator` to build it, with no further wiring. Those two skills are
**global**; they adapt to a repo by reading `docs/backlog/PROJECT.md` — which this
skill writes.

## How Claude and opencode share one contract

- **Claude Code** reads `CLAUDE.md`.
- **opencode** reads `AGENTS.md`.
- Both must point at the same source of truth: `docs/HANDOFF.md` (architecture, locked
  decisions, conventions, dispatch workflow). Keep `CLAUDE.md` / `AGENTS.md` thin —
  they orient the agent and defer to the docs — so the two toolchains never drift.
- The coordinator dispatches opencode agents into per-package **`.worktrees/`** (each
  WP isolated), wires their output at the composition roots, and integrates. The tree
  below reserves all of that.

## Workflow

### 1. Confirm the target & preconditions
- Confirm the directory to set up (default: the current working dir). If it already
  has a git repo or source, **stop and confirm** before scaffolding — don't clobber an
  existing project; this skill is for new ones.
- Check tooling: `git --version`, and `opencode --version` (note if opencode isn't on
  PATH — the project still works, but flag it so the user can install it for dispatch).

### 2. Interview for the initial specs
Gather just enough to fill the contract. Prefer `AskUserQuestion` for the crisp
choices (batch them) and ask inline for the open-ended ones. Cover:

- **Identity** — project name + one-line description.
- **Problem / goal** — what it does and for whom (the "why").
- **Target type** — CLI / web app / HTTP API / library / service / monorepo.
- **Stack** — language(s), package manager / runtime, notable frameworks.
- **Layout** — single package or monorepo; if monorepo, the package names.
- **Domain invariants** — the non-negotiables a change must never break, and any
  sensitive-data angles (PII, credentials/tokens, payments) intake should flag.
- **Locked decisions** — anything the user has already settled and doesn't want
  relitigated.
- **Dispatch mode** — how the coordinator should delegate work packages:
  *opencode CLI* (ask for the default model), *Claude subagents* (the `Agent` tool),
  or *by hand*.
- **Delivery / merge policy** — *autonomous through merge*, *open-PR-then-pause*, or
  *local-commits-only*.

Don't over-interview. Anything the user doesn't know yet, record as a placeholder /
open question in the docs and move on — the project is meant to evolve.

### 3. Scaffold the directory tree
Create this layout (omit pieces that don't fit the target type; keep the `docs/` and
`docs/backlog/` spine always):

```
<project>/
├── CLAUDE.md                 # thin: orients Claude, defers to docs/HANDOFF.md
├── AGENTS.md                 # thin: orients opencode, defers to docs/HANDOFF.md
├── README.md                 # project name, description, how to run
├── .gitignore                # from assets/gitignore.snippet + stack-specific entries
├── docs/
│   ├── HANDOFF.md            # THE contract — from assets/HANDOFF.template.md (§3–§7)
│   ├── WORK_PACKAGES.md      # house style for a WP prompt (stub is fine to start)
│   ├── INTEGRATION.md        # how integration is done here (stub)
│   ├── E2E_TESTING.md        # e2e harness + how to run it (stub)
│   ├── SMOKE.md              # quick smoke checks (stub)
│   ├── backlog/
│   │   ├── PROJECT.md        # profile read by request-intake + backlog-coordinator
│   │   └── BACKLOG.md        # index table (from the request-intake template snippet)
│   └── testing/
│       ├── PROJECT.md        # test profile read by test-intake + test-run
│       └── CATALOG.md        # index of standing checks (empty table to start)
├── .worktrees/              # per-WP worktrees for parallel agents (gitignored)
└── src/                      # or the stack-appropriate source skeleton
```

- Fill `docs/HANDOFF.md` from `assets/HANDOFF.template.md`, substituting the interview
  answers. Keep its section numbering (§3 stack/layout, §4 locked decisions, §5
  conventions, §6 dispatch, §7 next steps) — the profile and the backlog skills
  reference those numbers.
- `CLAUDE.md` and `AGENTS.md`: write from `assets/AGENTS.template.md` (the same thin
  orientation content works for both). They must each tell the agent to read
  `docs/HANDOFF.md` and follow `docs/backlog/PROJECT.md`.
- The `WORK_PACKAGES.md`, `INTEGRATION.md`, `E2E_TESTING.md`, `SMOKE.md` files can
  start as short, honest stubs ("TBD — fill as the project takes shape"); the backlog
  skills tolerate stubs and the user fleshes them out over time.

### 4. Write the project profile
This is the linchpin that makes the global backlog skills work. Create
`docs/backlog/PROJECT.md` from the canonical template `assets/project-profile-template.md`
inside the **sibling `request-intake` skill**.

> Resolve that by locating `request-intake` next to this skill's own directory rather
> than typing an absolute path — installs rename skills
> (`roberto-coding__request-intake` under `~/.claude/skills/`,
> `roberto-coding/request-intake` in the skillshare source), so a hardcoded path goes
> stale silently. This step previously read
> `~/.claude/skills/request-intake/assets/…`, which resolves to nothing on a
> skillshare-managed install. If you can't find the template, **say so rather than
> improvising** — the profile's field names are what every other skill reads.

Fill every field from the interview: identity, locations, stack & layout, build/verify
gate, dispatch mode + model, composition roots, domain invariants, locked decisions,
and delivery/merge policy. Where a value isn't known yet, leave the template's
placeholder and note it — don't invent a build command that doesn't exist.

**Also record how an external integration gets verified** — and if there is none yet,
say that explicitly rather than omitting it. Once the project does talk to a real
provider/API, this is where `backlog-coordinator` looks for:
- the **full** live-suite command;
- a **targeted** one (a single test or area). This is what makes per-request live
  verification cheap enough to run *before* closing rather than after merging — a
  project with only a slow full sweep reliably defers it, and half-closed requests
  accumulate;
- whether dispatched agents get live credentials, and if not, why not.

Create `docs/backlog/BACKLOG.md` from the index-table snippet at the bottom of the same
skill's `assets/request-template.md` (header + empty table).

### 4b. Write the test profile
`test-intake` and `test-run` read **`docs/testing/PROJECT.md`**, and `test-run` requires
it. This skill used to scaffold neither, so a freshly set-up project could not run its
own test skills until someone hand-wrote the profile — and nothing said that anywhere.

Create `docs/testing/PROJECT.md` from `assets/test-profile-template.md` in the sibling
**`test-intake`** skill (same resolution caveat as step 4 — find it next to this
skill's directory, don't hardcode a path), plus `docs/testing/CATALOG.md` with an empty
index table. `test-intake` can also scaffold the profile later on demand, so this step
is about not leaving a new project in a state where `test-run` simply stops.

Keep it short; a stub is fine, but it must exist and must name:

- **Catalog dir** and a pointer back to `docs/backlog/PROJECT.md`.
- **Tier → execution mapping** — which checks are plain scripts (no model call) and
  which need AI grading, at which model tier. Keeping inference spend deliberate is the
  point of the split.
- **Test fixtures** — where throwaway accounts/data live, how to reset them, and which
  identity is the designated target. **Record this in one committed place and derive
  everything else from it.** Fixture identity duplicated across a profile, an env file
  and scattered request notes will drift, and the copies disagreeing is not detectable
  by anything — a real incident, with a destructive test aimed at the wrong account.
- **Ownership** — whether a bug in a *test artifact* is fixed directly or has to go
  through the product backlog. Routing a one-line harness fix through request authoring
  and WP dispatch adds latency for no safety benefit, but the line has to be drawn
  explicitly or everything drifts to one side.
- **When the suite runs** — on demand, pre-deploy, in CI. If it touches real external
  services it generally should not be in the green gate.

### 5. Source skeleton (light)
Lay down a minimal, runnable skeleton appropriate to the stack and target type — just
enough that the green gate has something to run (e.g. a manifest, one entry-point
file, one passing test). Don't build the product; that's the backlog's job. Record the
real install + gate commands into `PROJECT.md` once they exist.

### 6. Initialize git
- `git init` (if not already a repo).
- Write `.gitignore` (stack entries + the snippet, which excludes `.worktrees/`,
  build output, deps, env files). The coordinator also relies on `.worktrees/` being
  ignored — belt-and-suspenders, add it to `.git/info/exclude` too.
- Stage and make the initial commit (e.g. `chore: scaffold project for Claude +
  opencode workflow`). Use the user's commit-footer convention if they have one.
- Only create a remote / push if the user explicitly asks.

### 7. Confirm & hand off
Tell the user, concisely:
- The tree you created (and anything left as a stub / placeholder).
- That `request-intake` and `backlog-coordinator` are ready to use here because
  `docs/backlog/PROJECT.md` exists — and what to run first ("log your first request
  with request-intake, then build it with backlog-coordinator").
- Any follow-ups: install opencode if it was missing, fill the build/gate command in
  `PROJECT.md` once the stack is real, flesh out the doc stubs.

## Boundaries
- **New projects only.** If the directory already holds a project, confirm before
  touching anything; never overwrite existing files silently.
- **Don't build the product.** Scaffold and contract only — feature work goes through
  the backlog skills.
- **Don't invent facts.** If a build command, model, or layout isn't decided, leave a
  clearly-marked placeholder rather than a plausible-looking lie.
- **No remote/push** unless the user asks.
