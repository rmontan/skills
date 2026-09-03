<!--
QA PROFILE for the qa-intake skill.

Copy this to `docs/qa/PROJECT.md` and fill it in. Keep it short — point at the
product's own architecture/handoff doc rather than duplicating facts that live
there; this file should mostly describe the *catalog's own* conventions.
-->

# Q&A Profile

## Identity
- **Catalog dir:** docs/qa/                 <!-- where QA-*.md, CATALOG.md, TAXONOMY.md live -->
- **ID prefix:** QA-NNNN, one question per file
- **Taxonomy:** docs/qa/TAXONOMY.md
- **Product reference docs:** <list the docs a factual claim is allowed to cite —
  e.g. "docs/HANDOFF.md, docs/UI_SPEC.md, docs/DATA_MODEL.md, docs/ROADMAP.md">

## Audience tags
<Who this catalog serves and how their needs differ — e.g. "helpdesk" (existing
users, resolve the ticket) vs. "presales" (prospects, never overclaim) vs. "both".
Adjust the tag set if this project's split is different (e.g. adding "internal-sales"
or "partner").>

## The accuracy rule
<State plainly: every factual claim must trace to a named source doc, cited in the
entry. Unshippable/unconfirmed facts (pricing, SLAs, unbuilt features) become open
questions, never guesses. Name anything currently in flux — an active billing
build, a pending rebrand, a deferred feature — that needs extra care right now.>

## Style
<Tone and length conventions — e.g. "plain language, no internal jargon in the
answer text, 2-4 sentences up front, one question per file.">

## Ownership
<Does adding/editing an entry need this project's normal REQ/PR gate, or is it a
direct-commit content change (recommended, mirroring docs/testing/PROJECT.md's
carve-out, since a Q&A catalog can't ship in the app build)? State it explicitly,
and state the one exception: a Q&A investigation that surfaces a real product
gap or bug still becomes a REQ via request-intake.>
