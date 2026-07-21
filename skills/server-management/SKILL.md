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
  version: "2.1.0"
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

## Step 2: Every Remote Command Confirms Its Own Host

There is no persistent SSH session across commands — each command you run
starts a fresh, non-interactive shell, so a bare `ssh <target>` in one
command does **not** keep you "connected" for the next one. Never assume
you're still on `<target>` because an earlier command connected to it; that
assumption is exactly how a command silently runs on the wrong box (or
locally) instead of the intended server.

Run remote work as a single non-interactive SSH invocation, one host per
command, and confirm location inline:

```bash
ssh <target> 'hostname && <command>'
```

For a sequence of related commands on the same host, chain them inside the
*same* `ssh` invocation rather than splitting across separate commands and
relying on a prior one to have left you "there":

```bash
ssh <target> 'cd /docker/foo && docker compose ps'
```

If a task hops across hosts (e.g. mnt1 → srv1), each hop needs its own
explicit `ssh <hop>` — confirm the hostname at every hop, never by chaining
off a previous command's connection.

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

**User/group:** containers run as `1001:110`, not root — set `user: "1001:110"` at
the service level in every `docker-compose.yml`. All three hosts have a uid-1001
account (named `docker`) and a gid-110 group backing this (named `docker` on srv1,
`docker-user` on mnt1/sandbox — the group *name* varies but the GID is always 110).
`roberto` is a member of that gid-110 group on all three, plus each host's actual
Docker daemon-socket group, so it can both administer containers (`docker ps`,
`compose up`, etc.) and own/read/write the `1001:110` bind-mounted data without sudo.
Before assuming this is set up on a *new* host, verify with `id docker`.

**Bind mounts only:** all persistent data uses bind mounts (`./data/...`) —
named or anonymous Docker volumes are forbidden. See the Quick Reference below.

```yaml
services:
  myapp:
    user: "1001:110"
    volumes:
      - ./data/myapp:/var/lib/myapp   # correct — bind mount
      - myapp_data:/var/lib/myapp     # forbidden — named volume
```

New container checklist: create `/docker/<name>/data/<service>` first, write the
compose file, `sudo chown -R 1001:110 /docker/<name>/data`, then `docker compose up`.

---

## Data Directories (srv1)

Outside of `/docker/`, srv1 also uses:
- `/data` — application data, databases, archives
- `/data/archives` — file archives

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
