<!--
Thin agent-orientation file. Write the SAME content to BOTH:
  - AGENTS.md   (read by opencode)
  - CLAUDE.md   (read by Claude Code)
so the two toolchains operate from one contract. Keep it short — it points at the
docs; it does not duplicate them.
-->

# <PROJECT NAME> — agent guide

This project is built with a **Claude + opencode** multi-agent workflow. Before doing
anything substantial, read the contract:

- **`docs/HANDOFF.md`** — architecture, current status, tech stack & layout (§3),
  **locked decisions you must not relitigate (§4)**, **mandatory repo conventions
  (§5)**, and the **agent-dispatch workflow (§6)**. This is authoritative.
- **`docs/backlog/PROJECT.md`** — the project profile: build/verify (green-gate)
  command, dispatch mode + model, coordinator-owned composition roots, domain
  invariants, and the delivery/merge policy.
- **`docs/backlog/`** — the request backlog (`REQ-*.md` + `BACKLOG.md`).

## Working agreements
- **Stay in your scope.** A work package owns a disjoint set of files. The composition
  roots named in HANDOFF §3 are wired by the coordinator during integration, not by
  per-WP agents.
- **Commit locally; do not push or open a PR** when running as a dispatched WP agent —
  integration and delivery are the coordinator's job (PROJECT.md delivery policy).
- **Add unit tests** for new logic and keep the green gate passing
  (`PROJECT.md` → Build & verify).
- **Respect locked decisions** (HANDOFF §4). Don't relitigate them.

## The skills
- Report a bug or request a feature → **request-intake** skill (writes a
  `docs/backlog/REQ-*.md`).
- Prioritize, build, and ship from the backlog → **backlog-coordinator** skill.
