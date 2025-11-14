# Podman Migration Guide for Ping Identity Platform

**Purpose**: This document explains how to migrate the Ping Identity deployment from Docker to Podman.

**Audience**: Developers familiar with Docker but new to Podman

**Version**: 1.0
**Date**: 2025-11-12
**Platform Version**: Ping Identity 7.5.2

---

## Table of Contents

1. [What is Podman?](#what-is-podman)
2. [Docker vs. Podman: Key Differences](#docker-vs-podman-key-differences)
3. [Why Migrate to Podman?](#why-migrate-to-podman)
4. [Migration Requirements](#migration-requirements)
5. [Changes Required for This Deployment](#changes-required-for-this-deployment)
6. [Step-by-Step Migration Instructions](#step-by-step-migration-instructions)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)
8. [Testing and Validation](#testing-and-validation)
9. [Appendix: Command Reference](#appendix-command-reference)

---

## What is Podman?

**Podman** (Pod Manager) is a daemonless container engine for developing, managing, and running OCI Containers on Linux systems. It's designed as a drop-in replacement for Docker with some key architectural differences.

### Key Podman Characteristics

- **Daemonless**: No background daemon process (unlike Docker which runs dockerd)
- **Rootless**: Can run containers without root privileges (enhanced security)
- **OCI Compliant**: Fully compliant with Open Container Initiative standards
- **Docker Compatible**: Most Docker commands work with Podman by aliasing
- **Pod Support**: Native support for Kubernetes-style pods
- **Systemd Integration**: Direct integration with systemd for container management

---

## Docker vs. Podman: Key Differences

### Architecture

**Docker Architecture**:
```
┌────────────────────────────────────────────┐
│           Docker Client (docker)            │
└──────────────────┬─────────────────────────┘
                   │ REST API
                   ▼
┌────────────────────────────────────────────┐
│      Docker Daemon (dockerd) - Root        │
│  ┌──────────────────────────────────────┐  │
│  │        containerd (runtime)          │  │
│  │  ┌────────────────────────────────┐  │  │
│  │  │         Container 1             │  │  │
│  │  └────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────┐  │  │
│  │  │         Container 2             │  │  │
│  │  └────────────────────────────────┘  │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

**Podman Architecture**:
```
┌────────────────────────────────────────────┐
│           Podman Client (podman)            │
│                                             │
│  Directly forks container processes         │
└──────────────────┬─────────────────────────┘
                   │ No Daemon!
                   ▼
┌────────────────────────────────────────────┐
│   Containers run as child processes         │
│   (can run rootless with user namespaces)   │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │      Container 1 (user process)    │    │
│  └────────────────────────────────────┘    │
│  ┌────────────────────────────────────┐    │
│  │      Container 2 (user process)    │    │
│  └────────────────────────────────────┘    │
└────────────────────────────────────────────┘
```

### Comparison Table

| Feature | Docker | Podman | Impact on Ping Deployment |
|---------|---------|---------|---------------------------|
| **Daemon** | Required (dockerd) | None | Podman doesn't need a background service |
| **Root Privileges** | Requires root or docker group | Can run rootless | Better security for Ping containers |
| **Command Syntax** | `docker ...` | `podman ...` | Simple alias or find/replace needed |
| **Compose Tool** | `docker compose` (v2) | `podman-compose` or `podman play kube` | Need to install podman-compose |
| **Networking** | Bridge networks (docker0) | netavark or CNI | Network configuration slightly different |
| **Volume Management** | Docker volumes | Podman volumes | Compatible but stored differently |
| **Systemd Integration** | Via Docker daemon | Direct (podman generate systemd) | Better for auto-start services |
| **Image Storage** | `/var/lib/docker` | `/var/lib/containers` (root) or `~/.local/share/containers` (rootless) | Different storage locations |
| **Socket Location** | `/var/run/docker.sock` | `/run/podman/podman.sock` (root) or `$XDG_RUNTIME_DIR/podman/podman.sock` | Scripts referencing socket need updates |
| **User Namespaces** | Optional | Default for rootless | UIDs inside container map to different UIDs on host |

---

## Why Migrate to Podman?

### Advantages for Ping Identity Deployment

1. **Enhanced Security**:
   - **Rootless containers**: Ping services (DS, IDM, AM) run without root privileges
   - **No daemon attack surface**: No single point of failure (no dockerd to exploit)
   - **User namespaces**: Container root (UID 0) maps to unprivileged user on host

2. **Better Resource Management**:
   - **No daemon overhead**: Containers are direct child processes
   - **Faster startup**: No daemon communication overhead
   - **Lower memory footprint**: No daemon consuming resources

3. **Systemd Integration**:
   - **Native systemd units**: Generate systemd service files for containers
   - **Auto-restart on boot**: Better than Docker's restart policies
   - **Logging to journald**: Unified logging with system logs

4. **Enterprise/Regulatory Compliance**:
   - **RHEL/CentOS default**: Red Hat Enterprise Linux uses Podman
   - **No licensing concerns**: Fully open-source (Apache 2.0)
   - **Auditing**: Direct process management easier to audit

5. **Kubernetes Alignment**:
   - **Pod support**: Can group Ping containers into pods
   - **Kube YAML support**: Can use Kubernetes manifests directly

### When to Stay with Docker

- **Development laptops**: Docker Desktop provides good developer experience
- **Existing Docker ecosystem**: Heavy use of Docker-specific tools
- **Windows/Mac primary**: Podman requires Linux VM (though improving)
- **Team familiarity**: Team strongly prefers Docker

---

## Migration Requirements

### System Requirements

**Operating System**:
- Linux kernel 4.18.0+ (for user namespaces)
- Preferably: RHEL 8+, CentOS 8+, Fedora 34+, Ubuntu 20.10+

**Software**:
```bash
# Podman installation (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y podman podman-compose

# Podman installation (RHEL/CentOS)
sudo dnf install -y podman podman-compose

# Verify installation
podman --version
podman-compose --version
```

**User Configuration (for rootless)**:
```bash
# Check if user namespaces are enabled
cat /proc/sys/kernel/unprivileged_userns_clone
# Should return 1 (Ubuntu) or not exist (RHEL - enabled by default)

# If disabled on Ubuntu:
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/00-local-userns.conf
sudo sysctl -p /etc/sysctl.d/00-local-userns.conf

# Configure subuid/subgid for rootless (usually automatic)
grep ^$(whoami): /etc/subuid
grep ^$(whoami): /etc/subgid

# If not present, add entries:
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
```

**Network Configuration**:
```bash
# Rootless networking setup (if needed)
sudo dnf install -y slirp4netns  # RHEL/CentOS
sudo apt-get install -y slirp4netns  # Ubuntu

# For better performance, install pasta (rootless network backend)
sudo dnf install -y passt  # RHEL/Fedora
```

### Prerequisites Check

Run this script to verify readiness:

```bash
#!/bin/bash
echo "=== Podman Migration Readiness Check ==="
echo

# Check Podman installed
if command -v podman &> /dev/null; then
    echo "✓ Podman installed: $(podman --version)"
else
    echo "✗ Podman NOT installed"
    exit 1
fi

# Check podman-compose
if command -v podman-compose &> /dev/null; then
    echo "✓ podman-compose installed: $(podman-compose --version)"
else
    echo "⚠ podman-compose NOT installed (optional but recommended)"
fi

# Check user namespaces
if [ -f /proc/sys/kernel/unprivileged_userns_clone ]; then
    if [ "$(cat /proc/sys/kernel/unprivileged_userns_clone)" = "1" ]; then
        echo "✓ User namespaces enabled"
    else
        echo "✗ User namespaces DISABLED"
    fi
else
    echo "✓ User namespaces enabled (RHEL default)"
fi

# Check subuid/subgid
if grep -q "^$(whoami):" /etc/subuid && grep -q "^$(whoami):" /etc/subgid; then
    echo "✓ Subordinate UID/GID configured"
else
    echo "✗ Subordinate UID/GID NOT configured"
fi

# Check networking tools
if command -v slirp4netns &> /dev/null; then
    echo "✓ slirp4netns installed"
else
    echo "⚠ slirp4netns NOT installed (needed for rootless networking)"
fi

echo
echo "=== End of Check ==="
```

---

## Changes Required for This Deployment

### 1. Command Changes

**Simple find/replace needed in all files**:

| Current (Docker) | New (Podman) | Files Affected |
|------------------|--------------|----------------|
| `docker` | `podman` | All `.sh` scripts, documentation |
| `docker compose` | `podman-compose` | All scripts calling compose |
| `docker-compose` | `podman-compose` | All scripts calling compose |

### 2. Docker Compose Files

**File**: All `docker-compose.yml` files (DS1-4, IDM1-2, AM1-2)

**Changes Required**:

#### Version Declaration (Optional)
```yaml
# Docker Compose
version: '3.8'

# Podman Compose
# version line can be removed (Podman ignores it) or kept for Docker compatibility
version: '3.8'  # Still valid
```

#### Network Configuration
```yaml
# Docker
networks:
  ping-network:
    external: true

# Podman (same, but network creation different)
networks:
  ping-network:
    external: true
```

**Network Creation Command**:
```bash
# Docker
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network

# Podman
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network
```

#### Volume Mounts (Rootless Consideration)

**Current**:
```yaml
volumes:
  - ${INSTALL_PATH}:/opt/opendj:ro
  - ${DATA_VOLUME}:/opt/opendj/db
  - ${LOGS_VOLUME}:/opt/opendj/logs
```

**For Rootless Podman** (if using):
- Host paths must be readable by your user
- Inside container, files will appear owned by correct user (due to user namespace mapping)
- **Z or z SELinux label** may be needed:
  ```yaml
  volumes:
    - ${INSTALL_PATH}:/opt/opendj:ro,Z
    - ${DATA_VOLUME}:/opt/opendj/db:Z
    - ${LOGS_VOLUME}:/opt/opendj/logs:Z
  ```
  - `:Z` = Private unshared label (for this container only)
  - `:z` = Shared label (multiple containers can access)

**Recommendation**: Start without Z/z labels, add only if SELinux denials occur.

#### Healthchecks

**Docker vs Podman**: Healthchecks work the same way.

**Current healthcheck example**:
```yaml
healthcheck:
  test: ["CMD", "/opt/opendj/bin/status", "--bindDN", "${ROOT_USER_DN}", "--bindPassword", "${ROOT_USER_PASSWORD}", "--script-friendly"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 120s
```

**For Podman**: No changes needed, but rootless containers may need `--privileged=false` or adjustments if healthcheck uses network.

#### Container Restart Policies

```yaml
# Docker and Podman
restart: unless-stopped  # Works in both
```

**Note**: For production Podman, consider `podman generate systemd` instead of restart policies.

### 3. Shell Scripts

**Files to modify**:
- `DS1/setup.sh`, `DS2/setup.sh`, `DS3/setup.sh`, `DS4/setup.sh`
- `IDM1/startup.sh`, `IDM2/startup.sh`
- `AM1/setenv.sh`, `AM2/setenv.sh`
- `shared/scripts/verify-install.sh`
- Any backup or operational scripts

**Changes**:
1. Replace `docker` with `podman` in all commands
2. Replace `docker-compose` or `docker compose` with `podman-compose`
3. Replace `/var/run/docker.sock` with `/run/podman/podman.sock` (if referenced)

**Example**:
```bash
# Before (Docker)
docker exec ds1-container /opt/opendj/bin/status

# After (Podman)
podman exec ds1-container /opt/opendj/bin/status
```

### 4. Documentation Files

**Files to update**:
- `README.md`
- `INSTALLATION-GUIDE.md`
- `checklist.md`
- `CONSIDERATIONS.md`
- `WORKFLOW.md`
- `architecture.md`

**Changes**:
1. Replace references to "Docker" with "Podman" (or "Docker/Podman" for compatibility)
2. Update prerequisites section to mention Podman
3. Update installation commands

**Example (README.md)**:
```markdown
# Before
### Prerequisites
- Docker 20.10.0+
- Docker Compose v2.0.0+

# After
### Prerequisites
- Podman 3.0+ (or Docker 20.10.0+ for Docker-based deployment)
- podman-compose 1.0+ (or Docker Compose v2.0.0+)
```

### 5. Environment Files

**Files**: `.env` files in each directory (DS1-4, IDM1-2, AM1-2)

**Changes**: None required - environment variables work the same.

### 6. Network Creation

**File**: Phase 1 of `INSTALLATION-GUIDE.md`

```bash
# Before (Docker)
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network

# After (Podman)
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network
```

### 7. Container Commands

**All commands in documentation and scripts**:

| Docker Command | Podman Command | Notes |
|----------------|----------------|-------|
| `docker ps` | `podman ps` | List containers |
| `docker ps -a` | `podman ps -a` | List all containers |
| `docker images` | `podman images` | List images |
| `docker exec` | `podman exec` | Execute in container |
| `docker logs` | `podman logs` | View container logs |
| `docker stop` | `podman stop` | Stop container |
| `docker start` | `podman start` | Start container |
| `docker restart` | `podman restart` | Restart container |
| `docker rm` | `podman rm` | Remove container |
| `docker rmi` | `podman rmi` | Remove image |
| `docker compose up` | `podman-compose up` | Start services |
| `docker compose down` | `podman-compose down` | Stop services |
| `docker network ls` | `podman network ls` | List networks |
| `docker volume ls` | `podman volume ls` | List volumes |

### 8. Systemd Integration (Optional Enhancement)

**New feature with Podman**: Generate systemd service units

```bash
# Generate systemd service for DS1 container
podman generate systemd --name ds1-container --files --new

# This creates a ds1-container.service file
# Move to systemd directory:
sudo cp container-ds1-container.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable container-ds1-container.service
sudo systemctl start container-ds1-container.service
```

**Benefits**:
- Containers start automatically on boot
- Managed via systemd (systemctl commands)
- Better logging integration (journald)
- Dependency management (start order)

---

## Step-by-Step Migration Instructions

### Phase 0: Preparation

#### Step 0.1: Backup Current Docker Deployment

```bash
# Stop all containers
cd /home/thepackle/workrepos/ping
docker compose -f DS1/docker-compose.yml down
docker compose -f DS2/docker-compose.yml down
docker compose -f DS3/docker-compose.yml down
docker compose -f DS4/docker-compose.yml down
docker compose -f IDM1/docker-compose.yml down
docker compose -f IDM2/docker-compose.yml down
docker compose -f AM1/docker-compose.yml down
docker compose -f AM2/docker-compose.yml down

# Backup data directories
tar -czf ping-backup-$(date +%Y%m%d).tar.gz \
  DS1/data DS2/data DS3/data DS4/data \
  IDM1/conf IDM2/conf \
  AM1/config AM2/config \
  shared/

# Store backup in safe location
mv ping-backup-*.tar.gz ~/backups/
```

#### Step 0.2: Install Podman

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y podman podman-compose slirp4netns

# RHEL/CentOS/Fedora
sudo dnf install -y podman podman-compose

# Verify installation
podman --version
podman-compose --version
```

#### Step 0.3: Configure Rootless Podman (Recommended)

```bash
# Configure subuid/subgid (if not already done)
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER

# Log out and log back in for changes to take effect
# Or run:
podman system migrate

# Verify rootless setup
podman info | grep -A 5 rootless
```

### Phase 1: Migrate Docker Compose Files

#### Step 1.1: Update All docker-compose.yml Files

No changes needed! Podman-compose is compatible with Docker Compose v3.8 format.

#### Step 1.2: Add SELinux Labels (If Needed)

Only if you're on RHEL/CentOS/Fedora with SELinux enforcing:

```bash
# Check if SELinux is enforcing
getenforce

# If Enforcing, add :Z labels to volume mounts
# Edit each docker-compose.yml and change:
volumes:
  - ${INSTALL_PATH}:/opt/opendj:ro,Z
  - ${DATA_VOLUME}:/opt/opendj/db:Z
  - ${LOGS_VOLUME}:/opt/opendj/logs:Z
```

### Phase 2: Update Scripts

#### Step 2.1: Create Script Migration Tool

```bash
# Create a script to update all scripts
cat > migrate-scripts.sh << 'EOF'
#!/bin/bash
# Migrate Docker commands to Podman in all scripts

find . -name "*.sh" -type f | while read file; do
  echo "Processing $file..."
  sed -i 's/docker compose/podman-compose/g' "$file"
  sed -i 's/docker-compose/podman-compose/g' "$file"
  sed -i 's/\bdocker\b/podman/g' "$file"
  sed -i 's/\/var\/run\/docker\.sock/\/run\/podman\/podman.sock/g' "$file"
done

echo "Migration complete!"
EOF

chmod +x migrate-scripts.sh
```

#### Step 2.2: Run Migration

```bash
# Review what will change first (dry run)
find . -name "*.sh" -type f -exec grep -l "docker" {} \;

# Run migration
./migrate-scripts.sh

# Verify changes
git diff

# If happy with changes, commit
git add .
git commit -m "Migrate from Docker to Podman"
```

### Phase 3: Update Documentation

```bash
# Update documentation files
sed -i 's/Docker/Podman/g' README.md INSTALLATION-GUIDE.md checklist.md CONSIDERATIONS.md WORKFLOW.md architecture.md

# Update specific commands in INSTALLATION-GUIDE.md
sed -i 's/docker network create/podman network create/g' INSTALLATION-GUIDE.md
sed -i 's/docker compose up/podman-compose up/g' INSTALLATION-GUIDE.md
sed -i 's/docker ps/podman ps/g' INSTALLATION-GUIDE.md
```

### Phase 4: Recreate Network

```bash
# Create Podman network (same as Docker)
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network

# Verify network created
podman network ls
podman network inspect ping-network
```

### Phase 5: Deploy with Podman

#### Step 5.1: Deploy PingDS Instances

```bash
# Deploy DS1
cd DS1
podman-compose up -d
podman logs -f ds1-container
# Wait for "Directory Server has started successfully"
cd ..

# Deploy DS2
cd DS2
podman-compose up -d
podman logs -f ds2-container
cd ..

# Deploy DS3 and DS4
cd DS3
podman-compose up -d
cd ../DS4
podman-compose up -d
cd ..

# Verify all DS containers running
podman ps | grep ds
```

#### Step 5.2: Configure DS Replication

```bash
# Enable replication between DS1 and DS2
podman exec ds1-container /opt/opendj/bin/dsreplication enable \
  --host1 ds1-container --port1 4444 \
  --bindDN1 "cn=Directory Manager" --bindPassword1 password \
  --replicationPort1 8989 \
  --host2 ds2-container --port2 4444 \
  --bindDN2 "cn=Directory Manager" --bindPassword2 password \
  --replicationPort2 8989 \
  --adminUID admin --adminPassword password \
  --baseDN "dc=example,dc=com" \
  --trustAll --no-prompt

# Initialize replication
podman exec ds1-container /opt/opendj/bin/dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds1-container --portSource 4444 \
  --hostDestination ds2-container --portDestination 4444 \
  --adminUID admin --adminPassword password \
  --trustAll --no-prompt

# Verify replication
podman exec ds1-container /opt/opendj/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt
```

#### Step 5.3: Deploy PingIDM

```bash
# Deploy IDM1
cd IDM1
podman-compose up -d
podman logs -f idm1-container
# Wait for "OpenIDM ready"
cd ..

# Deploy IDM2
cd IDM2
podman-compose up -d
podman logs -f idm2-container
cd ..

# Verify IDM clustering
curl -k -u admin:admin https://localhost:8453/openidm/cluster
```

#### Step 5.4: Deploy PingAM

```bash
# Deploy AM1
cd AM1
podman-compose up -d
podman logs -f am1-container
# Wait for Tomcat startup
cd ..

# Deploy AM2
cd AM2
podman-compose up -d
podman logs -f am2-container
cd ..

# Verify AM instances
curl http://localhost:8100/am/isAlive.jsp
curl http://localhost:8101/am/isAlive.jsp
```

### Phase 6: Validation

```bash
# Check all containers
podman ps

# Check network
podman network inspect ping-network

# Run health checks
./shared/scripts/health-check.sh

# Test authentication end-to-end
# (Follow INSTALLATION-GUIDE.md Phase 5 tests)
```

### Phase 7: Systemd Integration (Optional)

```bash
# Generate systemd units for all containers
for container in ds1 ds2 ds3 ds4 idm1 idm2 am1 am2; do
  podman generate systemd --name ${container}-container --files --new
done

# Move service files to systemd
sudo mv container-*.service /etc/systemd/system/

# Enable services
sudo systemctl daemon-reload
for container in ds1 ds2 ds3 ds4 idm1 idm2 am1 am2; do
  sudo systemctl enable container-${container}-container.service
done

# Services will now start on boot
```

---

## Troubleshooting Common Issues

### Issue 1: "permission denied" when accessing volumes

**Symptom**:
```
Error: unable to access /home/thepackle/workrepos/ping/DS1/data: permission denied
```

**Cause**: Rootless Podman uses user namespaces. Container UID 0 maps to your UID + offset on host.

**Solution**:

**Option A**: Fix permissions
```bash
# Make volumes writable by your user
chmod -R 755 DS1/data DS1/logs DS1/config
chown -R $USER:$USER DS1/data DS1/logs DS1/config
```

**Option B**: Run as root (not recommended for production)
```bash
sudo podman-compose up -d
```

**Option C**: Use podman unshare
```bash
# Enter user namespace and fix permissions
podman unshare chown -R 0:0 DS1/data
```

### Issue 2: "network not found" when starting containers

**Symptom**:
```
Error: network ping-network not found
```

**Cause**: Network wasn't created or was created in different namespace (root vs rootless).

**Solution**:
```bash
# Check if network exists
podman network ls

# If not present, create it
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network

# If using rootless, ensure you're not mixing root and rootless commands
# Networks created with sudo won't be visible to rootless podman
```

### Issue 3: Containers can't communicate with each other

**Symptom**:
```
IDM can't connect to DS: Connection refused
```

**Cause**: Rootless networking limitations or DNS not working.

**Solution**:

**Check DNS in network**:
```bash
podman network inspect ping-network | grep -A 10 dns_enabled
```

**Test connectivity**:
```bash
podman exec idm1-container ping ds1-container
podman exec idm1-container nslookup ds1-container
```

**Fix DNS**:
```bash
# Recreate network with DNS enabled (default)
podman network rm ping-network
podman network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network
```

### Issue 4: Port binding fails (address already in use)

**Symptom**:
```
Error: cannot listen on the TCP port: listen tcp4 0.0.0.0:8080: bind: address already in use
```

**Cause**: Port already bound by another process or container.

**Solution**:
```bash
# Check what's using the port
sudo lsof -i :8080
# or
sudo ss -tulpn | grep :8080

# Stop conflicting service
sudo systemctl stop <service>

# Or change port in docker-compose.yml
```

### Issue 5: SELinux denials blocking access

**Symptom** (in audit log):
```
type=AVC msg=audit(1234567890.123:456): avc: denied { read } for comm="conmon" path="/home/user/ping/DS1/data" dev="sda1" ino=123456
```

**Cause**: SELinux preventing container access to volumes.

**Solution**:

**Option A**: Add :Z label to volumes (recommended)
```yaml
volumes:
  - ${DATA_VOLUME}:/opt/opendj/db:Z
```

**Option B**: Temporarily set SELinux to permissive (testing only)
```bash
sudo setenforce 0
# Test if issue resolved
# Re-enable: sudo setenforce 1
```

**Option C**: Create SELinux policy (advanced)
```bash
# Generate policy from audit log
sudo ausearch -m AVC -ts recent | audit2allow -M my-podman-policy
sudo semodule -i my-podman-policy.pp
```

### Issue 6: Healthcheck failing in rootless mode

**Symptom**:
```
healthcheck failed: container is unhealthy
```

**Cause**: Healthcheck command doesn't work in rootless namespace.

**Solution**:
```bash
# Check healthcheck manually
podman exec ds1-container /opt/opendj/bin/status --bindDN "cn=Directory Manager" --bindPassword password

# If command works but healthcheck fails, adjust timeout
healthcheck:
  test: ["CMD-SHELL", "..."]
  interval: 60s  # Increase from 30s
  timeout: 30s   # Increase from 10s
  start_period: 180s  # Increase from 120s
```

### Issue 7: podman-compose not found

**Symptom**:
```
bash: podman-compose: command not found
```

**Cause**: podman-compose not installed.

**Solution**:
```bash
# Install via package manager
sudo dnf install podman-compose  # RHEL/Fedora
sudo apt install podman-compose  # Ubuntu 22.04+

# Or install via pip
pip3 install podman-compose

# Verify
podman-compose --version

# Alternative: Use Docker Compose with Podman socket
sudo systemctl enable --now podman.socket
export DOCKER_HOST=unix:///run/podman/podman.sock
docker-compose up -d  # Uses Podman backend
```

### Issue 8: Images not found or pull failures

**Symptom**:
```
Error: error creating container: image not found
```

**Cause**: Different image registry configuration or credentials.

**Solution**:
```bash
# Check registry configuration
cat /etc/containers/registries.conf

# Pull image manually to test
podman pull docker.io/library/openjdk:17-slim

# If authentication needed
podman login docker.io
podman login registry.example.com
```

---

## Testing and Validation

### Test Suite

Run this comprehensive test after migration:

```bash
#!/bin/bash
# Podman Migration Validation Test Suite

set -e

echo "=== Podman Migration Validation ==="
echo

# Test 1: All containers running
echo "Test 1: Checking all containers are running..."
EXPECTED_CONTAINERS=8  # 4 DS + 2 IDM + 2 AM
RUNNING_CONTAINERS=$(podman ps --filter "name=ds\|idm\|am" --format "{{.Names}}" | wc -l)
if [ "$RUNNING_CONTAINERS" -eq "$EXPECTED_CONTAINERS" ]; then
  echo "✓ All $EXPECTED_CONTAINERS containers running"
else
  echo "✗ Expected $EXPECTED_CONTAINERS containers, found $RUNNING_CONTAINERS"
  podman ps
  exit 1
fi

# Test 2: Network connectivity
echo
echo "Test 2: Testing inter-container connectivity..."
if podman exec idm1-container ping -c 1 ds1-container > /dev/null 2>&1; then
  echo "✓ IDM1 can reach DS1"
else
  echo "✗ IDM1 cannot reach DS1"
  exit 1
fi

# Test 3: DS Replication
echo
echo "Test 3: Checking DS replication status..."
if podman exec ds1-container /opt/opendj/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt --script-friendly 2>/dev/null | grep -q "ds2-container"; then
  echo "✓ DS replication active"
else
  echo "✗ DS replication not working"
  exit 1
fi

# Test 4: IDM API
echo
echo "Test 4: Testing IDM API..."
if curl -k -s -u admin:admin https://localhost:8453/openidm/info/ping | grep -q "UP"; then
  echo "✓ IDM1 API responding"
else
  echo "✗ IDM1 API not responding"
  exit 1
fi

# Test 5: AM alive check
echo
echo "Test 5: Testing AM instances..."
if curl -s http://localhost:8100/am/isAlive.jsp 2>/dev/null | grep -q "true"; then
  echo "✓ AM1 alive"
else
  echo "✗ AM1 not responding"
  exit 1
fi

if curl -s http://localhost:8101/am/isAlive.jsp 2>/dev/null | grep -q "true"; then
  echo "✓ AM2 alive"
else
  echo "✗ AM2 not responding"
  exit 1
fi

# Test 6: Volume persistence
echo
echo "Test 6: Checking volume mounts..."
if podman exec ds1-container test -f /opt/opendj/db/.initialized; then
  echo "✓ DS1 data volume mounted and initialized"
else
  echo "✗ DS1 data volume issue"
  exit 1
fi

# Test 7: Healthchecks
echo
echo "Test 7: Checking container health..."
UNHEALTHY=$(podman ps --format "{{.Names}}\t{{.Status}}" | grep "unhealthy" | wc -l)
if [ "$UNHEALTHY" -eq 0 ]; then
  echo "✓ All containers healthy"
else
  echo "✗ $UNHEALTHY containers unhealthy"
  podman ps --format "table {{.Names}}\t{{.Status}}"
  exit 1
fi

echo
echo "=== All Tests Passed! ==="
echo "Podman migration successful!"
```

Save as `test-podman-migration.sh`, make executable, and run:

```bash
chmod +x test-podman-migration.sh
./test-podman-migration.sh
```

---

## Appendix: Command Reference

### Essential Podman Commands for Ping Deployment

```bash
# Container Management
podman ps                          # List running containers
podman ps -a                       # List all containers
podman logs -f ds1-container       # Follow logs
podman exec -it ds1-container bash # Interactive shell
podman stop ds1-container          # Stop container
podman start ds1-container         # Start container
podman restart ds1-container       # Restart container
podman rm ds1-container            # Remove container

# Image Management
podman images                      # List images
podman pull openjdk:17-slim        # Pull image
podman rmi openjdk:17-slim         # Remove image
podman image prune                 # Remove unused images

# Network Management
podman network ls                  # List networks
podman network inspect ping-network # Inspect network
podman network rm ping-network     # Remove network

# Volume Management
podman volume ls                   # List volumes
podman volume inspect my-volume    # Inspect volume
podman volume rm my-volume         # Remove volume
podman volume prune                # Remove unused volumes

# Compose Operations
podman-compose up -d               # Start services in background
podman-compose down                # Stop and remove services
podman-compose ps                  # List compose services
podman-compose logs -f ds1         # Follow service logs
podman-compose restart ds1         # Restart service

# System Commands
podman info                        # System information
podman system df                   # Disk usage
podman system prune -a             # Clean up everything
podman version                     # Version information

# Rootless Specific
podman unshare <command>           # Run command in user namespace
podman system migrate              # Migrate to new storage format

# Systemd Integration
podman generate systemd --name ds1-container --files --new  # Generate service file
systemctl --user enable podman-ds1-container.service        # Enable user service
systemctl --user start podman-ds1-container.service         # Start user service
```

### Alias for Docker Compatibility

If you want to keep using `docker` commands:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias docker=podman
alias docker-compose=podman-compose

# Reload shell
source ~/.bashrc
```

Now `docker ps` automatically runs `podman ps`.

---

## Summary Checklist

Before completing migration, verify:

- [ ] Podman and podman-compose installed
- [ ] User namespaces configured (for rootless)
- [ ] All scripts updated (docker → podman)
- [ ] Network created (`podman network create ping-network`)
- [ ] All containers deployed and running
- [ ] DS replication working
- [ ] IDM cluster formed
- [ ] AM site configured
- [ ] All health checks passing
- [ ] End-to-end authentication tested
- [ ] Documentation updated
- [ ] Backup taken of working system
- [ ] Systemd units generated (optional)

---

## Additional Resources

**Official Documentation**:
- Podman Documentation: https://docs.podman.io/
- Podman Compose: https://github.com/containers/podman-compose
- Podman vs Docker: https://docs.podman.io/en/latest/markdown/podman-docker.1.html

**Tutorials**:
- RHEL Podman Guide: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/
- Rootless Podman: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md

**Community**:
- Podman GitHub: https://github.com/containers/podman
- Podman Discussions: https://github.com/containers/podman/discussions

---

**Document Version**: 1.0
**Last Updated**: 2025-11-12
**Maintained By**: IAM Engineering Team

---

*End of Podman Migration Guide*
