---
name: server-management
description: |
  Server management skill for nas (TrueNAS Scale), srv1 (Ubuntu production server), srv2 (Ubuntu server), proxmox (Proxmox VE hypervisor), and prox1 (Ubuntu server).
  Use when: managing servers, SSH connections, Docker containers, package updates, code deployment, log analysis.
  Access servers via `ssh nas`, `ssh srv1`, `ssh srv2`, `ssh proxmox`, or `ssh prox1`. Remote users have sudo without password (except proxmox which is read-only).
  IMPORTANT: nas management is read-only; proxmox management is read-only (use Proxmox web UI for changes); srv1, srv2, and prox1 allow full management with confirmation.
license: MIT
metadata:
  version: "1.4.0"
  category: infrastructure
  servers:
    nas:
      alias: nas
      connection: ssh nas
      ip: 10.10.10.102
      os: TrueNAS Scale (Debian-based)
      role: Home NAS + TrueNAS Apps
      management: read-only only, no CLI Docker management
    srv1:
      alias: srv1
      connection: ssh srv1
      hostname: srv1.stp.vc
      os: Ubuntu
      role: Production server for Step company
      management: full with confirmation
    srv2:
      alias: srv2
      connection: ssh srv2
      ip: 178.104.193.246
      os: Ubuntu
      role: Additional server
      user: roberto (sudo without password)
      management: full with confirmation
    proxmox:
      alias: proxmox
      connection: ssh proxmox
      ip: 10.10.10.159
      os: Proxmox VE (Debian-based hypervisor)
      role: Proxmox VE hypervisor — manages VMs and LXC containers
      user: roberto (sudo available)
      management: read-only — do NOT install software or modify system config on the host
    prox1:
      alias: prox1
      connection: ssh prox1
      ip: 10.10.10.190
      os: Ubuntu
      role: Ubuntu server (VM or standalone)
      user: roberto (sudo without password)
      management: full with confirmation
---

## Server Connection Workflow

When user requests action on a server (nas, srv1, srv2, proxmox, or prox1):

### Step 1: Parse Target Server
```
User: "check disk space on nas" → target = nas
User: "restart the web container on srv1" → target = srv1
User: "check srv2 status" → target = srv2
User: "check proxmox status" → target = proxmox
User: "install docker on prox1" → target = prox1
```

### Step 2: SSH Connection
```bash
ssh <target>
# Example: ssh nas, ssh srv1, ssh srv2, ssh proxmox, or ssh prox1
```

### Step 3: Read Server-Specific Skills (Mandatory — Including Plan Mode)

**IMPORTANT:** This step is NOT optional. Even when operating in plan mode (i.e., before executing any task), you MUST connect to the server and read available skills before formulating any plan that involves srv1, srv2, nas, proxmox, or prox1.

After connecting via SSH, ALWAYS run:
```bash
ls -la ~/.config/opencode/skills/ 2>/dev/null
```

On srv1, `~` resolves to `/home/roberto/.config/opencode` for both the `roberto` user and the `root` user (because `/root/.config/opencode` is a symlink to `/home/roberto/.config/opencode`). This means the same skills are available regardless of which user context you are running in.

If skill files or subdirectories exist at this path, read ALL of them. Their directives take precedence over the general guidelines in this file when they conflict.

**Directive priority:**
1. Server-specific skill directives (highest priority)
2. General server rules in this file
3. Default behavior

### Step 4: Execute Task
Execute the requested task using the appropriate guardrails for that server.

---

## Server-Specific Rules

### nas (TrueNAS Scale)

**ALLOWED Operations (Read-Only):**
- Check pool status: `zpool status`
- List datasets: `zfs list`
- Check dataset space: `df -h`
- View TrueNAS alerts: `midclt call alert.query`
- Check SMB shares status: `smbstatus`
- List running apps: `midclt call app.query`
- Check services: `systemctl list-units --type=service`
- View system health: `midclt call system.general.ui_queries`
- Check NFS exports: `showmount -e localhost`
- Read logs: `journalctl`, `/var/log/` files

**BLOCKED Operations (Never execute on nas):**
- `docker`, `docker-compose`, `docker rm`, `docker rmi` - use TrueNAS UI for apps
- `apt install`, `apt remove`, `dpkg` - system package changes
- `systemctl stop`, `systemctl start`, `systemctl restart` for system services
- Any `zfs` write operations (`zfs create`, `zfs destroy`, `zfs snapshot`)
- `rm`, `mv`, `cp` on system directories
- Firewall changes (`ufw`, `iptables`)
- Kernel parameter changes

**If blocked operation requested:**
```
"I cannot perform that operation on nas. TrueNAS Scale management should be done via the TrueNAS web UI. Would you like me to check the current status instead?"
```

### proxmox (Proxmox VE — Read-Only)

**IMPORTANT:** This is a Proxmox VE hypervisor. Do NOT install software, modify system configuration, or interfere with Proxmox services on this host. All VM and container provisioning should be done via the Proxmox web UI (https://10.10.10.159:8006).

**ALLOWED Operations (Read-Only):**
- Check VM/container status: `qm list`
- Check LXC containers: `pct list`
- View node status: `pvesh get /nodes/proxmox/status`
- Check cluster status: `pvecm status`
- Disk/memory info: `df -h`, `free -h`
- Network interfaces: `ip link`, `ip addr`
- Running services: `systemctl list-units --type=service --state=running`
- View logs: `journalctl`, `/var/log/pve/`
- Check storage: `pvesm status`

**BLOCKED Operations (Never execute on proxmox host):**
- `apt install`, `apt remove`, `dpkg` — no package changes on the hypervisor
- `docker`, `docker-compose` — do not install Docker on a Proxmox host
- `systemctl stop/start/restart` for Proxmox services (`pve*`, `corosync`, etc.)
- Any changes to `/etc/pve/`
- Firewall changes (`ufw`, `iptables`, `pve-firewall`)
- Kernel parameter changes

**If blocked operation requested:**
```
"I cannot perform that operation on the proxmox host. Proxmox VE hypervisor management should be done via the Proxmox web UI at https://10.10.10.159:8006. Would you like me to check the current status instead?"
```

### srv1 (Ubuntu - Production)

**Note on user context:** When you `ssh srv1`, you connect as `roberto`. If you later `sudo su` to become `root`, opencode will still find the same skills because `/root/.config/opencode` is a symlink to `/home/roberto/.config/opencode`. Both users share the same skill directory on srv1.

**ALLOWED Operations:**
- System info: `uname -a`, `uptime`, `who`
- Disk/memory: `df -h`, `free -h`, `lsblk`
- Package management: `apt update`, `apt upgrade`, `apt install`, `apt remove`
- Service management: `systemctl status`, `systemctl stop/start/restart`
- Docker: `docker ps`, `docker-compose up/down`, `docker exec`, `docker logs`
- Code operations: `git pull`, file copy/move
- Log analysis: `journalctl`, `/var/log/`, `docker logs`
- Process management: `ps aux`, `top`, `htop`
- Network: `ss`, `netstat`, `ping`, `curl`

**Dangerous Operations (require confirmation):**
See "Dangerous Operation Confirmation" section below.

### srv2 (Ubuntu - Additional Server)

**Note on Docker access:** If you get `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`, use `sudo` before the docker command (e.g., `sudo docker ps`) or ensure your user is in the `docker` group. Check with `groups roberto`.

**ALLOWED Operations:**
- All operations allowed on srv1
- Docker installation and management
- Testing new configurations

**Docker Installation Rules:**
- All Docker installations MUST be done starting from a subdirectory of `/mnt/box2/docker`
- In that subdirectory, create directories for all volumes mounted by the Docker
- The subdirectory must contain the `docker-compose.yml` file for the Docker(s) being installed
- Example structure:
  ```
  /mnt/box2/docker/<service-name>/
    ├── docker-compose.yml
    ├── data/          (for volume mounts)
    ├── workspace/     (for volume mounts)
    └── ...
  ```

**Dangerous Operations (require confirmation):**
See "Dangerous Operation Confirmation" section below.

### prox1 (Ubuntu Server)

**Note on Docker access:** If you get `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`, use `sudo` before the docker command (e.g., `sudo docker ps`) or ensure your user is in the `docker` group. Check with `groups roberto`.

**ALLOWED Operations:**
- All operations allowed on srv1
- Docker installation and management

**Docker Installation Rules:**
- All Docker installations MUST be done starting from a subdirectory of `/docker`
- In that subdirectory, create directories for all volumes mounted by the Docker
- The subdirectory must contain the `docker-compose.yml` file for the Docker(s) being installed
- Example structure:
  ```
  /docker/<service-name>/
    ├── docker-compose.yml
    ├── data/          (for volume mounts)
    ├── workspace/     (for volume mounts)
    └── ...
  ```

**Dangerous Operations (require confirmation):**
See "Dangerous Operation Confirmation" section below.

---

## Dangerous Operation Confirmation

**CRITICAL RULE:** Before executing any dangerous operation, ALWAYS explain what you want to do and ask permission.

### Confirmation Template

```
I'm going to [ACTION] on [SERVER].

What this will do: [EXPLANATION of the effect]
What this affects: [AFFECTED services/containers/data]
Duration: [EXPECTED time]

Do you want me to proceed? (yes/no)
```

### Operations Requiring Confirmation

| Operation | Example Commands |
|-----------|------------------|
| Package install | `apt install <package>` |
| Package remove | `apt remove <package>`, `apt purge <package>` |
| Docker container delete | `docker rm <container>` |
| Docker image delete | `docker rmi <image>` |
| Docker compose down | `docker-compose down` |
| Service restart | `systemctl restart <service>` |
| Service stop | `systemctl stop <service>` |
| Service disable | `systemctl disable <service>` |
| File/directory delete | `rm -rf <path>` |
| Directory move | `mv <path> <new-path>` |
| Reboot | `reboot`, `shutdown -r` |
| Firewall changes | `ufw enable/disable`, `iptables` |
| System-wide changes | `sysctl`, `modprobe`, kernel params |

---

## Common Task Templates

### System Information

```bash
# Quick system overview
uptime && echo "---" && df -h && echo "---" && free -h
```

### Docker Operations (srv1, srv2, prox1)

```bash
# List running containers
docker ps

# View container logs
docker logs <container_name> --tail 50 -f

# Execute command in container
docker exec -it <container_name> <command>

# Docker compose operations
# prox1:  /docker/<service>/
# srv2:   /mnt/box2/docker/<service>/
cd <compose-directory>
docker-compose ps
docker-compose logs -f <service>
docker-compose restart <service>
```

### Package Management (srv1, srv2, prox1)

```bash
sudo apt update
sudo apt upgrade
sudo apt install <package-name>
sudo apt remove <package-name>
```

### Log Analysis

```bash
journalctl -n 50
journalctl -f
journalctl -u <service-name> -n 50
docker logs <container> --tail 100 -f
```

### Proxmox Operations (proxmox — read-only)

```bash
qm list           # List VMs
pct list          # List LXC containers
pvesm status      # Storage status
pvecm status      # Cluster status
df -h && free -h  # Resource usage
```

### TrueNAS Operations (nas only)

```bash
zpool status
zfs list
midclt call app.query
smbstatus
```

---

## Server-Specific Skills Discovery

When connecting to a server, ALWAYS check for and read skills at `~/.config/opencode/skills/` on that server. These skills are binding instructions and take priority over this file.

---

## Safety Checklist Before Execution

- [ ] Confirmed target server (nas, srv1, srv2, proxmox, or prox1)
- [ ] Connected to server via SSH before formulating any plan or steps
- [ ] Read and understood all server-specific skill directives
- [ ] Verified operation is allowed on target server
- [ ] For dangerous ops on srv1/srv2/prox1: explained and got confirmation
- [ ] For nas: verified operation is read-only
- [ ] For proxmox: verified operation is read-only (no software installation)
- [ ] For prox1 Docker: verified Docker files are in `/docker/<service>/` subdirectory
- [ ] For srv2 Docker: verified Docker files are in `/mnt/box2/docker/<service>/` subdirectory

---

## Error Handling

If an operation fails:
1. Show the error message
2. Explain what likely caused it
3. Suggest remediation steps
4. Ask if user wants to retry with different parameters

If SSH connection fails:
1. Verify the server alias is correct (nas, srv1, srv2, proxmox, or prox1)
2. Check if SSH key is configured: `ssh-add -l`
3. Check if the server is reachable: `ping <ip>`
