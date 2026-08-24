<!--
TEST PROFILE for the test-intake + test-run skills.

Copy this to `docs/testing/PROJECT.md` and fill it in. Keep it short — it points at
the product's own `docs/backlog/PROJECT.md` rather than duplicating stack/build
details that already live there.
-->

# Test Profile

## Identity
- **Catalog dir:** docs/testing/            <!-- where TEST-*.md and CATALOG.md live -->
- **Product backlog profile:** docs/backlog/PROJECT.md   <!-- where failures get filed -->

## Tier → execution mapping
- **deterministic:** <how a check is run — e.g. "a Go test under //go:build e2e /
  live, or a shell script; run directly, no model call">
- **ai-cheap:** <which model to dispatch for this tier, e.g. "haiku">
- **ai-strong:** <which model to dispatch for this tier, e.g. "opus" or "sonnet">

## Test fixtures / throwaway accounts
<Which accounts, users, or datasets are safe to read/write/reset for testing purposes,
and how to reset them. e.g. "tvcasaetna@gmail.com (Google) + cs_test999@outlook.com
(Microsoft), linked under app user <uuid>. Synthetic data only — freely modifiable,
deletable, and reimportable via scripts/synth-accounts.sh (see docs/E2E_TESTING.md).
Never point a check at a real user's account or data.">

## Evidence capture for AI-graded checks
<How a check gathers what the grader will see — e.g. "screenshots via the `run` skill
against the dev server; API payloads captured as raw JSON; log excerpts via
<command>". Point at an existing mechanism rather than letting each check invent one.>

## When this suite runs
<e.g. "owner-run via test-run before a production deploy; not part of make gate or
CI" — or however this project wants it triggered.>
