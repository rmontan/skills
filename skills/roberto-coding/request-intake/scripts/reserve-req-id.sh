#!/usr/bin/env bash
# Reserve the next REQ-NNNN number, safely across every worktree of this clone.
#
# The counter lives under the shared .git directory (git-common-dir), not inside
# any single worktree's files — every `.worktrees/<wp>` checkout of the same clone
# already shares that directory, so this closes the race two sibling worktrees hit
# when they each derive "highest REQ + 1" from their own local backlog/ scan and
# land on the same number. flock makes the read-increment-write atomic; the
# conflict window is however long the lock is held (sub-second), not however long
# a session takes to write and commit its REQ file.
#
# Does NOT cover two genuinely separate clones (e.g. different machines) reserving
# concurrently — that residual race is accepted as out of scope for now.
#
# The stored counter is cross-checked against this worktree's own backlog/ directory
# on every call, not just at bootstrap (see the "sanity check" comment below) — a
# stale counter has handed out an already-used number in practice (2026-08-26): it
# sat at 336 while REQ-0336..REQ-0340 already existed on disk, because something
# created those REQs without going through this script and nothing since had
# re-validated the counter against reality.
#
# Usage: reserve-req-id.sh [backlog-dir]   (default: docs/backlog)
# Prints the reserved number, unpadded, on stdout. Nothing else goes to stdout.
set -euo pipefail

backlog_dir="${1:-docs/backlog}"

# Highest REQ-NNNN this worktree's own backlog/ directory has on disk. Cheap
# (no network), but only sees what this worktree has checked out — that's fine
# for the sanity check below (the shared counter is still the primary source of
# truth), and it's the only option when there's no git repo to share a counter
# through at all.
highest_local() {
  local highest=0
  while read -r n; do
    (( 10#$n > highest )) && highest="$((10#$n))"
  done < <(find "$backlog_dir" -maxdepth 1 -name 'REQ-*.md' 2>/dev/null \
    | grep -oP 'REQ-\K[0-9]+' || true)
  printf '%s\n' "$highest"
}

if ! git_common="$(git rev-parse --git-common-dir 2>/dev/null)"; then
  # Not a git repo: no shared location to coordinate through, so there's no
  # cross-worktree race to guard against either. Fall back to a plain scan.
  printf '%s\n' "$(( $(highest_local) + 1 ))"
  exit 0
fi

counter_file="$git_common/req-counter"
lock_file="$git_common/req-counter.lock"

exec 200>"$lock_file"
flock -w 10 200 || { echo "reserve-req-id: could not acquire lock within 10s" >&2; exit 1; }

if [[ -s "$counter_file" ]]; then
  next="$(<"$counter_file")"
  # Sanity check: the counter is only ever incremented by this script, so it can
  # go stale relative to the actual backlog if a REQ is ever created some other
  # way (by hand, a counter reset, a pre-script file) without the counter moving
  # to match. Take whichever is higher rather than trusting the stored value
  # blindly — costs one cheap local scan per call, and is a no-op when the
  # counter is already healthy.
  local_next=$(( $(highest_local) + 1 ))
  (( local_next > next )) && next="$local_next"
else
  # Bootstrap: seed from the highest REQ-NNNN this clone knows about. Prefer
  # origin/main (the shared, merged view) over a local scan, which only sees
  # whatever this worktree happens to have checked out.
  highest=0
  if git remote get-url origin >/dev/null 2>&1 && git fetch origin main --quiet 2>/dev/null; then
    while read -r n; do
      (( 10#$n > highest )) && highest="$((10#$n))"
    done < <(git ls-tree -r --name-only origin/main -- "$backlog_dir" 2>/dev/null \
      | grep -oP 'REQ-\K[0-9]+' || true)
  fi
  if (( highest == 0 )); then
    highest="$(highest_local)"
  fi
  next=$((highest + 1))
fi

printf '%s\n' "$((next + 1))" > "$counter_file"
printf '%s\n' "$next"
