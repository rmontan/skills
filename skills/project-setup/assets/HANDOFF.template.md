<!--
HANDOFF template. Copy to docs/HANDOFF.md and fill in from the setup interview.
This is THE shared contract: both CLAUDE.md and AGENTS.md point here, and the
backlog-coordinator + request-intake skills read it (and reference its section
numbers). Keep the numbering stable.
-->

# Project Handoff — <PROJECT NAME>

The single source of truth for how this project is built and operated. Both Claude
Code (`CLAUDE.md`) and opencode (`AGENTS.md`) defer to this file. Keep it current.

## 1. What this is
<2–4 sentences: what the product does and for whom (the "why"). From the spec
interview.>

## 2. Current status
<Where the project is right now, e.g. "freshly scaffolded — skeleton only, no
features yet". Update as it evolves.>

## 3. Tech stack & layout
- **Language / runtime:** <e.g. TypeScript / Node 20>
- **Package manager:** <e.g. pnpm>
- **Layout:** <single package, or monorepo packages: apps/api, apps/web, ...>
- **Datastore / migrations:** <if any — dir + rule, e.g. additive-only>
- **Entry points / composition roots:** <files that wire everything together; these
  are coordinator-owned during the backlog workflow>

## 4. Architectural decisions (locked — do not relitigate)
<Decisions already settled. A request contradicting one is wontfix unless the user
overrides. Examples:>
- <e.g. secrets are encrypted at rest>
- <e.g. SPA and API share an origin; no /api prefix>
- (none yet — add as decisions are made)

## 5. Repo conventions — MANDATORY
- **Branching / commits:** <e.g. feature branches; commit footer convention>
- **Tests:** <where tests live; the green gate command — see PROJECT.md>
- **Schema/migrations:** <rule, e.g. additive-only, one per parallel wave>
- **Ownership:** each work package owns a disjoint set of files; composition roots
  (§3) are coordinator-owned and wired during integration, not by per-WP agents.
- **Worktrees:** parallel agents run in `.worktrees/<wp>` (gitignored); never share a
  working directory.

## 6. Dispatching coding agents (current workflow)
Work packages are dispatched per `docs/backlog/PROJECT.md` (dispatch mode + model).
Default pattern (opencode):
```bash
# run from inside the WP's worktree; agent commits locally (does NOT push/PR).
opencode run "<work-package prompt>" -m <model> --dangerously-skip-permissions
```
The coordinator verifies (green gate + trial merge), wires the composition roots,
integration-tests, then follows the delivery policy in PROJECT.md.

## 7. Next steps (what to pick up next)
<The immediate to-dos. Right after scaffolding this is usually: decide/lock the stack,
fill the real build + gate commands in PROJECT.md, log the first requests via the
request-intake skill.>

## 8. Known caveats / gotchas
<Anything surprising. Empty to start.>

## 9. How to run
<Install + run + test commands once they exist. Mirror the gate into PROJECT.md.>
