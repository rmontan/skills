---
name: server-management
description: |
  Use when managing srv1 (production), mnt1 (personal server), sandbox (test server),
  or nas (TrueNAS Scale) — SSH connections, Docker containers, package updates,
  code deployment, log analysis, or checking service/firewall status on the home lab.
  Access via `ssh srv1`, `ssh mnt1`, `ssh sandbox`, `ssh nas`. All Linux hosts have a
  passwordless-sudo `roberto` user; nas is GUI-managed only, no CLI Docker/app changes.
license: MIT
metadata:
  version: "2.0.0"
  category: infrastructure
  servers:
    srv1:
      alias: srv1
      connection: ssh srv1
      hostname: srv1.stp.vc
      os: Ubuntu Linux
      role: Production server (Step company)
      user: roberto (passwordless sudo)
      hosting: Hetzner, behind its own firewall
      management: full, with confirmation for dangerous ops (same rules as mnt1/sandbox)
    mnt1:
      alias: mnt1
      connection: ssh mnt1
      ip: 10.10.10.231
      os: Ubuntu Linux
      role: Personal server
      user: roberto (passwordless sudo)
      hosting: VM on nas
      management: full, with confirmation for dangerous ops
    sandbox:
      alias: sandbox
      connection: ssh sandbox
      ip: 10.10.10.233
      os: Ubuntu Linux
      role: Test server
      user: roberto (passwordless sudo)
      hosting: VM on nas
      management: full, with confirmation for dangerous ops
    nas:
      alias: nas
      connection: ssh nas
      ip: 10.10.10.102
      os: TrueNAS Scale (Debian-based)
      role: Home NAS, hosts mnt1/sandbox VMs, runs NPM (Nginx Proxy Manager)
      user: admin (SSH login user — no roberto account on nas)
      management: read-only via CLI; all app/container/storage changes go through the TrueNAS web UI
---

## Overview

Four machines: **srv1** (production), **mnt1** (personal), **sandbox** (test), **nas**
(TrueNAS, GUI-only). All Linux hosts (srv1/mnt1/sandbox) run Docker under the
`roberto` user, which has passwordless sudo. SSH between all hosts is
passwordless.

## Network Topology

```
                 Mac (client)
        ┌───────────┬──────────┬───────────┐
        │           │          │           │
        ▼           ▼          ▼           ▼
      srv1        mnt1      sandbox       nas
   (Hetzner,     (VM on    (VM on     (TrueNAS,
    isolated)      nas)       nas)     hosts NPM)
        ▲           │  ▲       │  ▲
        │           └──┼───────┘  │
        └──────────────┘──────────┘
   mnt1 ↔ sandbox ↔ srv1 (mesh; srv1 accepts inbound only)
```

- **Mac → all four**: full SSH access, passwordless. This is the starting point for everything.
- **mnt1 ↔ sandbox**: can SSH to each other.
- **mnt1 → srv1** and **sandbox → srv1**: can SSH in.
- **srv1 → anything**: cannot initiate SSH out to mnt1, sandbox, or nas. srv1 is a one-way-in leaf node.
- **nas, mnt1, sandbox**: sit behind a shared home firewall (10.10.10.0/24).
- **srv1**: hosted on Hetzner behind its own firewall — allows all traffic from the home network's public IP, and only ports 80/443 from everywhere else.
- **NPM (Nginx Proxy Manager)** runs on nas and is the single reverse proxy for external access to services on nas, mnt1, and sandbox. Any service on those three that needs external exposure goes through NPM, not a direct port-forward.
- External access to services on **srv1** goes through its own Hetzner-side setup (ports 80/443 only) — srv1 is not behind NPM since NPM lives on the home network.

## Step 1: Identify the Target Host

Parse the user's request to a single target: `srv1`, `mnt1`, `sandbox`, or `nas`.
If the task requires hopping between hosts (e.g. deploying from mnt1 to srv1),
identify every hop up front — remember srv1 cannot initiate outbound hops.

## Step 2: Connect and Confirm Location

```bash
ssh <target>
hostname   # confirm you actually landed where you intended
```

Do this **once per session**, right after connecting — not before every
individual command. If you hop between hosts mid-session (e.g. mnt1 → srv1),
re-run `hostname` after each hop, since it's easy to lose track of which box
a shell is on.

## Step 3: Execute the Task

Apply the server-specific rules below. For dangerous operations, always use
the confirmation template regardless of which server (srv1, mnt1, sandbox all
follow the same rule — production gets no special exemption or extra strictness,
just the same discipline).

---

## Server-Specific Rules

### nas (TrueNAS Scale) — read-only, GUI-managed

**Allowed via CLI (read-only):**
- `zpool status`, `zfs list`, `df -h`
- `midclt call alert.query`, `midclt call app.query`
- `smbstatus`, `showmount -e localhost`
- `systemctl list-units --type=service`
- `journalctl`, `/var/log/*`

**Never run on nas:** `docker`/`docker-compose` commands, `apt install/remove`,
`zfs create/destroy/snapshot`, `systemctl start/stop/restart`, `rm/mv/cp` on
system paths, firewall changes. Apps, storage, and NPM configuration are all
managed through the TrueNAS web UI.

**If a blocked operation is requested:** explain that TrueNAS management goes
through the web UI, and offer to check current status via CLI instead.

### srv1, mnt1, sandbox (Ubuntu) — full management, roberto user

**Allowed freely:**
- Diagnostics: `uptime`, `df -h`, `free -h`, `lsblk`, `ps aux`, `top`, `ss`, `curl`, `ping`
- `docker ps`, `docker logs`, `docker exec`, `docker compose ps/logs`
- `journalctl`, `docker logs --tail`
- `apt update` (checking for updates is safe)
- Container lifecycle: `docker start/stop/restart`, `docker compose up -d`,
  `docker compose down`, `docker compose restart`, and rebuilds
  (`docker compose up -d --build`, `docker compose up -d --force-recreate`)

**Requires confirmation (see template below):**
- `apt upgrade`, `apt install`, `apt remove`/`purge`
- `docker rm`, `docker rmi` (actually deleting a container/image, not just stopping/rebuilding it)
- `systemctl restart/stop/disable` for any service
- `rm -rf`, destructive `mv`
- `reboot`/`shutdown`
- Firewall changes (`ufw`, `iptables`)

**srv1-specific:** confirm you're not trying to hop *from* srv1 to another
host — it can't, and the attempt will just hang until timeout.

---

## Docker Convention (srv1, mnt1, sandbox)

Every container lives under **`/docker/<container-name>/`**, and every volume
that container mounts must be a subdirectory of that same folder. No
exceptions — don't mount volumes elsewhere on the filesystem.

```
/docker/<container-name>/
  ├── docker-compose.yml     # required filename
  ├── data/                  # example volume mount
  ├── config/                # example volume mount
  └── ...
```

- Compose file is always named `docker-compose.yml` (not `compose.yaml`).
- Before creating a new container, `ls /docker` to check naming collisions and existing conventions.
- Manage with `docker compose` from inside `/docker/<container-name>/` (`ps`, `logs -f`, `restart`, `down`).

---

## Dangerous Operation Confirmation

Applies identically on srv1, mnt1, and sandbox — no server gets a pass.

```
I'm going to [ACTION] on [SERVER].

What this will do: [EFFECT]
What this affects: [SERVICES/CONTAINERS/DATA]
Duration: [EXPECTED TIME]

Proceed? (yes/no)
```

| Operation | Example |
|---|---|
| Package install/remove | `apt install/remove/purge <pkg>` |
| Package upgrade | `apt upgrade` |
| Container/image delete | `docker rm`, `docker rmi` |
| Service restart/stop/disable | `systemctl restart/stop/disable <svc>` |
| Destructive file ops | `rm -rf <path>`, risky `mv` |
| Reboot | `reboot`, `shutdown -r` |
| Firewall changes | `ufw`, `iptables` |

---

## Skills Sync (skillshare)

srv1, mnt1, and sandbox each have `skillshare` installed with `~/.config/skillshare`
cloned from `git@github.com:rmontan/skills.git` (global mode, `git_root: root`) — this
is the same repo the Mac's `~/.config/skillshare` syncs from. Skills land symlinked
into `~/.claude/skills`, `~/.gemini/skills`, and `~/.config/opencode/skills` on all
three servers (Claude, agy/antigravity, and opencode are used on all of them).

**"Sync skills to all servers" / "update skills on srv1/mnt1/sandbox" means:**
```bash
ssh srv1 skillshare pull
ssh mnt1 skillshare pull
ssh sandbox skillshare pull
```
`skillshare pull` does `git pull` + `skillshare sync` in one shot. If a skill was
edited locally on the Mac first, push it to the repo before pulling on the servers
(`skillshare push` from the Mac, or plain `git push` from `~/.config/skillshare`).

Don't hand-copy or manually symlink skill directories on any server — everything
should flow through this repo so all hosts stay in sync from one source.

---

## Credentials

Server/service credentials (mail account, SMTP relay, etc.) live in
`~/.config/server/credentials.env` on srv1, mnt1, and sandbox — never in this skill,
never in the skillshare repo, never in chat. That file is host-local, deployed
out-of-band (not via git/skillshare), and not readable without the right permissions
(root-owned 600 on srv1; roberto-owned 600 on mnt1/sandbox).

If a task needs a credential from it, read the specific value you need rather than
dumping the whole file, and don't echo secret values back into chat or logs.

---

## Error Handling

- SSH fails: verify alias (`srv1`/`mnt1`/`sandbox`/`nas`), check `ssh-add -l`,
  and remember srv1 can only be reached directly, never via a mnt1/sandbox hop.
- Command fails: show the error, explain the likely cause, suggest a fix,
  ask before retrying with different parameters.
