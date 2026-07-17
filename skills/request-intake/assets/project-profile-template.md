<!--
PROJECT PROFILE for the request-intake + backlog-coordinator skills.

Copy this to `docs/backlog/PROJECT.md` and fill it in. Both skills read this file
to adapt their generic workflow to this repo: vocabulary for intake, and build /
dispatch / verify / merge mechanics for the coordinator. Anything you leave blank
falls back to the skill's defaults (or is inferred from the repo).

Keep it short. For deep architecture, point at the handoff/architecture doc rather
than duplicating it here.
-->

# Project Profile

## Identity
- **Product name:** <e.g. "Acme Widget API">
- **Short description:** <one line>

## Locations
- **Backlog dir:** docs/backlog/            <!-- where REQ-*.md and BACKLOG.md live -->
- **Architecture / handoff doc(s):** <e.g. docs/HANDOFF.md, docs/ARCHITECTURE.md>
- **Work-package style guide:** <e.g. docs/WORK_PACKAGES.md, or "none — see below">
- **Integration / e2e / smoke docs:** <e.g. docs/INTEGRATION.md, docs/E2E_TESTING.md, docs/SMOKE.md>

## Stack & layout
- **Package manager / runtime:** <e.g. pnpm workspace / Node, uv / Python>
- **Package layout:** <e.g. apps/api, apps/web, workers, packages/shared>
- **Migrations:** <dir + rule, e.g. "apps/api/src/db, additive-only, one per wave">

## Build & verify (the "green gate")
- **Install:** <e.g. pnpm install>
- **Gate command:** <e.g. pnpm -r typecheck && pnpm -r test && pnpm -r build>
- **Baseline test counts (optional):** <e.g. api 278 + workers 524>

## Dispatch (how the coordinator delegates a work package)
- **Mode:** <one of: opencode CLI | Claude subagents (Agent tool) | manual/by hand>
- **Command / model (if a CLI):** <e.g. opencode run "<prompt>" -m opencode-go/minimax-m3 --dangerously-skip-permissions>
- **Coordinator-owned composition roots:** <files only the coordinator edits when wiring, e.g. workers/src/index.ts, apps/api/src/server.ts>

## Domain invariants to verify (and to flag at intake)
<!-- The non-negotiables a change must not break, and the sensitive-data angles
     intake should call out. Examples: -->
- <e.g. write-back idempotency — re-runs UPDATE, never duplicate>
- <e.g. encryption round-trips; no secrets in logs/exports>
- <e.g. free-tier limit still enforced>
- <e.g. PII + OAuth tokens at rest — always flag security/privacy impact>

## Locked decisions (do not relitigate)
<!-- Decisions the owner has settled. A request contradicting one is wontfix
     (coordinator) / an Open Question (intake) unless the user overrides. -->
- <e.g. tokens are always encrypted at rest>
- <e.g. SPA and API share an origin; routes live at root, no /api prefix>

## Delivery / merge policy
- **Operating mode:** <one of: autonomous through merge | open PR, pause for human merge | local commits only, never push>
- **CI workflow:** <e.g. .github/workflows/ci.yml>
- **Commit footer:** <e.g. Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>>
- **PR body footer:** <e.g. the Claude Code footer>
