# Ping Identity Platform - Deployment Summary

**Created**: 2025-11-04
**Version**: 7.5.2
**Environment**: Docker Compose (with K8s migration path)

---

## What Was Created

This document summarizes all the files and configurations created for your Ping Identity platform deployment.

### Documentation (7 Files)

1. **[README.md](README.md)** - Main project overview and quick start
2. **[architecture.md](architecture.md)** - Complete architecture with diagrams
3. **[WORKFLOW.md](WORKFLOW.md)** - Deployment workflow and tracking
4. **[checklist.md](checklist.md)** - Comprehensive deployment checklist
5. **[CONSIDERATIONS.md](CONSIDERATIONS.md)** - Production best practices
6. **[INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md)** - Step-by-step installation
7. **[k8s/README.md](k8s/README.md)** - Kubernetes migration roadmap

### Docker Compose Configurations

#### PingDS (4 Instances)

Each DS instance has:
- `.env` - Environment variables (ports, credentials, Java opts)
- `docker-compose.yml` - Container configuration
- `setup.sh` - Initialization script

**DS1** (Primary):
- Ports: 1636 (LDAPS), 4444 (Admin), 8080 (HTTP), 8443 (HTTPS), 8989 (Replication)
- IP: 172.20.0.11
- Files: [DS1/.env](DS1/.env), [DS1/docker-compose.yml](DS1/docker-compose.yml), [DS1/setup.sh](DS1/setup.sh)

**DS2** (Fallback):
- Ports: 1637, 4445, 8081, 8444, 8990
- IP: 172.20.0.12
- Files: [DS2/.env](DS2/.env), [DS2/docker-compose.yml](DS2/docker-compose.yml), [DS2/setup.sh](DS2/setup.sh)

**DS3** (Replica):
- Ports: 1638, 4446, 8082, 8445, 8991
- IP: 172.20.0.13
- Files: [DS3/.env](DS3/.env), [DS3/docker-compose.yml](DS3/docker-compose.yml), [DS3/setup.sh](DS3/setup.sh)

**DS4** (Replica):
- Ports: 1639, 4447, 8083, 8446, 8992
- IP: 172.20.0.14
- Files: [DS4/.env](DS4/.env), [DS4/docker-compose.yml](DS4/docker-compose.yml), [DS4/setup.sh](DS4/setup.sh)

#### PingIDM (2 Instances)

Each IDM instance has:
- `.env` - Environment variables (ports, credentials, repository config)
- `docker-compose.yml` - Container configuration
- `startup.sh` - Initialization and configuration script

**IDM1** (Primary):
- Ports: 8090 (HTTP), 8453 (HTTPS)
- IP: 172.20.0.21
- Repository: DS1 (primary), DS2 (secondary)
- Files: [IDM1/.env](IDM1/.env), [IDM1/docker-compose.yml](IDM1/docker-compose.yml), [IDM1/startup.sh](IDM1/startup.sh)

**IDM2** (Fallback):
- Ports: 8091 (HTTP), 8454 (HTTPS)
- IP: 172.20.0.22
- Repository: DS2 (primary), DS1 (secondary)
- Files: [IDM2/.env](IDM2/.env), [IDM2/docker-compose.yml](IDM2/docker-compose.yml), [IDM2/startup.sh](IDM2/startup.sh)

#### PingAM (2 Instances)

Each AM instance has:
- `.env` - Environment variables (ports, credentials, DS connections)
- `docker-compose.yml` - Tomcat container configuration
- `setenv.sh` - Tomcat environment setup

**AM1** (Primary):
- Ports: 8100 (HTTP)
- IP: 172.20.0.31
- DS Connections: DS1 (config, identity, CTS stores)
- Files: [AM1/.env](AM1/.env), [AM1/docker-compose.yml](AM1/docker-compose.yml), [AM1/setenv.sh](AM1/setenv.sh)

**AM2** (Fallback):
- Ports: 8101 (HTTP)
- IP: 172.20.0.32
- DS Connections: DS2 (config, identity, CTS stores)
- Files: [AM2/.env](AM2/.env), [AM2/docker-compose.yml](AM2/docker-compose.yml), [AM2/setenv.sh](AM2/setenv.sh)

### Shared Resources

**Installation Directory**:
- `shared/install/` - Where ForgeRock software should be extracted
- `shared/install/README.md` - Detailed extraction instructions

**Other Directories**:
- `shared/certs/` - SSL/TLS certificates
- `shared/scripts/` - Utility scripts
- `shared/backups/` - Backup storage

### Directory Structure

```
/home/thepackle/repos/ping/
├── README.md
├── architecture.md
├── WORKFLOW.md
├── checklist.md
├── CONSIDERATIONS.md
├── INSTALLATION-GUIDE.md
├── DEPLOYMENT-SUMMARY.md (this file)
│
├── DS1/
│   ├── .env
│   ├── docker-compose.yml
│   ├── setup.sh
│   ├── config/
│   ├── data/
│   └── logs/
│
├── DS2/ (same structure)
├── DS3/ (same structure)
├── DS4/ (same structure)
│
├── IDM1/
│   ├── .env
│   ├── docker-compose.yml
│   ├── startup.sh
│   ├── conf/
│   ├── connectors/
│   ├── script/
│   └── logs/
│
├── IDM2/ (same structure)
│
├── AM1/
│   ├── .env
│   ├── docker-compose.yml
│   ├── setenv.sh
│   ├── config/
│   └── logs/
│
├── AM2/ (same structure)
│
├── shared/
│   ├── install/
│   │   └── README.md
│   ├── certs/
│   ├── scripts/
│   └── backups/
│
└── k8s/
    ├── README.md (Kubernetes migration roadmap)
    ├── helm/
    ├── manifests/
    └── docs/
```

---

## Key Configuration Variables

### Passwords (Default - CHANGE THESE!)

All services use default passwords that **MUST** be changed before production:

```bash
# PingDS
ROOT_USER_PASSWORD=ChangeMe123!
DEPLOYMENT_ID_PASSWORD=ChangeMe123!

# PingIDM
ADMIN_PASSWORD=admin
REPO_BIND_PASSWORD=ChangeMe123!

# PingAM
ADMIN_PASSWORD=ChangeMe123!
CONFIG_STORE_PASSWORD=ChangeMe123!
AGENT_PASSWORD=ChangeMe123!
```

**To Change**: Edit each `.env` file in the respective service directory.

### Network Configuration

**Docker Network**: `ping-network` (172.20.0.0/16)

All containers use static IPs on this network for predictable connectivity.

**Create Network**:
```bash
docker network create --driver bridge --subnet 172.20.0.0/16 --gateway 172.20.0.1 ping-network
```

### Installation Paths

All Ping Identity software must be extracted to:

```bash
shared/install/opendj/      # PingDS 7.5.2
shared/install/openidm/     # PingIDM 7.5.2
shared/install/AM-7.5.2.war # PingAM 7.5.2
```

See [shared/install/README.md](shared/install/README.md) for detailed instructions.

---

## Quick Start Guide

### Prerequisites

1. **Install Docker and Docker Compose**:
   ```bash
   # Verify installation
   docker --version  # Should be 20.10.0+
   docker compose version  # Should be v2.0.0+
   ```

2. **Create Docker network**:
   ```bash
   docker network create --driver bridge --subnet 172.20.0.0/16 --gateway 172.20.0.1 ping-network
   ```

3. **Download and extract Ping software** to `shared/install/`:
   - See [README.md - Installation File Locations](README.md#installation-file-locations)

### Deployment Order

**Deploy in this order for proper dependencies**:

1. **Start DS1 and DS2**:
   ```bash
   cd DS1 && docker compose up -d && cd ..
   cd DS2 && docker compose up -d && cd ..

   # Wait for initialization (2-3 minutes)
   docker logs -f ds1-container  # Wait for "started successfully"
   ```

2. **Configure replication** between DS1 and DS2:
   ```bash
   # See INSTALLATION-GUIDE.md for detailed commands
   docker exec ds1-container /opt/opendj/bin/dsreplication enable ...
   ```

3. **Start DS3 and DS4** (optional):
   ```bash
   cd DS3 && docker compose up -d && cd ..
   cd DS4 && docker compose up -d && cd ..
   ```

4. **Start IDM1 and IDM2**:
   ```bash
   cd IDM1 && docker compose up -d && cd ..
   cd IDM2 && docker compose up -d && cd ..

   # Wait for "OpenIDM ready"
   docker logs -f idm1-container
   ```

5. **Configure DS for AM** (add AM schemas):
   ```bash
   # Run AM setup profiles on DS1
   # See INSTALLATION-GUIDE.md Phase 4.1
   ```

6. **Start AM1 and AM2**:
   ```bash
   cd AM1 && docker compose up -d && cd ..
   cd AM2 && docker compose up -d && cd ..

   # Wait for Tomcat startup (2-3 minutes)
   docker logs -f am1-container
   ```

7. **Complete AM configuration** via web UI:
   - Access: http://localhost:8100/am
   - Follow configuration wizard
   - See [INSTALLATION-GUIDE.md Phase 4](INSTALLATION-GUIDE.md#phase-4-pingam-deployment)

### Verification

```bash
# Check all containers are running
docker ps --filter "name=ds" --filter "name=idm" --filter "name=am"

# Access services
echo "PingDS Admin: https://localhost:8443"
echo "PingIDM Admin: https://localhost:8453/admin (admin/admin)"
echo "PingAM Console: http://localhost:8100/am/console (amadmin/password)"

# Check DS replication
docker exec ds1-container /opt/opendj/bin/dsreplication status \
  --adminUID admin --adminPassword ChangeMe123! \
  --hostname localhost --port 4444 --trustAll --no-prompt

# Check IDM health
curl -k -u admin:admin https://localhost:8453/openidm/info/ping

# Check AM health
curl http://localhost:8100/am/isAlive.jsp
```

---

## Important Environment Variables

### PingDS (.env)

```bash
# Container settings
CONTAINER_NAME=ds1-container
HOSTNAME=ds1-container
NETWORK_IP=172.20.0.11

# Ports (adjust for each instance)
HOST_LDAPS_PORT=1636
HOST_ADMIN_PORT=4444
HOST_HTTP_PORT=8080
HOST_HTTPS_PORT=8443
HOST_REPLICATION_PORT=8989

# DS configuration
SERVER_ID=ds1
DEPLOYMENT_ID=ping-demo-deployment
BASE_DN=dc=example,dc=com
ROOT_USER_DN=cn=Directory Manager
ROOT_USER_PASSWORD=ChangeMe123!

# Java options
JAVA_OPTS=-Xms2g -Xmx4g -XX:+UseG1GC

# Install path
INSTALL_PATH=../shared/install/opendj
```

### PingIDM (.env)

```bash
# Container settings
CONTAINER_NAME=idm1-container
HOSTNAME=idm1-container
NETWORK_IP=172.20.0.21

# Ports
HOST_HTTP_PORT=8090
HOST_HTTPS_PORT=8453

# IDM configuration
INSTANCE_ID=idm1
CLUSTER_ENABLED=true
CLUSTER_NAME=idm-cluster

# Repository (DS connection)
REPO_PRIMARY_HOST=ds1-container
REPO_PRIMARY_PORT=1636
REPO_SECONDARY_HOST=ds2-container
REPO_SECONDARY_PORT=1636
REPO_BIND_DN=cn=Directory Manager
REPO_BIND_PASSWORD=ChangeMe123!

# Java options
JAVA_OPTS=-Xms2g -Xmx4g -XX:+UseG1GC

# External connectors (optional)
MSSQL1_HOST=your-sql-server1.example.com
AD_HOST=your-ad-server.example.com
```

### PingAM (.env)

```bash
# Container settings
CONTAINER_NAME=am1-container
HOSTNAME=am1-container
NETWORK_IP=172.20.0.31

# Ports
HOST_HTTP_PORT=8100

# Tomcat
CATALINA_OPTS=-Xms4g -Xmx4g -XX:+UseG1GC

# AM configuration
SITE_NAME=ping-site
COOKIE_DOMAIN=.example.com

# DS connections (config store)
CONFIG_STORE_HOST=ds1-container
CONFIG_STORE_PORT=1636
CONFIG_STORE_SUFFIX=ou=am-config,dc=example,dc=com
CONFIG_STORE_PASSWORD=ChangeMe123!

# DS connections (identity store)
IDENTITY_STORE_HOST=ds1-container
IDENTITY_STORE_SUFFIX=ou=identities,dc=example,dc=com

# DS connections (CTS store)
CTS_STORE_HOST=ds1-container
CTS_STORE_SUFFIX=ou=tokens,dc=example,dc=com

# Admin credentials
ADMIN_USERNAME=amadmin
ADMIN_PASSWORD=ChangeMe123!
```

---

## Common Operations

### Start All Services

```bash
# Start DS instances
for ds in DS1 DS2 DS3 DS4; do
  cd $ds && docker compose up -d && cd ..
done

# Start IDM instances
for idm in IDM1 IDM2; do
  cd $idm && docker compose up -d && cd ..
done

# Start AM instances
for am in AM1 AM2; do
  cd $am && docker compose up -d && cd ..
done
```

### Stop All Services

```bash
# Stop in reverse order
for am in AM1 AM2; do
  cd $am && docker compose down && cd ..
done

for idm in IDM1 IDM2; do
  cd $idm && docker compose down && cd ..
done

for ds in DS1 DS2 DS3 DS4; do
  cd $ds && docker compose down && cd ..
done
```

### View Logs

```bash
# Follow logs for a specific service
docker logs -f ds1-container
docker logs -f idm1-container
docker logs -f am1-container

# View logs for all DS instances
docker logs ds1-container
docker logs ds2-container
docker logs ds3-container
docker logs ds4-container
```

### Restart a Service

```bash
# Restart single service
cd DS1 && docker compose restart && cd ..

# Or restart container directly
docker restart ds1-container
```

### Update Configuration

```bash
# Edit .env file
vi DS1/.env

# Recreate container with new configuration
cd DS1 && docker compose up -d --force-recreate && cd ..
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs <container-name>

# Common issues:
# 1. Port already in use - change HOST_*_PORT in .env
# 2. Install files not found - verify shared/install/ contents
# 3. Network not created - run: docker network create ping-network
```

### Cannot Connect to Service

```bash
# Check container is running
docker ps | grep <container-name>

# Check network connectivity
docker exec idm1-container ping ds1-container

# Check port is listening
docker exec ds1-container netstat -tuln | grep 1636
```

### Configuration Not Applied

```bash
# Recreate container to pick up .env changes
cd DS1 && docker compose up -d --force-recreate && cd ..

# Or rebuild and recreate
cd DS1 && docker compose up -d --build --force-recreate && cd ..
```

---

## Next Steps

1. **Review Documentation**:
   - Start with [README.md](README.md)
   - Read [architecture.md](architecture.md) for design details
   - Follow [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md) for deployment

2. **Download Software**:
   - Access ForgeRock Backstage
   - Download PingDS, PingIDM, PingAM 7.5.2
   - Extract to `shared/install/`

3. **Customize Configuration**:
   - Edit `.env` files to change default passwords
   - Update `BASE_DN` if not using `dc=example,dc=com`
   - Configure external system connections (SQL, AD)

4. **Deploy**:
   - Follow [Quick Start Guide](#quick-start-guide) above
   - Or follow detailed [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md)

5. **Test**:
   - Create test users in DS
   - Configure authentication in AM
   - Set up reconciliation in IDM
   - Perform end-to-end testing

6. **Plan for Kubernetes** (Future):
   - Review [k8s/README.md](k8s/README.md)
   - Set up K8s development cluster
   - Begin migration planning

---

## Support

### Internal Documentation

- [README.md](README.md) - Project overview
- [architecture.md](architecture.md) - Architecture details
- [WORKFLOW.md](WORKFLOW.md) - Deployment workflow
- [checklist.md](checklist.md) - Deployment checklist
- [CONSIDERATIONS.md](CONSIDERATIONS.md) - Best practices
- [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md) - Step-by-step guide
- [k8s/README.md](k8s/README.md) - Kubernetes roadmap

### External Resources

- **Ping Identity Docs**: https://docs.pingidentity.com
- **Community Forum**: https://support.pingidentity.com/s/
- **ForgeRock Backstage**: https://backstage.forgerock.com

---

**Document Version**: 1.0
**Last Updated**: 2025-11-04
**Author**: IAM Engineering Team

---

*End of Deployment Summary*
