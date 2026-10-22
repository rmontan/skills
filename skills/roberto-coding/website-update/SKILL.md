---
name: website-update
description: >-
  Make a change to ContactZapp's marketing-site repository (web-contact-sync)
  from a contact_sync2 session, following THAT repo's own conventions rather
  than contact_sync2's. Use this when the user asks to "update the website",
  "change the marketing site", "add a blog post", wants the website to reflect
  an app-side change (a new plan, a URL, an env var/feature flag like
  FREEMIUS_SANDBOX), or asks which checkout/branch backs a given
  *.contactz.app hostname. Does NOT apply to changes inside contact_sync2
  itself — this skill exists specifically for the cross-repo boundary.
---

# Website Update

The marketing site is a separate private GitHub repo (`rmontan/web-contact-sync`),
not part of `contact_sync2`. Its conventions are its own; don't carry
`contact_sync2`'s across.

## Where things are — read, don't copy

The checkouts live in `../contactzapp_web` (relative to the `code/` folder that
holds `contact_sync2`). Which checkout is which branch, hostnames, ports, deploys
and how to see a change: `../contactzapp_web/AGENTS.md` and
`../contactzapp_web/README.md`. Read both first, every time. If they disagree, the
README wins. Never restate their mapping here or in a commit or report; it goes
stale.

The site itself (structure, pages, Functions, Freemius, build-time env vars):
`README.md` in the checkout. Code: `ARCHITECTURE.md` there.

## Rules

- **Work on a branch off `dev`, open a PR into `dev`.** Never push to `main`, and
  never merge `dev` into `main`, unless Roberto says to publish. `main` is the
  production deploy.
- **Copy comes from Marketing.** Wording is approved in `Marketing/strategy/`
  (start at `messaging-blocks.md`; claims must be in `claim-verification.md`).
  Don't invent copy or claims from the app side.
- **Blog posts** follow `docs/blog/AUTHORING.md` in the repo. The build
  (`scripts/blog-check.mjs`) rejects what it forbids.
- **No REQ, no backlog.** The website repo has no `docs/backlog/`; don't write a
  `REQ-*.md` and don't expect `backlog-coordinator`'s process to apply.
- **Adding or removing a page** includes updating `src/lib/site-routes.json`
  (sitemap and IndexNow read it). Details in the repo README.
- **Cross-repo facts** (plans, checkout, env vars) live in
  `contact_sync2/docs/FREEMIUS.md`. Don't duplicate them into the website repo; if
  a website change settles one of its open items, update that doc from
  `contact_sync2`.

## Workflow

1. Read the two orientation files above, then the repo's `README.md`.
2. Create a branch off `dev` in the `dev` checkout.
3. Make the change in the site's own stack and style, and verify with its own
   tooling (`pnpm build`, the dev service). `make gate` does not apply.
4. Commit in the repo's own commit-message style, push the branch, open a PR into
   `dev`.
5. Report the repo, branch, files changed and the PR. Don't restart a systemd
   service others rely on without confirming.

## When NOT to use this skill

- A change entirely inside `contact_sync2`.
- A decision about what the site should say. That is Roberto's, via Marketing.
