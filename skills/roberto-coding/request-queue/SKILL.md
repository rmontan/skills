---
name: request-queue
description: >-
  Quickly save a bug report or feature request (and any screenshots) to the
  backlog inbox, for request-intake to turn into a proper REQ entry later. Use
  this when the user wants to jot something down fast without stopping for
  clarifying questions — "queue this", "add to the inbox", "quick one for the
  backlog", "save this for later", or when they paste a description and/or a
  screenshot and just want it captured. This skill does exactly one thing:
  write the raw report to the backlog inbox. It does NOT classify bug vs.
  feature, ask questions, assign an ID, or write a REQ-*.md file — that's
  request-intake's job when it drains the queue.
---

# Request Queue

You are a drop box, not an interviewer. Take whatever the user gives you — a
description, a screenshot, both — and save it verbatim to the backlog inbox as fast
as possible. Do not classify it, do not ask clarifying questions, do not decide
priority, do not write a `REQ-*.md` file. All of that is `request-intake`'s job when
it later drains the queue. Your entire job is: capture faithfully, save, confirm, done.

If you find yourself wanting to ask a question to make the report "actionable" —
don't. That's precisely the work this skill exists to defer. Save what you were
given, gaps and all.

## Find the backlog location

Look for `docs/backlog/PROJECT.md` and read only enough to find the backlog
directory (default `docs/backlog/`). If there's no `PROJECT.md`, use `docs/backlog/`
if it exists, or ask the user once where requests are tracked in this repo. Don't
read the rest of the project profile (domain invariants, locked decisions, etc.) —
that's request-intake's concern, not yours.

The inbox lives at `<backlog>/inbox/`. Create it if it doesn't exist.

## Workflow

### 1. Capture verbatim
Take the user's description exactly as given. Don't summarize, rewrite, classify as
bug/feature, or fill gaps. If they only give you a screenshot with no words, that's a
valid queue entry — save it as-is; request-intake can ask what it means when it
processes the item.

### 2. Save any screenshots/attachments
If the user attached or pasted an image (or points you at a local file path), copy it
into `<backlog>/inbox/` next to the entry, named `<same-slug>-1.<ext>`,
`<same-slug>-2.<ext>`, etc. for multiple images. Don't crop, annotate, or otherwise
modify it.

### 3. Write the queue entry
- Build a slug from the first few words of the description (kebab-case, ~5 words).
- Filename: `<backlog>/inbox/<YYYYMMDD-HHMMSS>-<slug>.md`, using the current local
  timestamp. This ordering is what lets request-intake process items oldest-first
  without needing an ID scheme of its own.
- Content — frontmatter plus the raw text, nothing else:

  ```markdown
  ---
  queued: <YYYY-MM-DD HH:MM>
  reporter: <user's email if known, else unknown>
  attachments: [<relative filenames of any saved images, or omit if none>]
  ---

  <the user's description, verbatim>
  ```

  See `assets/queue-entry-template.md` for the exact shape.

### 4. Confirm — one line
Tell the user the file was queued and where (clickable path). Nothing else: no
classification, no "here's what I'd ask next," no priority guess. If they want it
processed into a full request right now instead of later, say so and point them at
`request-intake` — but only if they ask; don't offer it unprompted.

## Boundaries
- **Never** classify bug vs. feature, ask clarifying questions, assign a `REQ` ID, set
  priority, or touch `<backlog>/BACKLOG.md`. That's `request-intake`'s job when it
  drains this queue.
- **Never** write a `REQ-*.md` file. This skill only ever writes into
  `<backlog>/inbox/`.
- One report per queue file. If the user dumps several unrelated issues in one
  message, split them into separate queue entries — same rule request-intake applies
  downstream, kept consistent so nothing has to be re-split later.
- If the description is already fully detailed and the user explicitly asks to file
  it *now* (not "later," not "queue it"), that's `request-intake`'s workflow, not
  this one — hand off instead of doing intake's job here.
