---
name: claude-rc-setup
description: >-
  Use when the user asks to "set up claude rc", "install remote control",
  "reinstate/restart/fix the claude rc session", "make the claude rc session
  survive reboots/drops", or "respawn claude rc" on a remote server (mnt1,
  srv1, sandbox, or any other SSH-reachable Linux host). Installs Claude
  Code's Remote Control (`claude rc`) inside a crash- and reboot-resilient
  tmux + systemd wrapper, and covers safely respawning it later without
  silently killing in-flight background work.
license: MIT
metadata:
  version: 1.1.0
  category: infrastructure
  author: Roberto
---

# Claude RC Setup

Installs Claude Code's Remote Control feature (`claude rc` — lets you drive
a Claude Code session from claude.ai/code or the Claude mobile app) on a
remote Linux server, wrapped so it survives SSH drops, its own crashes, and
full reboots. Also covers how to respawn it safely later, since a naive
kill-and-restart can silently interrupt in-flight background work.

This was built from hands-on experience standing up `claude rc` on `mnt1`
for the `contact_sync2` project — including the failure modes actually hit
(tmux server dying with the last session, a live-migration attempt via
`reptyr` that's blocked by design, and background workers dying on restart
even though they looked independent).

## When to Use

Use this skill when the user:
- Asks to install / set up `claude rc` (Remote Control) on a server
- Reports the remote target is missing from claude.ai/code or the mobile app
  and the server-side session needs to be reinstated
- Wants the session hardened to survive SSH drops, crashes, or reboots
- Asks to "respawn" / restart a `claude rc` session that's already wrapped

Do NOT use this skill for:
- Setting up Claude Code itself (assumes `claude` CLI is already installed,
  in `$PATH`, and authenticated on the target host)
- General SSH/server conventions unrelated to `claude rc` — if the target is
  one of the home-lab hosts (srv1/mnt1/sandbox/nas), the **server-management**
  skill covers connection aliases, sudo conventions, and dangerous-operation
  confirmation rules; use both together

## Prerequisites

- SSH access to the target host, with a user that has (passwordless, on the
  home-lab hosts) sudo — needed for the systemd unit.
- `claude` CLI already installed and logged in on that host (`claude
  --version` should work over SSH).
- A project directory to run it in.

Confirm before starting:
```bash
ssh <host> "claude --version && which claude"
```

## Instructions

### Step 1: Check for an existing session first

Never assume a clean slate — a previous attempt may be half-alive.

```bash
ssh <host> "tmux ls 2>&1; ps aux | grep -E 'claude.*remote-control|claude rc' | grep -v grep"
```

- `tmux ls` failing with `no server running on ...` means any prior tmux
  wrapper died completely (this is the actual failure mode hit on mnt1: a
  standalone tmux server survived on borrowed time because of an unrelated
  second session, then vanished once that session also closed).
- A live `claude --resume ... --remote-control` process with **no** tmux
  session around it means someone (or the claude.ai web UI) restarted the
  session directly, bypassing tmux — this happens because the persistent
  `--serve`/`--bridge` daemon processes (parented by PID 1) can respawn the
  interactive process on their own, independent of any wrapper you set up.
  If so, this process is likely a direct child of the current SSH session
  and will die on the next drop — go to **Step 5 (Respawning)** to safely
  move it, rather than assuming Step 2's fresh install is safe to run over it.

### Step 2: Create the launch script

```bash
ssh <host> "cat > ~/launch_claude_rc.sh << 'EOF'
#!/usr/bin/env bash
cd <PROJECT_DIR> || exit 1
exec claude rc
EOF
chmod +x ~/launch_claude_rc.sh"
```

Replace `<PROJECT_DIR>` with the absolute path (e.g.
`/home/roberto/code/contact_sync2`). `exec` matters — it replaces the shell
so the tmux pane's process *is* `claude rc`, not a wrapping shell.

### Step 3: Create the idempotent tmux bootstrap script

This is what makes the setup safe to re-run (at boot, or by hand) without
duplicating sessions:

```bash
ssh <host> "cat > ~/start_claude_rc_tmux.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if tmux has-session -t claude-rc 2>/dev/null; then
  echo \"claude-rc tmux session already running\"
  exit 0
fi

tmux new-session -d -s claude-rc -c <PROJECT_DIR>
tmux set-option -t claude-rc remain-on-exit on
tmux send-keys -t claude-rc \"~/launch_claude_rc.sh\" Enter
EOF
chmod +x ~/start_claude_rc_tmux.sh"
```

`remain-on-exit on` is the load-bearing line: without it, if `claude rc`
crashes and this is the only window in the only session, tmux destroys the
window, then the session, then the **server itself** — leaving nothing to
reconnect to and no way to see what went wrong. With it, a crashed pane just
sits there dead-but-visible, and the session (and server) survive.

If setting up more than one project on the same host, use a distinct
session name per project (e.g. `claude-rc-<project>`) instead of the bare
`claude-rc` default, to avoid collisions.

### Step 4: Wire it into systemd for reboot survival

```bash
ssh <host> "sudo tee /etc/systemd/system/claude-rc.service > /dev/null << 'EOF'
[Unit]
Description=Claude Code Remote Control - tmux session bootstrap
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=<HOST_USER>
Group=<HOST_USER>
ExecStart=/home/<HOST_USER>/start_claude_rc_tmux.sh

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now claude-rc.service"
```

Replace `<HOST_USER>` with the SSH login user (e.g. `roberto`).
`Type=oneshot` + `RemainAfterExit=yes` is deliberate over `Type=forking`:
the bootstrap script's whole job is to fire-and-forget a `tmux new-session
-d`, and systemd doesn't need to track the daemonized tmux server's PID for
this to do its job — it only needs to *run once at boot*. Crash-survival
within a running session is already handled by `remain-on-exit` in Step 3,
not by systemd restarting anything.

### Step 5: Verify

```bash
ssh <host> "tmux capture-pane -t claude-rc -p -S -30"
```

Look for:
```
·✔︎· Ready · <project> · <branch>
    Capacity: 0/32 · New sessions will be created in the current directory

Code anywhere with the Claude mobile app or https://claude.ai/code?environment=env_...
```

That URL is what connects claude.ai/code or the mobile app to this session.

Also confirm the boot wiring:
```bash
ssh <host> "systemctl is-enabled claude-rc.service && systemctl is-active claude-rc.service"
ssh <host> "tmux show-options -t claude-rc remain-on-exit"
```

Expect `enabled`, `active`, and `remain-on-exit on`.

## What "robust" actually covers

| Failure mode | Covered by | How |
|---|---|---|
| SSH connection drops | tmux | Process is parented by the daemonized tmux server (PID 1), not the SSH session |
| `claude rc` process crashes | `remain-on-exit on` | Pane stays visible instead of tearing down the session/server |
| Host reboots | systemd unit | Re-runs the idempotent bootstrap script at boot |

Not automatic: a crashed pane does **not** auto-restart `claude rc` — see
Respawning below. This is intentional — auto-restarting on crash risks
masking a real problem in a restart loop; a visible dead pane is easier to
diagnose than a symptom that silently disappears.

## Known Trade-off: Every Restart Duplicates the Target Entry

Confirmed by watching `claude-rc.service` do its job after an actual mnt1
reboot: **every fresh `claude rc` launch — manual respawn or the automatic
systemd one after a reboot — mints a brand-new environment registration**
with Anthropic's backend, each with its own `env_...` ID and its own
`?environment=` connect URL. There is no local cache of a prior environment
ID to resume, and `claude remote-control --help` has no
`--environment-id`/resume-style flag — only `--name`, which sets the
*display* name shown in claude.ai/code, not a stable identity (untested
whether reusing the same `--name` on every launch causes the backend to
update the old entry in place rather than adding a new one — don't assume
it dedupes).

**Effect the user will see:** claude.ai/code and the mobile app accumulate
one target entry per restart, all appearing to be "the same server" (mnt1),
even though only the most recent one is ever actually live. This is not a
bug to chase down server-side — checked directly: at any given time there is
exactly one live `claude rc` process and one live tmux session on the host.
The duplication is purely account-side list state that outlives the process
it pointed to.

**There is nothing to fix from the server.** Confirm which entry is current
by re-running Step 5 and reading the `environment=env_...` value out of the
tmux pane — that's the only live one. The others are safe to remove/dismiss
directly in the claude.ai/code or mobile app UI; there's no SSH-reachable
way to do that from this end.

**Set expectations up front** whenever you set this up or respawn it: tell
the user a new connect link is coming and the old one (and any old target
list entries) will need manual cleanup on their end — don't let them
discover the duplication on their own and think something's broken.

## Respawning

When the user says "respawn claude rc" (or the pane in `claude-rc` is dead),
**do not just kill and relaunch blindly.** Killing the live `claude rc`
process takes down every background worker it spawned too, even ones that
look fully independent at the OS level — this was hit directly on mnt1: 7
background `opencode` workers each had their own session ID (`SID == PID`,
detached from the parent's session), which looked like it should protect
them from a plain `kill` of the parent. Empirically, most of them still died
when the parent was killed — the likely cause is their stdout/stderr being
piped back to the parent for output-streaming, so they got `SIGPIPE`d once
that pipe's reader vanished, independent of session/process-group semantics.

**Before respawning, always check for live in-flight work:**

```bash
ssh <host> "ps --forest -o pid,ppid,etime,cmd -g \$(tmux list-panes -t claude-rc -F '#{pane_pid}')"
```

If there are active child processes (builds, tests, subagent workers), tell
the user what's running and what worktrees/branches it's touching before
proceeding — respawning will very likely interrupt them. Uncommitted changes
in those worktrees are not lost (they're just files on disk), but the
process driving them stops, so flag it rather than silently proceeding.

**Live migration does not work.** `reptyr` (or any ptrace-based tool) cannot
move a running `claude rc` process into a fresh tty without killing/restarting
it — attempting `sudo reptyr <pid>` fails with `Unable to attach: Permission
denied` even as root. This is Claude Code hardening itself against ptrace
(reasonable, given it handles API credentials), not a fixable permissions
issue. Don't spend time on `ptrace_scope` sysctl workarounds — go straight to
kill-and-relaunch once the user's aware of the trade-off.

**To actually respawn**, once you've confirmed it's OK to interrupt anything
running:

```bash
# If the pane is dead but the session/server is intact (the remain-on-exit case):
ssh <host> "tmux respawn-pane -t claude-rc -k '~/launch_claude_rc.sh'"

# If a stray un-wrapped process is running outside tmux (e.g. the web UI
# restarted it directly — see Step 1):
ssh <host> "kill <PID> && sleep 2"
ssh <host> "~/start_claude_rc_tmux.sh"   # idempotent — safe even if a session already exists

# If the whole tmux server is gone:
ssh <host> "~/start_claude_rc_tmux.sh"
# or equivalently:
ssh <host> "sudo systemctl restart claude-rc.service"
```

`tmux respawn-pane -k` is the cleanest option when the session itself is
still alive — it reuses the existing pane instead of creating a new window,
keeping the session structure (and `remain-on-exit` setting) untouched.

After respawning, always re-verify with Step 5 and give the user the fresh
`environment=env_...` connect link — restarting `claude rc` issues a new one
each time, so the old link (and any web/mobile connection using it) goes
stale.

## Troubleshooting

**Error:** `tmux ls` → `no server running on /tmp/tmux-<uid>/default`
**Cause:** The tmux server's last session lost its last pane (crash without
`remain-on-exit`, or the session was explicitly killed) and the server
exited with it. This is what "wrap it in tmux" is meant to prevent going
forward — reinstall following Steps 2-4.
**Solution:** Re-run the bootstrap script (Step 3's script, or `sudo
systemctl restart claude-rc.service`).

**Error:** `sudo reptyr <pid>` → `Unable to attach to pid <pid>: Permission
denied`
**Cause:** Claude Code blocks ptrace on itself. Not a `ptrace_scope`/sudo
issue — root also gets denied.
**Solution:** Don't try to work around it. Use the kill-and-relaunch path in
Respawning instead, after checking for in-flight work.

**Error:** The same server (e.g. mnt1) shows up more than once in the
claude.ai/code or mobile app target list.
**Cause:** Expected, not a bug — see "Known Trade-off" above. Every restart
(manual or the automatic post-reboot one) mints a new environment
registration; old ones aren't cleaned up automatically.
**Solution:** Get the current live `environment=env_...` URL from the tmux
pane (Step 5) and tell the user that's the one to use. Stale entries can
only be removed from the app UI itself, not from the server.

**Error:** Mac/mobile app doesn't show the server as a remote target, even
though claude.ai/code (web) can see and control it.
**Cause:** This has consistently turned out to be a client-side app sync
issue, not a server-side one — the same environment ID and healthy
`remote-server.log` (no errors) were confirmed server-side while the desktop
app still didn't list it.
**Solution:** This isn't fixable from the server. Have the user fully quit
and reopen the desktop app, confirm it's signed into the same Anthropic
account, and check for a pending app update.
