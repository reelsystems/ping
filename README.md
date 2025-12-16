# Ping Identity Platform on Podman (RHEL)

Complete Podman-based deployment of the Ping Identity Platform stack, converted from ForgeOps Kubernetes deployment for RHEL systems.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Component Details](#component-details)
- [Configuration](#configuration)
- [DS Replication Setup](#ds-replication-setup)
- [PingGateway Integration](#pinggateway-integration)
- [IDM Connectors](#idm-connectors)
- [Network Architecture](#network-architecture)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Overview

This repository provides a complete Podman/Podman-Compose setup for the Ping Identity Platform, including:

- **PingDirectory (DS)** - LDAP directory server with multi-master replication
- **PingDirectory Proxy (DS-Proxy)** - LDAP proxy for AM configuration store
- **PingAccess Manager (AM)** - Access management and SSO
- **PingIDM (IDM)** - Identity management and provisioning
- **PingGateway (IG)** - Identity gateway and API gateway
- **Admin UI** - Web-based administration interface
- **Login UI** - Custom login interface
- **MySQL** - Repository database for IDM

## Prerequisites

### System Requirements

- **RHEL 8.x or 9.x** (or compatible: AlmaLinux, Rocky Linux)
- **Podman 4.0+** with Podman Compose
- **8GB RAM minimum** (16GB recommended)
- **50GB disk space** for containers and volumes
- **Root or sudo access** for initial setup

### Software Installation

```bash
# Install Podman and dependencies
sudo dnf install -y podman podman-compose podman-docker

# Enable Podman socket (optional, for Docker compatibility)
systemctl --user enable --now podman.socket

# Verify installation
podman --version
podman-compose --version

# Configure subuid/subgid for rootless mode (if running rootless)
grep $USER /etc/subuid /etc/subgid
# If not configured, add entries:
# echo "$USER:100000:65536" | sudo tee -a /etc/subuid
# echo "$USER:100000:65536" | sudo tee -a /etc/subgid
```

### Firewall Configuration

```bash
# Open required ports
sudo firewall-cmd --permanent --add-port=1389/tcp  # DS LDAP
sudo firewall-cmd --permanent --add-port=1636/tcp  # DS LDAPS
sudo firewall-cmd --permanent --add-port=8080-8086/tcp  # HTTP services
sudo firewall-cmd --permanent --add-port=8443-8448/tcp  # HTTPS services
sudo firewall-cmd --permanent --add-port=3306/tcp  # MySQL
sudo firewall-cmd --reload
```

## Quick Start

### 1. Clone or Navigate to Repository

```bash
cd /path/to/podman-ping
```

### 2. Build All Container Images

```bash
# Build all images from the compose directory
cd compose
podman-compose build

# Or build individual components:
podman build -t ping-ds ../ds
podman build -t ping-am ../am
podman build -t ping-idm ../idm
podman build -t ping-ig ../ig
podman build -t ping-admin-ui ../admin-ui
podman build -t ping-login-ui ../login-ui
podman build -t ping-ds-proxy ../ds-proxy
```

### 3. Start the Platform

```bash
# Start all services
podman-compose up -d

# View logs
podman-compose logs -f

# Check status
podman-compose ps
```

### 4. Verify Services

```bash
# Check health status of all containers
podman ps --format "table {{.Names}}\t{{.Status}}"

# Test individual services
curl http://localhost:8082/am/isAlive.jsp        # AM
curl -k https://localhost:8446/openidm/info/ping # IDM
curl http://localhost:8084/ig/status              # IG
curl http://localhost:8085/                       # Admin UI
curl http://localhost:8086/                       # Login UI
```

### 5. Access the Platform

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Access Manager | http://localhost:8082/am | amadmin / changeme |
| Identity Manager | https://localhost:8446/admin | openidm-admin / changeme |
| Admin UI | http://localhost:8085 | (uses AM/IDM auth) |
| Login UI | http://localhost:8086 | (authentication interface) |
| Identity Gateway | http://localhost:8084 | (no direct UI) |

## Component Details

### PingDirectory (DS)

**Purpose**: LDAP directory server storing user identities, groups, and AM runtime data.

**Key Features**:
- Multi-master replication between DS-1 and DS-2
- High availability and load distribution
- Stores CTS (Core Token Service) data for AM
- User store for authentication

**Ports**:
- 1389/1390: LDAP (DS-1/DS-2)
- 1636/1637: LDAPS (DS-1/DS-2)
- 4444/4445: Admin console (DS-1/DS-2)
- 8989/8990: Replication (DS-1/DS-2)

**Data Location**: `/opt/opendj/data`

**Default Credentials**:
- Bind DN: `cn=Directory Manager`
- Password: `changeme`

### PingDirectory Proxy (DS-Proxy)

**Purpose**: LDAP proxy distributing requests across DS instances for AM configuration store.

**Key Features**:
- Load balancing between DS-1 and DS-2
- Failover support
- Configuration persistence for AM

**Ports**:
- 1391: LDAP
- 1638: LDAPS
- 4446: Admin console

### PingAccess Manager (AM)

**Purpose**: Enterprise access management and single sign-on (SSO) solution.

**Key Features**:
- OAuth 2.0 / OpenID Connect provider
- SAML 2.0 identity provider
- Multi-factor authentication
- Session management via CTS in DS

**Ports**:
- 8082: HTTP
- 8445: HTTPS

**Dependencies**: DS-1, DS-2, DS-Proxy

**Configuration**:
- CTS Store: DS-1 and DS-2
- User Store: DS-1 and DS-2
- Config Store: DS-Proxy

### PingIDM (Identity Manager)

**Purpose**: Identity lifecycle management, provisioning, and governance.

**Key Features**:
- User provisioning to external systems
- Reconciliation and synchronization
- Workflow and approvals
- Connector framework for external systems

**Ports**:
- 8083: HTTP (redirects to HTTPS)
- 8446: HTTPS
- 8447: Mutual authentication

**Dependencies**: MySQL (repository), DS-1 (user store)

**Repository**: MySQL database `openidm`

### PingGateway (IG)

**Purpose**: Identity-aware API gateway and reverse proxy.

**Key Features**:
- Authentication/authorization enforcement
- Token validation and transformation
- Request/response transformation
- Integration with AM and IDM

**Ports**:
- 8084: HTTP
- 8448: HTTPS

**Dependencies**: AM, IDM, DS-1

### Admin UI

**Purpose**: Web-based administration interface for the platform.

**Features**:
- Unified management of AM and IDM
- User and policy management
- Visual configuration tools

**Port**: 8085

### Login UI

**Purpose**: Customizable authentication interface.

**Features**:
- Self-service registration
- Password reset
- Progressive profiling
- Integration with AM

**Port**: 8086

## Configuration

### Environment Variables

All configuration is managed through environment variables in the `podman-compose.yml` file.

#### Common Variables

```yaml
# Directory Server
DS_SERVER_ID: 1                          # Unique server ID for replication
BASE_DN: "dc=example,dc=com"             # Base DN for directory
ROOT_USER_DN: "cn=Directory Manager"     # Admin DN
ROOT_USER_PASSWORD: changeme             # Admin password

# Access Manager
AM_STORES_CTS_SERVERS: "ds-1:1389,ds-2:1389"
AM_ADMIN_PASSWORD: changeme

# Identity Manager
OPENIDM_ADMIN_USERNAME: openidm-admin
OPENIDM_ADMIN_PASSWORD: changeme
OPENIDM_REPO_HOST: ping-mysql
OPENIDM_REPO_DB: openidm
```

### Customizing Configuration

1. **Modify environment variables** in `compose/podman-compose.yml`
2. **Add custom configuration files** to component-specific `config/` directories
3. **Rebuild containers** if Containerfile changes are made
4. **Restart services** to apply changes

```bash
# After configuration changes
cd compose
podman-compose down
podman-compose up -d
```

### Volume Persistence

All data is persisted in named volumes:

```bash
# List volumes
podman volume ls

# Inspect a volume
podman volume inspect ds-data-1

# Backup a volume
podman run --rm -v ds-data-1:/data -v $(pwd):/backup alpine tar czf /backup/ds-data-1.tar.gz /data

# Restore a volume
podman run --rm -v ds-data-1:/data -v $(pwd):/backup alpine tar xzf /backup/ds-data-1.tar.gz -C /
```

## DS Replication Setup

The configuration includes two Directory Server instances (DS-1 and DS-2) configured for multi-master replication.

### Replication Architecture

```
DS-1 (172.28.0.20:8989) <----> DS-2 (172.28.0.21:8989)
        |                           |
        +------ Replication --------+
```

### Initial Setup

Replication is automatically configured when containers start. The setup includes:

1. **DS-1** initializes as the primary server
2. **DS-2** joins the topology by connecting to DS-1
3. Both servers replicate changes bidirectionally

### Manual Replication Configuration

If you need to configure replication manually:

```bash
# Enable replication on DS-1
podman exec -it ping-ds-1 /opt/opendj/bin/dsreplication enable \
  --host1 ds-1.ping.local --port1 4444 --bindDN1 "cn=Directory Manager" --bindPassword1 changeme \
  --replicationPort1 8989 \
  --host2 ds-2.ping.local --port2 4444 --bindDN2 "cn=Directory Manager" --bindPassword2 changeme \
  --replicationPort2 8989 \
  --baseDN "dc=example,dc=com" \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt

# Initialize replication from DS-1 to DS-2
podman exec -it ping-ds-1 /opt/opendj/bin/dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds-1.ping.local --portSource 4444 \
  --hostDestination ds-2.ping.local --portDestination 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt
```

### Verify Replication Status

```bash
# Check replication status
podman exec -it ping-ds-1 /opt/opendj/bin/dsreplication status \
  --hostname ds-1.ping.local --port 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt

# Monitor replication delay
podman exec -it ping-ds-1 /opt/opendj/bin/status \
  --bindDN "cn=Directory Manager" --bindPassword changeme \
  --useSSL --trustAll

# Test replication by adding a user to DS-1
podman exec -it ping-ds-1 /opt/opendj/bin/ldapadd \
  -h localhost -p 1389 -D "cn=Directory Manager" -w changeme <<EOF
dn: uid=testuser,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
cn: Test User
sn: User
uid: testuser
mail: testuser@example.com
userPassword: password123
EOF

# Verify user appears on DS-2
podman exec -it ping-ds-2 /opt/opendj/bin/ldapsearch \
  -h localhost -p 1389 -D "cn=Directory Manager" -w changeme \
  -b "dc=example,dc=com" "(uid=testuser)"
```

### Replication Troubleshooting

```bash
# View replication errors
podman exec -it ping-ds-1 tail -f /opt/opendj/logs/replication

# Reset replication (WARNING: data loss possible)
podman exec -it ping-ds-1 /opt/opendj/bin/dsreplication disable \
  --hostname ds-1.ping.local --port 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt

# Re-enable and reinitialize (see manual configuration above)
```

### Adding Additional DS Replicas

To add DS-3:

1. Add service definition in `podman-compose.yml`
2. Set `REPLICATION_PEER: ds-1.ping.local:8989`
3. Start the container: `podman-compose up -d ds-3`
4. Verify replication status

## PingGateway Integration

PingGateway acts as a reverse proxy and policy enforcement point for AM and IDM.

### Architecture

```
Client → IG (8084) → AM (8082) / IDM (8446) / DS (1389)
```

### Configuration Files

IG configuration is located in `ig/config/`. Key files:

- `config.json` - Main IG configuration
- `routes/` - Route definitions for different endpoints
- `scripts/` - Groovy scripts for custom logic

### Sample IG Route Configuration

Create `ig/config/routes/01-am-route.json`:

```json
{
  "name": "AccessManagerRoute",
  "condition": "${matches(request.uri.path, '^/am')}",
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "type": "HeaderFilter",
          "config": {
            "messageType": "REQUEST",
            "add": {
              "X-Forwarded-Proto": ["https"],
              "X-Forwarded-Host": ["${request.uri.host}"]
            }
          }
        }
      ],
      "handler": {
        "type": "ClientHandler",
        "config": {
          "targets": ["http://am.ping.local:8080"]
        }
      }
    }
  }
}
```

### IG OAuth 2.0 Token Validation

Create `ig/config/routes/02-protected-api.json`:

```json
{
  "name": "ProtectedAPIRoute",
  "condition": "${matches(request.uri.path, '^/api')}",
  "handler": {
    "type": "Chain",
    "config": {
      "filters": [
        {
          "type": "OAuth2ResourceServerFilter",
          "config": {
            "tokenIntrospectionEndpoint": "http://am.ping.local:8080/am/oauth2/introspect",
            "providerHandler": "ClientHandler",
            "clientId": "ig-client",
            "clientSecret": "password",
            "requireHttps": false,
            "cacheExpiration": "5 minutes"
          }
        }
      ],
      "handler": {
        "type": "Router",
        "config": {
          "defaultHandler": {
            "type": "ClientHandler",
            "config": {
              "targets": ["http://idm.ping.local:8080"]
            }
          }
        }
      }
    }
  }
}
```

### Testing IG Integration

```bash
# Direct AM access (bypassing IG)
curl http://localhost:8082/am/json/serverinfo/*

# Through IG
curl http://localhost:8084/am/json/serverinfo/*

# Protected API through IG (should return 401 without token)
curl http://localhost:8084/api/endpoint

# With valid OAuth token
TOKEN=$(curl -X POST "http://localhost:8082/am/oauth2/access_token" \
  -d "grant_type=password&username=demo&password=changeme&client_id=ig-client&client_secret=password&scope=openid" \
  | jq -r '.access_token')

curl -H "Authorization: Bearer $TOKEN" http://localhost:8084/api/endpoint
```

### IG Monitoring

```bash
# View IG logs
podman logs -f ping-ig

# Check IG status
curl http://localhost:8084/ig/status

# View active routes
curl http://localhost:8084/ig/routes
```

## IDM Connectors

PingIDM uses connectors to integrate with external systems. This deployment includes configurations for Active Directory and MySQL.

### Active Directory Connector

Configuration: `configs/ad-connector/provisioner.openicf-ad.json`

#### Prerequisites

1. Active Directory server accessible from the container network
2. Service account with appropriate permissions
3. LDAPS (port 636) enabled on AD

#### Configuration Steps

1. **Update AD connection details** in `configs/ad-connector/provisioner.openicf-ad.json`:

```json
{
  "configurationProperties": {
    "host": "ad.example.com",
    "port": 636,
    "ssl": true,
    "principal": "CN=Service Account,CN=Users,DC=example,DC=com",
    "credentials": {
      "$crypto": {
        "type": "x-simple-encryption",
        "value": {
          "data": "ENCRYPTED_PASSWORD"
        }
      }
    },
    "baseContexts": [
      "CN=Users,DC=example,DC=com"
    ]
  }
}
```

2. **Encrypt the service account password**:

```bash
# Access IDM container
podman exec -it ping-idm bash

# Encrypt password
cd /opt/openidm
./cli.sh encrypt changeme

# Copy the encrypted value to the configuration
```

3. **Test AD connectivity**:

```bash
# From IDM container
ldapsearch -H ldaps://ad.example.com:636 \
  -D "CN=Service Account,CN=Users,DC=example,DC=com" \
  -w password \
  -b "CN=Users,DC=example,DC=com" \
  "(objectClass=user)" cn sAMAccountName
```

4. **Restart IDM** to load the connector:

```bash
podman-compose restart idm
```

5. **Verify connector status**:

```bash
# Check connector configuration
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/config/provisioner.openicf/ad"

# Test connector
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/system/ad?_action=test" \
  -X POST \
  -H "Content-Type: application/json"
```

#### AD Synchronization

Create a sync mapping in `idm/config/sync.json`:

```json
{
  "mappings": [
    {
      "name": "systemAdAccount_managedUser",
      "source": "system/ad/account",
      "target": "managed/user",
      "properties": [
        {
          "source": "sAMAccountName",
          "target": "userName"
        },
        {
          "source": "givenName",
          "target": "givenName"
        },
        {
          "source": "sn",
          "target": "sn"
        },
        {
          "source": "mail",
          "target": "mail"
        }
      ],
      "policies": [
        {
          "situation": "ABSENT",
          "action": "CREATE"
        },
        {
          "situation": "FOUND",
          "action": "UPDATE"
        }
      ]
    }
  ]
}
```

Run reconciliation:

```bash
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/recon?_action=recon&mapping=systemAdAccount_managedUser" \
  -X POST \
  -H "Content-Type: application/json"

# Check reconciliation status
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/recon?_queryId=audit-recon-all"
```

### MySQL Connector (IDM Repository)

IDM uses MySQL as its repository database. The configuration is managed via environment variables in `podman-compose.yml`.

#### Repository Configuration

The MySQL database is automatically initialized with the schema from `configs/mysql/init.sql`.

**Connection Details**:
- Host: `ping-mysql`
- Port: `3306`
- Database: `openidm`
- Username: `openidm`
- Password: `openidm`

#### Accessing MySQL

```bash
# Access MySQL from host
podman exec -it ping-mysql mysql -u openidm -popenidm openidm

# View IDM tables
SHOW TABLES;

# Query managed users
SELECT objectid, fullobject FROM managedobjects WHERE objecttypes_id = (
  SELECT id FROM objecttypes WHERE objecttype = 'managed/user'
);

# View audit logs
SELECT * FROM auditauthentication ORDER BY activitydate DESC LIMIT 10;
```

#### MySQL Backup and Restore

```bash
# Backup
podman exec ping-mysql mysqldump -u openidm -popenidm openidm > idm-backup.sql

# Restore
cat idm-backup.sql | podman exec -i ping-mysql mysql -u openidm -popenidm openidm
```

### Custom Connectors

To add additional connectors (e.g., LDAP, REST, databases):

1. **Place connector JAR** in `idm/connectors/`
2. **Create provisioner configuration** in `idm/config/provisioner.openicf-<name>.json`
3. **Rebuild IDM container**:
   ```bash
   podman-compose build idm
   podman-compose up -d idm
   ```

## Network Architecture

### Container Network

All services run on a custom bridge network `ping-network` with static IP assignments:

| Service | IP Address | Hostname |
|---------|-----------|----------|
| MySQL | 172.28.0.10 | ping-mysql |
| DS-1 | 172.28.0.20 | ds-1.ping.local |
| DS-2 | 172.28.0.21 | ds-2.ping.local |
| DS-Proxy | 172.28.0.22 | ds-proxy.ping.local |
| AM | 172.28.0.30 | am.ping.local |
| IDM | 172.28.0.40 | idm.ping.local |
| IG | 172.28.0.50 | ig.ping.local |
| Admin UI | 172.28.0.60 | admin-ui.ping.local |
| Login UI | 172.28.0.61 | login-ui.ping.local |

### Service Communication

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ├──────────────────────────────────┐
       │                                  │
┌──────▼──────┐                    ┌──────▼──────┐
│  Login UI   │                    │  Admin UI   │
│   :8086     │                    │   :8085     │
└──────┬──────┘                    └──────┬──────┘
       │                                  │
       └──────────┬───────────────────────┘
                  │
           ┌──────▼──────┐
           │     IG      │
           │   :8084     │
           └──────┬──────┘
                  │
       ┌──────────┼──────────┐
       │          │          │
┌──────▼──────┐ ┌▼─────┐ ┌──▼──────┐
│     AM      │ │ IDM  │ │   DS-1  │
│   :8082     │ │:8446 │ │  :1389  │
└──────┬──────┘ └──┬───┘ └───┬─────┘
       │           │         │
       └────┬──────┤    ┌────┼─────┐
            │      │    │    │     │
     ┌──────▼──┐ ┌▼────▼┐ ┌─▼─────▼┐
     │DS-Proxy │ │MySQL│ │  DS-2   │
     │  :1391  │ │:3306│ │  :1390  │
     └─────────┘ └─────┘ └─────────┘
```

### DNS Resolution

Container hostnames are resolved via the bridge network's embedded DNS:

```bash
# Test DNS resolution from any container
podman exec ping-am nslookup ds-1.ping.local
podman exec ping-idm ping -c 3 am.ping.local
```

### External Access

Services are accessible from the host via port mappings:

```bash
# List all port mappings
podman-compose ps

# Access from host
curl http://localhost:8082/am/isAlive.jsp
```

### Firewall and SELinux

If services are not accessible:

```bash
# Check SELinux status
getenforce

# Set to permissive for testing (not recommended for production)
sudo setenforce 0

# Check firewall rules
sudo firewall-cmd --list-all

# Verify Podman networking
podman network inspect ping-network
```

## Troubleshooting

### Common Issues

#### Containers Fail to Start

```bash
# Check logs
podman-compose logs <service>

# Check resource usage
podman stats

# Inspect container
podman inspect <container-name>
```

#### Service Health Checks Failing

```bash
# Check health status
podman ps --format "table {{.Names}}\t{{.Status}}"

# Manually run health check command
podman exec <container-name> <health-check-command>

# Example for DS
podman exec ping-ds-1 /opt/opendj/bin/status --bindDN "cn=Directory Manager" --bindPassword changeme
```

#### Network Connectivity Issues

```bash
# Test inter-container connectivity
podman exec ping-am ping -c 3 ds-1.ping.local
podman exec ping-idm curl http://am.ping.local:8080/am/isAlive.jsp

# Check network configuration
podman network inspect ping-network

# Restart network stack
podman-compose down
podman-compose up -d
```

#### Volume Permission Issues

```bash
# Check volume ownership
podman volume inspect <volume-name>

# Fix permissions (example for DS)
podman exec -u root ping-ds-1 chown -R forgerock:root /opt/opendj/data
```

#### IDM Not Connecting to MySQL

```bash
# Verify MySQL is running
podman exec ping-mysql mysql -u openidm -popenidm -e "SELECT 1"

# Check IDM logs for connection errors
podman logs ping-idm | grep -i mysql

# Test MySQL connectivity from IDM container
podman exec ping-idm nc -zv ping-mysql 3306
```

#### AM Configuration Issues

```bash
# Check AM logs
podman logs ping-am

# Verify DS connectivity
podman exec ping-am ldapsearch -h ds-1.ping.local -p 1389 -D "cn=Directory Manager" -w changeme -b "dc=example,dc=com" "(objectClass=*)"

# Reset AM configuration (WARNING: destructive)
podman-compose stop am
podman volume rm am-data
podman-compose up -d am
```

### Debugging Tools

```bash
# Enter container shell
podman exec -it <container-name> bash

# View container processes
podman top <container-name>

# Check resource limits
podman inspect <container-name> | jq '.[0].HostConfig'

# Monitor logs in real-time
podman-compose logs -f --tail=100 <service>
```

### Performance Tuning

#### Increase Container Resources

Edit `podman-compose.yml` and add resource limits:

```yaml
services:
  am:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'
```

#### JVM Tuning

Adjust `JAVA_OPTS` in component environment variables:

```yaml
environment:
  JAVA_OPTS: "-Xms2g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

#### MySQL Tuning

Create `configs/mysql/my.cnf`:

```ini
[mysqld]
innodb_buffer_pool_size = 2G
max_connections = 500
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 256M
```

Mount in `podman-compose.yml`:

```yaml
volumes:
  - ../configs/mysql/my.cnf:/etc/mysql/conf.d/custom.cnf:ro
```

## Security Considerations

### Default Passwords

**CRITICAL**: Change all default passwords before production deployment!

```bash
# List of default passwords to change:
# - DS root user: changeme
# - AM admin: changeme
# - IDM admin: changeme
# - MySQL root: changeme
# - MySQL openidm: openidm
```

### SSL/TLS Certificates

This deployment uses self-signed certificates for development. **For production, you MUST use certificates from a trusted CA.**

#### Quick Setup (Development Only)

```bash
# Generate self-signed certs for testing
./scripts/setup-certificates.sh

# Copy to volume
podman volume create shared-certs
podman run --rm -v $(pwd)/certs:/src -v shared-certs:/dest alpine \
  sh -c 'cp -r /src/* /dest/ && chmod -R 755 /dest'
```

#### Production Certificate Setup

For production deployments with proper CA-signed certificates, see the comprehensive guide:

**[Production Certificate Management Guide](docs/PRODUCTION_CERTIFICATES.md)**

This guide covers:
- ✅ **Using bind mounts for certificate volumes** (recommended for production)
- ✅ Using Podman named volumes
- ✅ Service-specific certificate configuration (DS, AM, IDM, IG)
- ✅ Certificate format conversion (PEM, JKS, PKCS12)
- ✅ Secure password management with Podman secrets
- ✅ Zero-downtime certificate rotation procedures
- ✅ Certificate expiration monitoring
- ✅ SELinux configuration for RHEL systems

**Quick Example - Bind Mount Approach:**

```bash
# 1. Create certificate directory on host
sudo mkdir -p /opt/ping-certs/{ds,java}

# 2. Copy your production certificates
cp your-ca-signed-cert.pem /opt/ping-certs/ds/server-cert.pem
cp your-private-key.pem /opt/ping-certs/ds/server-key.pem
cp your-keystore.jks /opt/ping-certs/java/keystore.jks
cp your-truststore.jks /opt/ping-certs/java/truststore.jks

# 3. Set SELinux context (RHEL)
sudo semanage fcontext -a -t container_file_t "/opt/ping-certs(/.*)?"
sudo restorecon -Rv /opt/ping-certs

# 4. Update podman-compose.yml to use bind mount
# Replace: - shared-certs:/var/run/secrets/keys:ro
# With:    - /opt/ping-certs:/var/run/secrets/keys:ro,z
```

See the [full production certificate guide](docs/PRODUCTION_CERTIFICATES.md) for detailed instructions.

### Network Security

```bash
# Use internal network for inter-container communication
# Only expose necessary ports to host
# Consider using Podman secrets for sensitive data

# Create a secret
echo "changeme" | podman secret create ds-admin-password -

# Use in compose file
secrets:
  ds-admin-password:
    external: true
```

### SELinux

For production, keep SELinux enabled and configure appropriate contexts:

```bash
# Set correct SELinux contexts for volumes
sudo semanage fcontext -a -t container_file_t "/path/to/volumes(/.*)?"
sudo restorecon -Rv /path/to/volumes
```

### Firewall Rules

Restrict access to specific IPs:

```bash
# Allow only from specific subnet
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="8082" protocol="tcp" accept'
sudo firewall-cmd --reload
```

## Backup and Restore

### Full System Backup

```bash
#!/bin/bash
BACKUP_DIR="/backup/ping-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Stop services
cd compose
podman-compose down

# Backup volumes
for vol in ds-data-1 ds-data-2 am-data idm-data ig-data mysql-data; do
  podman run --rm -v $vol:/data -v $BACKUP_DIR:/backup alpine \
    tar czf /backup/$vol.tar.gz /data
done

# Backup configurations
cp -r ../configs $BACKUP_DIR/
cp -r ../compose $BACKUP_DIR/

# Restart services
podman-compose up -d
```

### Restore from Backup

```bash
#!/bin/bash
BACKUP_DIR="/backup/ping-20240115"

# Stop services
cd compose
podman-compose down

# Remove existing volumes
podman volume rm ds-data-1 ds-data-2 am-data idm-data ig-data mysql-data

# Restore volumes
for vol in ds-data-1 ds-data-2 am-data idm-data ig-data mysql-data; do
  podman volume create $vol
  podman run --rm -v $vol:/data -v $BACKUP_DIR:/backup alpine \
    tar xzf /backup/$vol.tar.gz -C /
done

# Restart services
podman-compose up -d
```

## Additional Resources

### Official Documentation

- [Ping Identity Documentation](https://docs.pingidentity.com/)
- [ForgeOps GitHub](https://github.com/ForgeRock/forgeops)
- [Podman Documentation](https://docs.podman.io/)

### Related Files

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architectural documentation
- [NOTES.md](NOTES.md) - Additional notes and context

### Support and Community

- Report issues in this repository
- Ping Identity Community Forums
- RHEL/Podman Community

## License

This deployment configuration is provided as-is for use with Ping Identity products. Consult Ping Identity licensing for product usage terms.

---

**Last Updated**: 2024-01-15
**Version**: 1.0.0
**Maintainer**: Platform Team
