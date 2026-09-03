---
name: qa-intake
description: >-
  Turn a customer question into a registered, consistently-written entry in the
  project's Q&A catalog for helpdesk and presales (docs/qa/) — classify its
  category against the taxonomy, tag its audience, ground every factual claim in
  the project's own docs, and write it in one consistent voice. Use this when the
  user wants to "add a Q&A", "write an FAQ entry", "answer this for support",
  "write a presales answer", "add this to the knowledge base", or reports a
  question customers keep asking. Extend the taxonomy (docs/qa/TAXONOMY.md) when
  a question doesn't fit an existing category rather than forcing a fit. This is
  content authoring, not a product or test change — no REQ needed to add one.
---
# Q&A Intake

You are the front door for the project's **customer-facing Q&A catalog** — a
knowledge base for helpdesk and presales (`docs/qa/`), separate from both the
product backlog (`docs/backlog/`) and the test catalog (`docs/testing/`). Your
job: take a question, ground its answer in the product's own documentation,
classify it, write it in a consistent voice, and register it so anyone
answering that question later reaches for the same, current, accurate text
instead of improvising.

**Why this is a separate catalog:** a REQ describes a one-time change to ship; a
TEST entry describes a standing check to re-run; a QA entry describes a
standing *answer* to give a customer. None of the three is the others. The one
place QA touches the backlog: if writing an answer surfaces a real product gap
or a doc/behavior mismatch, that becomes a REQ via `request-intake` — this
skill never edits application code or claims a gap is closed just by writing
an FAQ entry around it.

## Q&A profile (read first)

Read **`docs/qa/PROJECT.md`** if it exists — it names the catalog location, the
audience tags this project uses, the list of docs a factual claim is allowed to
cite, style conventions, and the ownership/commit policy.

If it doesn't exist, offer to scaffold one from `assets/qa-profile-template.md`
(and a starter `docs/qa/TAXONOMY.md` from `assets/taxonomy-template.md`, built
from that project's *own* product docs — never copied from another project),
then proceed conservatively: two audience tags (`helpdesk`, `presales`, plus
`both`), and refuse to state anything not traceable to a doc you can name.

## Workflow

### 1. Understand the question
Get the question as a customer would actually ask it, and who's asking it in
practice — a live support ticket, a presales objection, something the user
anticipates being asked. Don't over-abstract it into internal vocabulary yet;
that happens in step 4.

### 2. Tag the audience
`helpdesk` (existing user, resolve the situation) / `presales` (prospect
deciding whether to buy, never overclaim) / `both` (the underlying fact doesn't
change by audience). Use whatever tag set the project's profile defines if it
differs from these three.

### 3. Classify against the taxonomy — extend it before forcing a fit
Read `docs/qa/TAXONOMY.md`. If an existing category fits, use it. If none does,
**add a category (or a subtopic to an existing one) to TAXONOMY.md first**, in
the same shape as the existing entries, citing which product doc justifies it
if that isn't obvious — then file the new entry under it. A taxonomy that
silently drifts out of sync with what's actually filed defeats the point of
having one.

### 4. Ground the answer — invent nothing
This is the step that matters most. For every factual claim in the draft
answer:
- Find the specific doc + section that supports it (the project's architecture/
  handoff doc, its UI spec, its data model doc, its roadmap, its backlog — per
  the profile's list). Cite it in the entry's `sources:` field.
- If you can't find support for a claim — an unshipped feature, an exact price,
  an SLA, a retention window — **do not state it as fact.** Either omit it, or
  write it explicitly as an "if asked, escalate" note rather than a guessed
  answer. A wrong or overclaimed answer to a near-paying customer is worse than
  no answer.
- Never restate a locked/architectural decision in a way that contradicts it,
  and never answer as though a deferred or in-flight feature (check the
  backlog for anything actively being built) already fully shipped.
- Translate internal vocabulary into plain language for the answer text itself
  (jargon is fine in **Notes**, never in **Answer**).

If grounding the answer turns up a real discrepancy — the docs say X but you
know the app does Y, or customers keep hitting a gap nothing covers — stop and
hand that off to `request-intake` as its own REQ. Don't paper over a real
product problem with a well-written FAQ entry.

### 5. Write the answer in the profile's style
Default shape (mirror the profile if it says otherwise): a direct 2–4 sentence
answer first, an optional **Say more if** follow-up script for a live agent,
and internal **Notes** for whoever re-verifies this entry later. One question
per file — split a bundled question into separate entries.

### 6. Register the catalog entry
No `mkdir`-lock/reserve-script machinery here, unlike `request-intake`'s
backlog or `test-intake`'s test catalog — those are written under
parallel-agent dispatch, where two sessions race hard enough to need a
dedicated ID-reservation counter. Q&A authoring doesn't run that way. Have the
full entry text ready, then do the write itself as a single flock-guarded
append so two concurrent qa-intake runs simply queue instead of colliding:

1. Scan `docs/qa/*.md` for the highest existing `QA-NNNN` — fine to do this
   without a lock, it's just what decides your candidate number.
2. Write `docs/qa/QA-<NNNN>-<short-kebab-slug>.md` from
   `assets/qa-item-template.md` with the drafted content (a new file at a
   number nobody else has written can't collide).
3. Append the one-line index row to `docs/qa/CATALOG.md` under an `flock` on
   that file, so a second run waits for the first instead of interleaving
   writes: `flock docs/qa/CATALOG.md -c 'printf "%s\n" "<row>" >>
   docs/qa/CATALOG.md'` (create the file from the template's index snippet
   first if it doesn't exist yet — that first-creation isn't itself
   lock-protected, but is a one-time event per project).
4. **If this is a git repository:** commit the new QA file and the
   `CATALOG.md` change together — `git add docs/qa/QA-<NNNN>-*.md
   docs/qa/CATALOG.md && git commit -m "qa: file QA-<NNNN> — <short
   question>"` (match the project's own commit-message convention if one is
   documented). Stage only those two paths, never `-A`/`git add .`. If this
   isn't a git repo, skip silently.
5. **Deliver with a direct push to `main` — no branch, no PR, no CI**, unless
   the project's own `docs/qa/PROJECT.md` says otherwise. A Q&A entry is a
   `.md` file nothing in the build reads; the branch/PR/CI cycle
   `request-intake`/`test-intake` use exists to gate *code* changes, and
   applying it here is pure ceremony with no matching safety benefit. Do:
   `git fetch origin main && git rebase origin/main` (only if you weren't
   already at its tip) `&& git push origin HEAD:main`. This is a plain
   fast-forward push, never `--force`: if it's rejected because `main` moved
   since your fetch, that's an ordinary push race — fetch again, rebase, and
   retry, the same as any other push, rather than forcing over someone else's
   commit.

Set `status: active` once you're confident the answer is accurate and complete
enough to use as-is; use `draft` if it still needs review (e.g. a claim you
couldn't fully verify) before someone relies on it with a customer.

### 7. Confirm
Tell the user: the QA id, its category and audience tag, the file path, and
which sources back the answer. If you flagged anything as an open question
instead of answering it outright, say so plainly. If you filed a companion REQ
(step 4), name it. In a git repo, confirm the entry is pushed to `main`.

## Boundaries
- **Never invent a fact.** If it's not traceable to a named doc, it's an open
  question, not an answer — this is the one rule that makes the whole catalog
  trustworthy enough for presales to use unreviewed.
- **Never edit application code**, and never let a well-written answer stand in
  for fixing a real gap it surfaces — that's `request-intake`'s job.
- **Don't duplicate.** Scan `docs/qa/CATALOG.md` for a close match before
  writing a new entry; extend or correct the existing one instead.
- **Don't let the taxonomy rot.** A new topic gets a home in
  `docs/qa/TAXONOMY.md` before (or exactly when) it gets its first entry, not
  after several entries have already accumulated without one.
- One question per file, same discipline as one request per REQ / one check per
  TEST.
