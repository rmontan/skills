---
name: server-management
description: |
  Use when managing srv1 (production), czap1 (contactzapp production), mnt1 (personal server), sandbox (test server), czadmin (contactzapp admin VM),
  tmp1 (temporary Hetzner server, being shut down), or nas (TrueNAS Scale) — SSH connections, Docker containers, package updates,
  code deployment, log analysis, or checking service/firewall status on the home lab. Also covers the Purelymail
  mail hosting (mailboxes, domains, routing/aliases for contactz.app etc.) via its API — see "Purelymail".
  Access via `ssh srv1`, `ssh czap1`, `ssh mnt1`, `ssh sandbox`, `ssh czadmin`, `ssh tmp1`, `ssh nas`. All Linux hosts have a
  passwordless-sudo `roberto` user; nas is GUI-managed only, no CLI Docker/app changes.
license: MIT
metadata:
  version: "2.5.0"
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
      hosting: KVM/QEMU VM on its own physical host (separate hardware, NOT the nas); same home LAN
      management: full, with confirmation for dangerous ops
    sandbox:
      alias: sandbox
      connection: ssh sandbox
      ip: 10.10.10.233
      os: Ubuntu Linux
      role: Test server + CI runners (monitoring moved to czadmin 2026-10-05; Beszel agent only)
      user: roberto (passwordless sudo)
      hosting: VM on nas
      management: full, with confirmation for dangerous ops
    czadmin:
      alias: czadmin
      connection: ssh czadmin (from the Mac or mnt1)
      ip: 10.10.10.234
      os: Ubuntu 26.04 LTS (2 vCPU, 2.5 GB RAM, 50 GB disk — root LV extended to the full VG; /tmp on disk, tmp.mount masked)
      role: Admin VM for contactzapp — monitoring box (Beszel hub, Uptime Kuma, Healthchecks, ntfy) since 2026-10-05; will host the detached admin panel (REQ-1701). Never a CI runner.
      user: roberto (passwordless sudo, /etc/sudoers.d/90-roberto)
      hosting: VM on nas
      management: full, with confirmation for dangerous ops
    tmp1:
      alias: tmp1
      connection: ssh tmp1 (from the Mac or mnt1)
      ip: 2.29.62.35
      os: Ubuntu 26.04 LTS
      role: Temporary server — being shut down soon; don't deploy anything new there
      user: roberto (passwordless sudo)
      hosting: Hetzner, host firewall is ufw (active)
      management: full, with confirmation for dangerous ops
    czap1:
      alias: czap1
      connection: ssh czap1 (from the Mac or mnt1)
      ip: 2.31.19.232
      os: Ubuntu Linux
      role: Production server for contactzapp (app.contactz.app), being set up
      user: roberto (passwordless sudo)
      hosting: Hetzner, behind a Hetzner firewall (80/443 public, all ports from home); no host firewall
      management: over SSH only — no Claude Code, opencode or skillshare on the host, by design
    nas:
      alias: nas
      connection: ssh nas
      ip: 10.10.10.102
      os: TrueNAS Scale (Debian-based)
      role: Home NAS, hosts the sandbox and czadmin VMs, runs NPM (Nginx Proxy Manager)
      user: admin (SSH login user — no roberto account on nas)
      management: read-only via CLI; all app/container/storage changes go through the TrueNAS web UI
---

## Overview

Six machines: **srv1** (production), **czap1** (production server for contactzapp), **mnt1** (personal), **sandbox** (test), **tmp1**
(temporary), **nas** (TrueNAS, GUI-only). All Linux hosts (srv1/czap1/mnt1/sandbox/tmp1) run
Docker under the `roberto` user, which has passwordless sudo. SSH is passwordless
along the paths listed under Network Topology.

## Network Topology

```
                 Mac (client)
        ┌───────────┬──────────┬───────────┐
        │           │          │           │
        ▼           ▼          ▼           ▼
      srv1        mnt1      sandbox       nas
   (Hetzner,    (VM, own   (VM on     (TrueNAS,
    isolated)   hardware)    nas)     hosts NPM)
        ▲           │  ▲       │  ▲
        │           └──┼───────┘  │
        └──────────────┘──────────┘
   mnt1 ↔ sandbox ↔ srv1 (mesh; srv1 accepts inbound only)
```

- **Mac → every host** (srv1, czap1, mnt1, sandbox, tmp1, nas): full SSH access, passwordless. This is the starting point for everything.
- **mnt1 ↔ sandbox**: can SSH to each other.
- **mnt1 → srv1** and **sandbox → srv1**: can SSH in.
- **srv1 → anything**: cannot initiate SSH out to mnt1, sandbox, or nas. srv1 is a one-way-in leaf node.
- **nas, mnt1, sandbox**: sit behind a shared home firewall (10.10.10.0/24).
- **srv1**: hosted on Hetzner behind its own firewall — allows all traffic from the home network's public IP, and only ports 80/443 from everywhere else.
- **NPM (Nginx Proxy Manager)** runs on nas and is the single reverse proxy for external access to services on nas, mnt1, and sandbox. Any service on those three that needs external exposure goes through NPM, not a direct port-forward.
- External access to services on **srv1** goes through its own Hetzner-side setup (ports 80/443 only) — srv1 is not behind NPM since NPM lives on the home network.
- **czap1** (2.31.19.232): production server for **contactzapp** (public site `app.contactz.app`).
  Reachable from the **Mac** (`ssh czap1`) and from **mnt1** (`ssh czap1`, h2h key). `roberto`
  user with passwordless sudo. Treat as a leaf like srv1: it has no SSH keys to reach
  anything else. It is production, so apply the same confirmation discipline. It sits behind a **Hetzner
  firewall**: only 80/443 from the internet, everything from the home network; the host
  itself has no firewall (ufw inactive). It is
  managed over SSH only, by design: no Claude Code, opencode or skillshare runs on it,
  and none should be installed.
- **czadmin** (10.10.10.234): admin VM on the nas, created 2026-10-05. Reachable from the **Mac**
  (GitHub key) and from **mnt1** (`ssh czadmin`, h2h key — mnt1's `id_ed25519` is the GitHub key
  but passphrase-protected, so it cannot log in non-interactively). It will host the detached
  admin panel and the monitoring stack; it must **never** run a CI runner (a runner with
  docker.sock is root, and the panel holds per-environment admin tokens). Like czap1 it is
  managed over SSH only: no Claude Code, opencode or skillshare on it, by design. Base setup
  (2026-10-05): Docker CE from download.docker.com (same as sandbox), Docker Convention
  uid/gid 1001:110, watchtower, portainer-agent (:9001, sandbox's agent secret), nightly
  `~/scripts/docker-prune.sh` at 03:30 (generic prune only — no runner housekeeping).
- **tmp1** (2.29.62.35): temporary Hetzner server, being shut down soon, not shown in the diagram. Reachable
  from the **Mac** and from **mnt1** (`ssh tmp1`); sandbox has no alias for it, and tmp1
  has no SSH config/keys to reach anything else (treat it as a leaf, like srv1). Its
  firewall is **ufw** on the host: OpenSSH from anywhere, plus specific ports from the
  home NAT IP only (81.56.206.190). Services publish via `network_mode: host`, not
  Docker port mappings, because Docker-published ports bypass ufw.

## Monitoring (czadmin is the monitoring box)

Since 2026-10-05 the whole stack (ntfy, Healthchecks, Uptime Kuma, Beszel) runs on **czadmin**,
moved from sandbox. Production is watched from there. Alerts go to
**ntfy** (topic `alerts`) → the ntfy phone/web app. Tools publish to ntfy over the LAN
(`http://10.10.10.234:2586`, publisher token), never via the public hostname, so alerting
does not depend on DNS/NPM. Email goes out as `support@contactz.app` through Purelymail
(`smtp.purelymail.com:465`, implicit TLS), each service with its **own app password**
(`beszel-sandbox`, `healthchecks-sandbox` — see "Purelymail"); revoke one without touching the
others. Beszel's SMTP lives in its PocketBase settings (change it through the settings API with a
temporary `beszel superuser`, deleted afterwards); Healthchecks' in `/docker/healthchecks/.env`.

| Service | Host · path | URL | Credentials |
|---|---|---|---|
| Beszel hub | czadmin `/docker/beszel/` | http://10.10.10.234:8090 | owner |
| Uptime Kuma (v2, SQLite) | czadmin `/docker/uptime-kuma/` | http://10.10.10.234:3001 | owner |
| Healthchecks (SQLite) | czadmin `/docker/healthchecks/` | http://10.10.10.234:8000 | login `admin@contactz.app`, password in `admin.credentials` (600); secrets in `.env` (600) |
| ntfy | czadmin `/docker/ntfy/` | https://ntfy.contactz.app (NPM) · http://10.10.10.234:2586 | `credentials` (600): publisher token, read-only `probe` user; `admin` password is owner-held, not stored |

- **ntfy** is `auth-default-access: deny-all`, signup off, web push on, iOS relay via
  `upstream-base-url: https://ntfy.sh` (message text stays local). The NPM proxy host
  needs **no Advanced config** — ntfy sends `X-Accel-Buffering: no` and a 45 s
  keepalive; a pasted nginx snippet (`proxy_http_version`, buffering, timeouts) took the
  host Offline. Force SSL is on.
- **Healthchecks** is at `https://hc.contactz.app` (NPM): only `/ping` is public; every
  other path has a custom location `/` with access list `local` (allows `10.10.10.0/24` and
  `192.168.1.254` — LAN clients reach NPM through the outer router as .254; internet clients
  keep their real IP). `SITE_ROOT=https://hc.contactz.app`. `INTEGRATIONS_ALLOW_PRIVATE_IPS`
  is on so it can reach ntfy on the LAN. Admin via `docker compose exec healthchecks
  ./manage.py …` (its `createsuperuser` takes `--email/--password`, not `--noinput`).
- **Cron jobs report through `/usr/local/bin/hc-run <uuid> <logfile> <cmd…>`**: pings
  `/start`, runs the job appending to the log, then pings the exit code with the last 40 log
  lines; curl failures never affect the job. The one source is this skill's `scripts/hc-run` —
  install it with `sudo install -o root -g root -m 755 <skill>/scripts/hc-run
  /usr/local/bin/hc-run` (czap1 has no skillshare: copy it over ssh), never hand-edit a host
  copy. Wired: czap1 pgbackrest full/diff (roberto crontab) and restic
  (`/etc/cron.d/czap1-restic`); mnt1's six roberto cron jobs. A new check is created in the
  Healthchecks UI or `manage.py shell` (cron schedule, tz, grace) and its UUID goes in the
  cron line. Healthchecks' check descriptions say in plain English what each job does.
- **Beszel agents**: czadmin (same compose as the hub, unix socket), sandbox `/docker/beszel-agent/`
  (:45876, standalone since 2026-10-05), mnt1 `/docker/beszel-agent/`
  (:45876), czap1 `/docker/beszel-agent/` (:45876, reachable from home only via the
  Hetzner firewall), tmp1 `/docker/beszel/` (agent-only, ufw-allowed from home NAT IP).
  srv1 has no agent, on purpose. Systems are defined in
  `/docker/beszel/data/beszel_data/config.yml` on czadmin (owned 1001:110 — append with
  `sudo tee -a`) and synced on hub restart — that file is authoritative (systems missing
  from it are removed), so add new hosts there, not only in the UI. The hub's public key
  is the `KEY` in each agent's compose file.
- **The monitoring box is watched from outside**: roberto's crontab on czadmin runs this skill's
  `scripts/monitoring-heartbeat` (installed at `/usr/local/bin/monitoring-heartbeat`; czadmin has
  no skillshare, so copy it over ssh) every 5 minutes. It pings a healthchecks.io check (owner's account) only when
  Healthchecks, ntfy, Kuma and Beszel all answer, and sends `/fail` naming what is down otherwise. That
  check must alert by email/app from healthchecks.io, never via the self-hosted ntfy.
- The watchtowers on czadmin and sandbox have no label filter: these `:latest`/`:2` images auto-update daily.

## Before Running Anything

If the task hops between hosts (e.g. deploying from mnt1 to srv1), identify every
hop up front — srv1 cannot initiate outbound hops.

### Check whether you are already on the target

**Do not assume the session is running on the Mac.** Claude Code sessions also
run *on* srv1, mnt1, and sandbox (never on czap1 or tmp1). If you are already on the target host, `ssh
<target> '...'` is a pointless self-hop — and it will usually fail, because the
`~/.ssh/id_ed25519` on those hosts is passphrase-encrypted and no ssh-agent is
available in a non-interactive session. The error looks like an access problem
but isn't:

```
roberto@mnt1: Permission denied (publickey).
```

So before building any remote command, establish where you are:

```bash
hostname
```

- **Already on the target** → run the command **directly**, no `ssh` wrapper:
  `docker ps`, not `ssh mnt1 'docker ps'`.
- **On the Mac, or on a different host** → use the SSH form below.

A quick way to make a command work from either place:

```bash
[ "$(hostname)" = "mnt1" ] && docker ps || ssh mnt1 'docker ps'
```

### Every remote command confirms its own host

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

### srv1, czap1, czadmin, mnt1, sandbox, tmp1 (Ubuntu) — full management, roberto user

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

**czap1-specific:** production, being set up, and managed only by SSH from the Mac or
mnt1. It follows the Docker Convention. There is no skillshare, Claude Code, opencode or
`~/.config/server/credentials.env` there, and that is deliberate.

**tmp1-specific:** it's a temporary box being shut down soon — don't deploy new
services there. There's no skillshare, no
`~/.config/server/credentials.env`, and no uid-1001 `docker` account (see Docker
Convention). Firewall changes there mean `ufw`, and still need confirmation.

---

## Docker Convention (srv1, czap1, czadmin, mnt1, sandbox; not tmp1)

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
the service level in every `docker-compose.yml`. Every host it covers has a uid-1001
account (named `docker`) and a gid-110 group backing this (named `docker` on srv1,
`docker-user` on mnt1/sandbox/czadmin — the group *name* varies but the GID is always 110).
`roberto` is a member of that gid-110 group on each of those hosts, plus each host's actual
Docker daemon-socket group, so it can both administer containers (`docker ps`,
`compose up`, etc.) and own/read/write the `1001:110` bind-mounted data without sudo.
Before assuming this is set up on a *new* host, verify with `id docker`.
**tmp1 exception:** no uid-1001/gid-110 exists there (`roberto` is 1000 and in the
socket group 983), so its existing containers run with the image default user.

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

Applies identically on every Linux host (srv1, czap1, czadmin, mnt1, sandbox, tmp1) — no server gets a pass, and production gets no extra strictness either: the same discipline everywhere.

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
three (Claude, agy/antigravity, and opencode are used on all of them). czap1, czadmin and
tmp1 have no skillshare, deliberately.

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

| Key | What it is |
|---|---|
| `PURELYMAIL_API_TOKEN` | Purelymail account API token — see "Purelymail". Present on **mnt1** only (the host agents run mail work from); add it to sandbox/srv1 only if a task there needs it. Never on czap1/tmp1. |

---

## Purelymail (mail hosting for contactz.app)

Mailboxes, domains and aliases are hosted at Purelymail and managed through its JSON API.
Spec: <https://news.purelymail.com/api/index.html> (Swagger UI; the machine-readable spec is
`https://news.purelymail.com/api/swagger-spec.js`).

**Always go through `scripts/purelymail`** (installed at `/usr/local/bin/purelymail`; same
rule as `hc-run`: `sudo install -o root -g root -m 755 <skill>/scripts/purelymail
/usr/local/bin/purelymail`, never hand-edit a host copy). It reads `PURELYMAIL_API_TOKEN`
from the environment or `~/.config/server/credentials.env`, passes it to curl on stdin (not
argv), and prints the raw JSON. Do not write your own `curl` with the token, do not `source`
the credentials file, do not print the token.

```bash
purelymail <operation> '<json body>'          # POST https://purelymail.com/api/v0/<operation>
purelymail listDomains
purelymail listUser
purelymail getUser '{"userName":"info@contactz.app"}'
```

The token is the account-level key: it can do everything the web console can, and the spec
shows no scoping. Treat it like a root credential.

**Operations (all POST, JSON body, header `Purelymail-Api-Token`):**

| Area | Operation → body |
|---|---|
| Users | `listUser` · `getUser {userName}` · `createUser {userName (local part), domainName, password, enablePasswordReset?, recoveryEmail?, sendWelcomeEmail?, enableSearchIndexing?}` · `modifyUser {userName, newUserName?, newPassword?, enablePasswordReset?, requireTwoFactorAuthentication?, enableSearchIndexing?}` · `deleteUser {userName}` |
| Password reset | `listPasswordReset {userName}` · `upsertPasswordReset {userName, type: email\|phone, target, description?, allowMfaReset?, existingTarget?}` · `deletePasswordReset {userName, target}` |
| Routing / aliases | `listRoutingRules` · `createRoutingRule {domainName, prefix, matchUser, targetAddresses[], catchall?}` · `deleteRoutingRule {routingRuleId}` (id comes from `listRoutingRules`) |
| Domains | `listDomains {includeShared?}` · `addDomain {domainName}` · `getOwnershipCode` · `updateDomainSettings {name, allowAccountReset?, symbolicSubaddressing?, recheckDns?}` · `deleteDomain {name}` |
| App passwords | `createAppPassword {userHandle, name?}` → `{appPassword}` · `deleteAppPassword {userName, appPassword}` |
| Billing | `checkAccountCredit` |

`userName` is the **local part** in `createUser` but the **full address** everywhere else.
An error comes back as HTTP 200 with `{"type":"error","code":…,"message":…}`; the wrapper
turns that into a non-zero exit.

**Rules for agents:**
- Read-only calls (`list*`, `get*`, `checkAccountCredit`) are free to use. Start with a read
  to see current state before changing anything.
- The wrapper refuses `deleteUser`, `deleteDomain`, `deleteRoutingRule`, `deleteAppPassword`,
  `deletePasswordReset`, `modifyUser`, `createRoutingRule` and `updateDomainSettings` unless
  `PURELYMAIL_CONFIRMED=1` is set. Set it **only after** the owner has said yes in this
  conversation, using the Dangerous Operation template (action, effect, what it affects).
  `deleteUser` destroys the mailbox and its mail irrecoverably; `deleteDomain` and
  routing changes can silently stop inbound mail.
- `createUser`/`modifyUser` take a password in the body. Generate it (`openssl rand -base64 24`),
  hand it to the owner through a file or the owner's password manager, never into chat, a
  commit, a REQ or a log. Prefer `createAppPassword` for a program that needs mailbox access
  (IMAP/SMTP/CardDAV) so the real password stays out of config files.
- Never print or paste `PURELYMAIL_API_TOKEN`, an `appPassword` or a `newPassword`
  response into chat, a report, a REQ, or the repo. Redact them from anything you quote.
- DNS for a domain (MX/SPF/DKIM/DMARC) is not set through this API: `listDomains` reports
  `dnsSummary.passesMx/Spf/Dkim/Dmarc`, `updateDomainSettings {recheckDns:true}` re-runs
  the check. Records themselves are edited at the DNS provider.
- Rotate the token in the Purelymail console (account settings → API) and replace the
  value in `credentials.env` if it is ever exposed.

---

## Secret escrow (age)

Every host encrypts its own secret files into one bundle that **only the owner can open**, so a
new or changed secret is escrowed by the next nightly run instead of being pasted into
Bitwarden by hand (owner decision, 2026-10-07).

- **Two key pairs, by tier** (owner, 2026-10-07): **prod** (czap1, czadmin) and **dev** (mnt1,
  sandbox). srv1 is deliberately **not** covered: the owner keeps it separate (2026-10-07). A leaked dev key never opens production. The **private** halves live only in
  Bitwarden and on the offline print, and are generated on the owner's Mac. **Never generate a
  key on a server or in an agent session.** The **public** halves are tracked here:
  `escrow/recipients/<tier>.age.pub`. A host never holds a private key, so it cannot decrypt
  its own bundle.
- **What each host escrows** is `escrow/hosts/<host>.files` (absolute paths, files or
  directories), with its tier in `escrow/hosts/<host>.tier`. **When you add a secret file to a
  host, add it to that list in the same session** and re-run `escrow-install`. A listed path
  that is missing fails the run and writes nothing, so a stale list alerts instead of rotting.
- **`scripts/escrow`** (host: `/usr/local/sbin/escrow`, root cron 20:45 UTC through `hc-run`)
  tars the listed paths and `age`-encrypts them to the tier key. It writes
  `/docker/escrow/<host>.tar.age` (0644, ciphertext only), which czap1's and czadmin's restic
  runs pick up from `/docker`.
- **On the Mac, once per tier / per host:** `scripts/escrow-keygen <prod|dev>` makes the key pair, saves the private key to Bitwarden ("escrow <tier> age key") and prints the public key. `scripts/escrow-roots <host>` copies that host's restic password and pgBackRest cipher pass into "<host> escrow roots". Both refuse to overwrite an existing note. Run them as scripts, never pasted into a shell.
- **`scripts/escrow-install <host>`** (run from mnt1 or the Mac) installs or
  refreshes everything from this skill and runs the job once. It refuses if `age` is missing
  (`apt install age` needs the owner's yes) or if the tier's public key is not in this skill
  yet. Its Healthchecks UUID is `escrow/hosts/<host>.hc` (checks "<host> escrow", created 2026-10-07; the collector's is `escrow/collect.hc`, check "mnt1 escrow collect", 21:30 UTC).
- **`scripts/escrow-collect`** runs on mnt1 from roberto's crontab at 21:30 UTC through `hc-run` (log `~/logs/escrow-collect.log`). It copies
  every host's bundle to the NAS share (`/mnt/nas-mnt1/escrow/`, cifs-checked). That gives
  sandbox, which has no backup of its own, an off-host copy, and the prod bundles a
  second one at home.
- **`scripts/escrow-drill <host>`** (Mac) takes the tier key from Bitwarden itself, decrypts a host's bundle and compares
  every file's SHA-256 with the live one. It prints paths and OK/DIFF only. Run it after
  installing on a host and after changing its list.
- **Not covered:** srv1 (kept separate by the owner). Account logins that live only in web consoles (Hetzner, Cloudflare, GitHub,
  Google Cloud, Entra, Freemius, Purelymail, Bitwarden's own master password and recovery
  code). Those stay in Bitwarden. The escrow is for recovery, not day-to-day lookups.
- **Roots that cannot be inside the escrow they unlock** stay in Bitwarden + the offline print:
  the two age private keys, each restic repository password, and the pgBackRest cipher pass.

---

## Error Handling

- `Permission denied (publickey)` when connecting **from** srv1/mnt1/sandbox:
  first check you aren't self-hopping (`hostname` — see "Check whether you are already on the target"). If the target
  really is another host, the cause is almost always the key choice: those hosts
  keep a passphrase-encrypted copy of the Mac key at `~/.ssh/id_ed25519` that
  cannot be used non-interactively. Host-to-host hops must use the unencrypted
  `~/.ssh/id_ed25519_h2h` key, set per-host in `~/.ssh/config` with
  `IdentityFile ~/.ssh/id_ed25519_h2h` + `IdentitiesOnly yes`.
- SSH fails otherwise: verify alias (`srv1`/`czap1`/`mnt1`/`sandbox`/`tmp1`/`nas`), check
  `ssh-add -l`, and remember srv1 can only be reached directly, never via a
  mnt1/sandbox hop.
- Command fails: show the error, explain the likely cause, suggest a fix,
  ask before retrying with different parameters.
