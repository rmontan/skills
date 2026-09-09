---
name: website-update
description: >-
  Make a change to one of ContactZapp's marketing-site repositories
  (web-contact-sync or web-contact-sync-dev2) from a contact_sync2 session,
  following THAT repo's own conventions rather than contact_sync2's. Use this
  when the user asks to "update the website", "change the marketing site",
  "update dev2", "update the coming-soon page", wants the website to reflect
  an app-side change (a new plan, a URL, an env var/feature flag like
  FREEMIUS_SANDBOX), or asks which directory/branch backs a given
  *.contactz.app hostname. Does NOT apply to changes inside contact_sync2
  itself — this skill exists specifically for the cross-repo boundary.
---

# Website Update

ContactZapp has two codebases that both answer to `*.contactz.app`: the product
application (`contact_sync2`, this repo) and the marketing site (a separate GitHub
repo, checked out as two worktrees). This skill is the map between the two, and the
discipline for touching the marketing-site worktrees safely from here — it does not
carry contact_sync2's own conventions across that boundary, on purpose.

## Site map (read this first — it can drift, verify if unsure)

| Hostname | Directory | Branch | Purpose | Reaches Cloudflare? |
|---|---|---|---|---|
| `contactz.app` | `~/code/web-contact-sync` | `main` | **Production.** The live "coming soon" splash page today. Becomes the full marketing site once `dev2` merges into `main` — see "The dev2 cutover" below. | Yes — the only branch `.github/workflows/deploy.yml` deploys |
| `dev.contactz.app` | `~/code/web-contact-sync` | `dev` | Local-only staging for `main`'s splash page. `wrangler pages dev`, systemd `web-contact-sync-dev.service` on mnt1. | No |
| `dev2.contactz.app` | `~/code/web-contact-sync-dev2` (a separate worktree — own `node_modules`, own local D1 state) | `dev2` | Local-only staging for the **future** full marketing site, including the Freemius checkout integration. Not live yet. Merges into `main` when ready, replacing the coming-soon splash. `wrangler pages dev`, systemd `web-contact-sync-dev2.service` on mnt1. | No |
| `devapp.contactz.app` | `~/code/contact_sync2` (this repo) | `main` | The product application itself (not the marketing site) — internal test deployment, Docker on mnt1. | No |
| `app.contactz.app` (future) | `~/code/contact_sync2` (this repo) | not built yet | Planned production deployment of the product application. | No |

`web-contact-sync` and `web-contact-sync-dev2` are two worktrees of the **same**
private GitHub repo (`rmontan/web-contact-sync`), not two different repos — they
share one `.git` and history, just checked out on different branches
(`dev`/`main` vs `dev2`). Confirm with `git -C <dir> remote -v` and
`git -C <dir> branch --show-current` if this table looks stale.

## The dev2 cutover — not this skill's job

`dev2` is deliberately built out separately from `main` so today's live splash page
keeps working undisturbed while the full site is built. When it's ready, the owner's
own documented workflow (in that repo's README) is: `git checkout main && git merge
dev2 && git push` — the same `main` → GitHub Actions → Cloudflare pipeline, no CI
changes needed. **Never perform that cutover as a side effect of an unrelated
change** — merging `dev2` into `main` is a production-deploy decision for the repo
owner to make explicitly, not something to bundle into a smaller task.

## Core rule: follow the target repo's OWN conventions, not this one's

`contact_sync2/CLAUDE.md` says this repo is self-contained and must not import
decisions from another codebase — the same boundary applies in reverse when working
in the website repo from here:

- **No REQ, no backlog.** Neither website worktree has a `docs/backlog/` — they work
  from `AGENTS.md` and direct commits. Don't write a `REQ-*.md` for a website-only
  change, and don't expect `backlog-coordinator`'s WP/PR/CI process to apply there.
- **Read that worktree's own `AGENTS.md`/`README.md` first, every time.** `dev2` is
  mid-build and can diverge from `dev`/`main`'s conventions even though they share a
  repo.
- **`cd` into the actual target directory and treat it as its own project** for the
  duration of the task. Don't simulate its logic inside `contact_sync2`, and don't
  port contact_sync2 code/patterns over verbatim just because they solved a similar
  problem — adapt to that repo's actual stack (Next.js static export + Cloudflare
  Pages Functions, not Go; see its own comment style and follow it).
- **`main` is the only branch that reaches Cloudflare production** for the website
  repo (`.github/workflows/deploy.yml`). Treat anything destined for `main` there
  with the same caution as any other production deploy — confirm before
  merging/pushing to it. `dev`/`dev2` are local-only and lower-risk, but there is no
  standing push/merge authorization for this repo the way there is for
  `contact_sync2` — confirm before pushing if the task didn't already ask for it
  explicitly.
- **Cross-repo integration facts live in `contact_sync2/docs/FREEMIUS.md`** — the one
  doc both sides already point to (see its §4 "Checkout", §7 "Env vars", §8 "Open /
  not yet decided"). If a website-side change resolves or changes one of its open
  items (e.g. §8.4, "Sandbox → live cutover hasn't happened"), update that doc's own
  line from within `contact_sync2` as a normal doc edit, so the fact lives in one
  place instead of being rediscovered later. Don't duplicate its content into the
  website repo.

## Workflow

1. **Identify the target** from the site map above (hostname → directory → branch).
2. **Read that repo's own `AGENTS.md`, `README.md`, and any `wrangler.toml`/env
   files** relevant to the change — it moves independently of `contact_sync2`, so
   don't rely on a prior session's understanding of it.
3. **Make the change inside that repo's own worktree**, matching its stack and
   existing code/comment style.
4. **Verify with that repo's own tooling** (e.g. `pnpm build` for the static Next
   export; its own dev server or systemd service for a live check) — `make gate` and
   the rest of `contact_sync2`'s green gate do not apply there.
5. **Commit inside that repo**, in its own commit-message style. Don't push to a
   shared branch (especially `main`), and don't restart a systemd service backing a
   currently-relied-upon environment, without confirming first — unless the task
   already authorized it explicitly.
6. **Report back which repo/branch/files changed**, and whether the commit is
   local-only or pushed. Don't assume `contact_sync2`'s standing merge authorization
   carries over to this repo — it doesn't.

## When NOT to use this skill

- A change entirely inside `contact_sync2` — just do the work directly, or via
  `request-intake`/`backlog-coordinator` per `CLAUDE.md`.
- A product decision about what the marketing site or app *should* say or do — that's
  the user's call, not something this skill's site map can answer.
