# Ping Identity Platform Deployment Checklist

**Project**: Ping Identity Demo Environment - Version 7.5.2
**Target Scale**: ~5,000 users
**Created**: 2025-11-04

---

## Table of Contents

1. [Pre-Deployment Requirements](#pre-deployment-requirements)
2. [Infrastructure Requirements](#infrastructure-requirements)
3. [Software Requirements](#software-requirements)
4. [Network Requirements](#network-requirements)
5. [Security Requirements](#security-requirements)
6. [PingDS Deployment Checklist](#pingds-deployment-checklist)
7. [PingIDM Deployment Checklist](#pingidm-deployment-checklist)
8. [PingAM Deployment Checklist](#pingam-deployment-checklist)
9. [Integration & Testing Checklist](#integration--testing-checklist)
10. [Production Readiness Checklist](#production-readiness-checklist)

---

## Pre-Deployment Requirements

### Account & Access

- [ ] Ping Identity Support Portal account created
- [ ] Access to Ping Identity Backstage for downloads
- [ ] License files obtained (if required for evaluation/production)
- [ ] Access credentials for external systems (SQL, AD)
- [ ] Administrative access to deployment server
- [ ] Git repository created (optional, for configuration versioning)

### Documentation Review

- [ ] Read [architecture.md](architecture.md) - Platform architecture
- [ ] Read [WORKFLOW.md](WORKFLOW.md) - Deployment workflow
- [ ] Read this checklist completely before starting
- [ ] Review Ping Identity 7.5.2 release notes for known issues
- [ ] Bookmark Ping Identity documentation portal

### Knowledge Requirements

**PingDS**:
- [ ] Understand LDAP basics (entries, attributes, DN structure)
- [ ] Familiarity with replication concepts
- [ ] Knowledge of LDIF format
- [ ] Basic understanding of schema and objectClasses

**PingIDM**:
- [ ] Understanding of identity lifecycle management
- [ ] Familiarity with JSON configuration
- [ ] Knowledge of reconciliation and synchronization concepts
- [ ] Basic understanding of connectors

**PingAM**:
- [ ] Understanding of authentication vs. authorization
- [ ] Familiarity with SSO concepts
- [ ] Knowledge of OAuth2 and SAML (basic)
- [ ] Understanding of session management

**General**:
- [ ] Docker fundamentals (containers, volumes, networks)
- [ ] Linux command line proficiency
- [ ] Basic networking (ports, protocols, DNS)
- [ ] SSL/TLS certificate concepts

---

## Infrastructure Requirements

### Hardware Requirements (Minimum for Demo)

**Host Server**:
- [ ] CPU: 8 cores or more (16 cores recommended)
- [ ] RAM: 16 GB minimum (32 GB recommended)
- [ ] Disk: 100 GB available (SSD strongly recommended)
- [ ] Network: 1 Gbps network interface

**Disk Space Breakdown**:
- [ ] Operating system: 20 GB
- [ ] Docker images: 10 GB
- [ ] PingDS data (4 instances): 20 GB
- [ ] PingIDM data: 5 GB
- [ ] PingAM data: 5 GB
- [ ] Logs: 10 GB
- [ ] Backups: 20 GB
- [ ] Working space: 10 GB

### Operating System Requirements

- [ ] Linux distribution (Ubuntu 20.04+ / RHEL 8+ / CentOS 8+)
- [ ] Kernel version 3.10 or higher
- [ ] 64-bit architecture
- [ ] User account with sudo privileges
- [ ] Filesystem: ext4 or xfs recommended

**OS Configuration**:
- [ ] File descriptor limits increased (ulimit -n 65536)
- [ ] Disable SELinux or configure appropriate policies
- [ ] Firewall configured to allow required ports
- [ ] Time synchronization enabled (NTP/chrony)
- [ ] Hostname properly configured
- [ ] DNS or /etc/hosts configured for name resolution

### Java Requirements

- [ ] Java 11.0.6+ or Java 17.0.3+ installed
- [ ] JAVA_HOME environment variable set
- [ ] Java version verified: `java -version`
- [ ] OpenJDK or Oracle JDK (both supported)

**Java Configuration**:
- [ ] Java trust store accessible
- [ ] Java cryptography extension (JCE) unlimited strength installed
- [ ] Verify Java path: `which java`

### Docker Requirements

- [ ] Docker Engine 20.10.0 or later installed
- [ ] Docker Compose v2.0.0 or later installed
- [ ] Docker service running: `systemctl status docker`
- [ ] User added to docker group: `usermod -aG docker $USER`
- [ ] Docker daemon configuration reviewed
- [ ] Docker storage driver configured (overlay2 recommended)
- [ ] Test Docker: `docker run hello-world`

**Docker Configuration**:
- [ ] Docker daemon logging configured
- [ ] Docker resource limits set (if needed)
- [ ] Docker registry access configured (if using private registry)

---

## Software Requirements

### Required Software Downloads

**PingDS 7.5.2**:
- [ ] Download PingDS-7.5.2.zip from Backstage
- [ ] Verify SHA256 checksum
- [ ] Extract to working directory
- [ ] Verify extraction: Check for `bin/`, `lib/`, `setup` directories
- [ ] File size verification: ~200 MB

**PingIDM 7.5.2**:
- [ ] Download IDM-7.5.2.zip from Backstage
- [ ] Verify SHA256 checksum
- [ ] Extract to working directory
- [ ] Verify extraction: Check for `bin/`, `conf/`, `connectors/` directories
- [ ] File size verification: ~300 MB

**PingAM 7.5.2**:
- [ ] Download AM-7.5.2.zip from Backstage
- [ ] Verify SHA256 checksum
- [ ] Extract to working directory
- [ ] Verify extraction: Check for `AM-7.5.2.war` or standalone distribution
- [ ] File size verification: ~250 MB

**Additional Components**:
- [ ] Microsoft SQL Server JDBC driver (if using SQL connectors)
  - Download: mssql-jdbc-X.X.X.jre11.jar
  - URL: https://docs.microsoft.com/en-us/sql/connect/jdbc/
- [ ] Any custom LDAP schemas required
- [ ] SSL certificates (or tools to generate self-signed)

### Optional Software

- [ ] Apache Directory Studio (LDAP browser)
- [ ] Postman or curl (for API testing)
- [ ] JMeter (for load testing)
- [ ] Prometheus + Grafana (for monitoring)
- [ ] Git (for configuration version control)

---

## Network Requirements

### Port Availability

**Verify these ports are available on the host**:

**PingDS**:
- [ ] 1636 (DS1 LDAPS)
- [ ] 1637 (DS2 LDAPS)
- [ ] 1638 (DS3 LDAPS)
- [ ] 1639 (DS4 LDAPS)
- [ ] 4444-4447 (DS admin ports)
- [ ] 8080-8083 (DS HTTP)
- [ ] 8443-8446 (DS HTTPS)
- [ ] 8989-8992 (DS replication ports)

**PingIDM**:
- [ ] 8090 (IDM1 HTTP)
- [ ] 8091 (IDM2 HTTP)
- [ ] 8453 (IDM1 HTTPS)
- [ ] 8454 (IDM2 HTTPS)

**PingAM**:
- [ ] 8100 (AM1 HTTP)
- [ ] 8101 (AM2 HTTP)

**Verification Command**:
```bash
# Check if ports are in use
netstat -tuln | grep -E ':(1636|1637|1638|1639|4444|4445|4446|4447|8080|8081|8082|8083|8090|8091|8100|8101|8443|8444|8445|8446|8453|8454)'
```

### Firewall Configuration

**Host Firewall (iptables/firewalld)**:
- [ ] Allow incoming connections on all required ports (if external access needed)
- [ ] Allow Docker container-to-container communication
- [ ] Allow connections to external systems (SQL, AD)

**Commands for firewalld**:
```bash
# PingDS ports
firewall-cmd --permanent --add-port=1636-1639/tcp
firewall-cmd --permanent --add-port=4444-4447/tcp
firewall-cmd --permanent --add-port=8080-8083/tcp
firewall-cmd --permanent --add-port=8443-8446/tcp

# PingIDM ports
firewall-cmd --permanent --add-port=8090-8091/tcp
firewall-cmd --permanent --add-port=8453-8454/tcp

# PingAM ports
firewall-cmd --permanent --add-port=8100-8101/tcp

# Reload firewall
firewall-cmd --reload
```

### DNS/Hostname Configuration

- [ ] Hostname resolution configured
- [ ] /etc/hosts updated with container names (if not using DNS)
- [ ] FQDN resolution tested
- [ ] Reverse DNS lookup working (if required)

**Example /etc/hosts entries**:
```
172.20.0.11  ds1-container ds1
172.20.0.12  ds2-container ds2
172.20.0.13  ds3-container ds3
172.20.0.14  ds4-container ds4
172.20.0.21  idm1-container idm1
172.20.0.22  idm2-container idm2
172.20.0.31  am1-container am1
172.20.0.32  am2-container am2
```

### External Connectivity

**Microsoft SQL Databases**:
- [ ] Network connectivity to SQL Server 1
- [ ] Network connectivity to SQL Server 2
- [ ] Port 1433 (default SQL Server port) accessible
- [ ] SQL Server authentication configured
- [ ] Service account credentials obtained
- [ ] Test connection: `telnet sqlserver1 1433`

**Active Directory**:
- [ ] Network connectivity to AD domain controller
- [ ] Port 636 (LDAPS) accessible or port 389 (LDAP)
- [ ] AD service account credentials obtained
- [ ] AD base DN identified (e.g., DC=corp,DC=example,DC=com)
- [ ] Test connection: `telnet ad.example.com 636`

---

## Security Requirements

### Certificates

**Self-Signed Certificates (Demo)**:
- [ ] Generate CA certificate
- [ ] Generate server certificates for each DS instance
- [ ] Generate server certificates for IDM instances
- [ ] Generate server certificates for AM instances
- [ ] Import CA certificate to Java trust store
- [ ] Certificate validity period sufficient (365+ days)

**Commands**:
```bash
# Generate CA certificate
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -out ca-cert.pem

# Generate server certificate (example for DS1)
openssl genrsa -out ds1-key.pem 2048
openssl req -new -key ds1-key.pem -out ds1-csr.pem
openssl x509 -req -in ds1-csr.pem -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out ds1-cert.pem -days 365
```

**Production Certificates**:
- [ ] CA-signed certificates obtained
- [ ] Certificate chain complete
- [ ] Private keys secured
- [ ] Certificate expiration monitoring configured

### Credentials Management

- [ ] Directory Manager password defined (PingDS)
- [ ] Replication admin password defined (PingDS)
- [ ] IDM admin password defined (PingIDM)
- [ ] amadmin password defined (PingAM)
- [ ] SQL service account credentials secured
- [ ] AD service account credentials secured
- [ ] Password complexity requirements met
- [ ] Credentials documented in secure location (password manager)

**Security Best Practices**:
- [ ] Passwords not stored in plain text
- [ ] Passwords not committed to version control
- [ ] Use environment variables or secrets management
- [ ] Rotate credentials post-deployment

### Access Control

- [ ] Linux file permissions set correctly (chmod 600 for sensitive files)
- [ ] Docker volumes have appropriate permissions
- [ ] Only necessary ports exposed to external network
- [ ] Admin consoles accessible only from trusted networks (if production)
- [ ] SSH access secured with key-based authentication

---

## PingDS Deployment Checklist

### Phase 1: Directory Structure Setup

- [ ] Create DS1 directory: `mkdir -p DS1/{config,data,logs}`
- [ ] Create DS2 directory: `mkdir -p DS2/{config,data,logs}`
- [ ] Create DS3 directory: `mkdir -p DS3/{config,data,logs}`
- [ ] Create DS4 directory: `mkdir -p DS4/{config,data,logs}`
- [ ] Create shared certs directory: `mkdir -p shared/certs`
- [ ] Set proper ownership: `chown -R $USER:$USER DS*`

### Phase 2: DS1 Deployment (Primary)

**Container Setup**:
- [ ] Create Dockerfile for DS1
- [ ] Create docker-compose.yml for DS1
- [ ] Configure volume mounts (data, logs, config)
- [ ] Set environment variables
- [ ] Configure network: ping-network
- [ ] Assign static IP: 172.20.0.11

**DS1 Configuration**:
- [ ] Setup profile: ds-evaluation (initial)
- [ ] Base DN: dc=example,dc=com (or custom)
- [ ] Root user DN: cn=Directory Manager
- [ ] Root user password: [SECURE_PASSWORD]
- [ ] LDAP port: 1636 (LDAPS)
- [ ] Admin port: 4444
- [ ] HTTP port: 8080
- [ ] HTTPS port: 8443
- [ ] Replication port: 8989

**DS1 Deployment**:
- [ ] Build Docker image: `docker-compose build`
- [ ] Start container: `docker-compose up -d`
- [ ] Check logs: `docker logs -f ds1-container`
- [ ] Verify service: `docker exec ds1-container status`
- [ ] Test LDAP connection: `ldapsearch -h localhost -p 1636 -Z -X -D "cn=Directory Manager" -w password -b "dc=example,dc=com" "(objectClass=*)"`
- [ ] Access admin console: https://localhost:8443
- [ ] Create test user entry
- [ ] Verify test user searchable

**DS1 Post-Deployment**:
- [ ] Configure backup strategy
- [ ] Enable audit logging
- [ ] Configure password policy
- [ ] Review default indexes
- [ ] Document admin credentials

### Phase 3: DS2 Deployment (Fallback)

**Container Setup**:
- [ ] Create Dockerfile for DS2 (similar to DS1)
- [ ] Create docker-compose.yml for DS2
- [ ] Configure volume mounts
- [ ] Set environment variables
- [ ] Configure network: ping-network
- [ ] Assign static IP: 172.20.0.12

**DS2 Configuration**:
- [ ] Setup profile: ds-evaluation
- [ ] Base DN: dc=example,dc=com (MUST match DS1)
- [ ] Root user DN: cn=Directory Manager
- [ ] Root user password: [SAME_AS_DS1]
- [ ] LDAP port: 1637
- [ ] Admin port: 4445
- [ ] HTTP port: 8081
- [ ] HTTPS port: 8444
- [ ] Replication port: 8990

**DS2 Deployment**:
- [ ] Build Docker image
- [ ] Start container: `docker-compose up -d`
- [ ] Check logs: `docker logs -f ds2-container`
- [ ] Verify service running independently
- [ ] Test LDAP connection on port 1637
- [ ] Access admin console: https://localhost:8444

### Phase 4: Replication Configuration (DS1 ↔ DS2)

**Enable Replication**:
- [ ] Execute dsreplication enable command
- [ ] Specify host1: ds1-container, port1: 4444
- [ ] Specify host2: ds2-container, port2: 4445
- [ ] Set replication admin credentials
- [ ] Configure base DN: dc=example,dc=com
- [ ] Trust all certificates (demo) or configure proper trust

**Command**:
```bash
docker exec ds1-container dsreplication enable \
  --host1 ds1-container --port1 4444 --bindDN1 "cn=Directory Manager" \
  --bindPassword1 password --replicationPort1 8989 \
  --host2 ds2-container --port2 4445 --bindDN2 "cn=Directory Manager" \
  --bindPassword2 password --replicationPort2 8990 \
  --adminUID admin --adminPassword password \
  --baseDN "dc=example,dc=com" --trustAll --no-prompt
```

**Initialize Replication**:
- [ ] Execute dsreplication initialize command
- [ ] Source: DS1
- [ ] Destination: DS2
- [ ] Verify initialization completes

**Command**:
```bash
docker exec ds1-container dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds1-container --portSource 4444 \
  --hostDestination ds2-container --portDestination 4445 \
  --adminUID admin --adminPassword password \
  --trustAll --no-prompt
```

**Verify Replication**:
- [ ] Check replication status: `dsreplication status`
- [ ] Verify both servers listed
- [ ] Confirm replication lag < 100ms
- [ ] Create test entry on DS1, verify on DS2
- [ ] Create test entry on DS2, verify on DS1
- [ ] Delete test entry on DS1, verify deleted on DS2

**Command**:
```bash
docker exec ds1-container dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt
```

### Phase 5: DS3 and DS4 Deployment (Additional Replicas)

**DS3 Configuration**:
- [ ] Create Dockerfile and docker-compose.yml
- [ ] Base DN: dc=example,dc=com
- [ ] LDAP port: 1638
- [ ] Admin port: 4446
- [ ] HTTP port: 8082
- [ ] HTTPS port: 8445
- [ ] Replication port: 8991
- [ ] Static IP: 172.20.0.13

**DS4 Configuration**:
- [ ] Create Dockerfile and docker-compose.yml
- [ ] Base DN: dc=example,dc=com
- [ ] LDAP port: 1639
- [ ] Admin port: 4447
- [ ] HTTP port: 8083
- [ ] HTTPS port: 8446
- [ ] Replication port: 8992
- [ ] Static IP: 172.20.0.14

**Deploy DS3**:
- [ ] Start container
- [ ] Verify service running
- [ ] Add to replication topology (dsreplication enable)
- [ ] Initialize replication from DS1
- [ ] Verify replication status

**Deploy DS4**:
- [ ] Start container
- [ ] Verify service running
- [ ] Add to replication topology (dsreplication enable)
- [ ] Initialize replication from DS1
- [ ] Verify replication status

**Verify 4-Way Replication**:
- [ ] Check dsreplication status shows all 4 servers
- [ ] Test data replication to all instances
- [ ] Verify replication lag acceptable on all links
- [ ] Monitor replication errors in logs

### Phase 6: Configure DS for PingAM Integration

**AM Identity Store Setup**:
- [ ] Run setup with `am-identity-store` profile on DS1
- [ ] Create base DN: ou=identities,dc=example,dc=com
- [ ] Verify AM schema extensions added
- [ ] Create AM service account: uid=amldapuser,ou=identities,dc=example,dc=com
- [ ] Set service account password
- [ ] Grant appropriate access rights

**AM Config Store Setup**:
- [ ] Run setup with `am-config-store` profile on DS1
- [ ] Create base DN: ou=am-config,dc=example,dc=com
- [ ] Verify config store schema
- [ ] Create AM admin bind account
- [ ] Set appropriate ACIs

**AM CTS Store Setup**:
- [ ] Run setup with `am-cts` profile on DS1
- [ ] Create base DN: ou=tokens,dc=example,dc=com
- [ ] Configure CTS schema
- [ ] Optimize CTS indexes for performance
- [ ] Configure CTS token expiration

**Verify AM Setup**:
- [ ] Check schema replication to all DS instances
- [ ] Verify AM service accounts accessible
- [ ] Test bind as AM service account
- [ ] Review DS access logs for AM setup

**Commands**:
```bash
# Identity store setup
docker exec ds1-container setup \
  --serverId ds1 \
  --deploymentId amidentity \
  --deploymentIdPassword password \
  --rootUserDN "cn=Directory Manager" \
  --rootUserPassword password \
  --hostname ds1-container \
  --ldapPort 1636 \
  --enableStartTls \
  --ldapsPort 1636 \
  --httpsPort 8443 \
  --adminConnectorPort 4444 \
  --replicationPort 8989 \
  --profile am-identity-store \
  --set am-identity-store/amIdentityStoreAdminPassword:password \
  --acceptLicense

# Config store setup
docker exec ds1-container setup \
  --serverId ds1 \
  --deploymentId amconfig \
  --deploymentIdPassword password \
  --rootUserDN "cn=Directory Manager" \
  --rootUserPassword password \
  --hostname ds1-container \
  --ldapPort 1636 \
  --enableStartTls \
  --ldapsPort 1636 \
  --httpsPort 8443 \
  --adminConnectorPort 4444 \
  --replicationPort 8989 \
  --profile am-config-store \
  --set am-config-store/amConfigStoreAdminPassword:password \
  --acceptLicense
```

---

## PingIDM Deployment Checklist

### Phase 1: IDM Directory Structure

- [ ] Create IDM1 directory: `mkdir -p IDM1/{conf,connectors,script,logs}`
- [ ] Create IDM2 directory: `mkdir -p IDM2/{conf,connectors,script,logs}`
- [ ] Copy IDM distribution to IDM1 directory
- [ ] Copy IDM distribution to IDM2 directory
- [ ] Set proper ownership

### Phase 2: IDM1 Deployment (Primary)

**Container Setup**:
- [ ] Create Dockerfile for IDM1
- [ ] Create docker-compose.yml for IDM1
- [ ] Configure volume mounts (conf, connectors, script, logs)
- [ ] Set environment variables (JAVA_OPTS, IDM_ENVCONFIG_DIRS)
- [ ] Configure network: ping-network
- [ ] Assign static IP: 172.20.0.21

**IDM1 Configuration Files**:

**boot.properties**:
- [ ] Set openidm.host=idm1-container
- [ ] Set openidm.port.http=8090
- [ ] Set openidm.port.https=8453
- [ ] Set openidm.port.mutualauth=8444
- [ ] Configure cluster settings

**repo.ds.json** (Repository Configuration):
- [ ] Configure primary LDAP server: ds1-container:1636
- [ ] Configure secondary LDAP server: ds2-container:1637
- [ ] Set bind DN for repository access
- [ ] Set bind password (encrypted)
- [ ] Configure connection pool settings
- [ ] Enable SSL/TLS

**Example repo.ds.json**:
```json
{
  "dbType": "DS",
  "useDataSource": "default",
  "connectionTimeout": 30000,
  "ldapConnectionFactories": [
    {
      "primaryLdapServers": [
        {
          "hostname": "ds1-container",
          "port": 1636,
          "sslCertAlias": "ds-cert"
        }
      ],
      "secondaryLdapServers": [
        {
          "hostname": "ds2-container",
          "port": 1637,
          "sslCertAlias": "ds-cert"
        }
      ]
    }
  ],
  "security": {
    "trustManager": "jvm",
    "keyManager": "jvm"
  },
  "authentication": {
    "simple": {
      "bindDn": "uid=idm,ou=admins,dc=example,dc=com",
      "bindPassword": "&{password}"
    }
  }
}
```

**cluster.json** (Clustering Configuration):
- [ ] Enable clustering: `"enabled": true`
- [ ] Set cluster name: "idm-cluster"
- [ ] Configure instance ID: "idm1"
- [ ] Configure repository-based clustering

**IDM1 Deployment**:
- [ ] Build Docker image
- [ ] Start container: `docker-compose up -d`
- [ ] Check logs: `docker logs -f idm1-container`
- [ ] Wait for startup message: "OpenIDM ready"
- [ ] Access admin console: https://localhost:8453/admin
- [ ] Login: admin/admin (default)
- [ ] Verify repository connection in Dashboard
- [ ] Check health endpoint: `curl -k https://localhost:8453/openidm/info/ping`

**IDM1 Post-Deployment**:
- [ ] Change default admin password
- [ ] Configure audit logging
- [ ] Review security settings
- [ ] Enable monitoring endpoints

### Phase 3: IDM2 Deployment (Fallback)

**Container Setup**:
- [ ] Create Dockerfile for IDM2 (similar to IDM1)
- [ ] Create docker-compose.yml for IDM2
- [ ] Configure volume mounts
- [ ] Set environment variables
- [ ] Configure network: ping-network
- [ ] Assign static IP: 172.20.0.22

**IDM2 Configuration Files**:

**boot.properties**:
- [ ] Set openidm.host=idm2-container
- [ ] Set openidm.port.http=8091
- [ ] Set openidm.port.https=8454
- [ ] Configure cluster settings (same cluster name as IDM1)

**repo.ds.json**:
- [ ] Configure primary LDAP server: ds2-container:1637
- [ ] Configure secondary LDAP server: ds1-container:1636
- [ ] Same bind credentials as IDM1
- [ ] Same connection pool settings

**cluster.json**:
- [ ] Enable clustering: `"enabled": true`
- [ ] Set cluster name: "idm-cluster" (MUST match IDM1)
- [ ] Configure instance ID: "idm2" (MUST be unique)

**IDM2 Deployment**:
- [ ] Build Docker image
- [ ] Start container: `docker-compose up -d`
- [ ] Check logs: `docker logs -f idm2-container`
- [ ] Wait for startup and cluster join message
- [ ] Access admin console: https://localhost:8454/admin
- [ ] Login: admin/admin
- [ ] Verify cluster status (should show 2 instances)
- [ ] Check health endpoint: `curl -k https://localhost:8454/openidm/info/ping`

**Verify Clustering**:
- [ ] Both IDM instances visible in admin console
- [ ] Scheduled tasks show cluster-aware distribution
- [ ] Configuration changes on IDM1 visible on IDM2
- [ ] Test failover: stop IDM1, verify IDM2 serves requests

### Phase 4: Configure External System Connectors

**SQL Server Connector Setup**:

**Download JDBC Driver**:
- [ ] Download Microsoft JDBC driver (mssql-jdbc-X.X.X.jre11.jar)
- [ ] Copy to IDM1/connectors/ directory
- [ ] Copy to IDM2/connectors/ directory
- [ ] Verify file permissions: `chmod 644 mssql-jdbc*.jar`

**SQL Database 1 Connector**:
- [ ] Create provisioner.mssql1.json in IDM1/conf/
- [ ] Configure database connection details:
  - Host: sqlserver1.example.com
  - Port: 1433
  - Database name: IdentityDB1
  - Table name: Users
  - Username: idm_service
  - Password: [SECURE_PASSWORD]
- [ ] Configure connector bundle reference
- [ ] Map database columns to IDM attributes

**Example provisioner.mssql1.json**:
```json
{
  "name": "mssql1",
  "connectorRef": {
    "connectorHostRef": "#LOCAL",
    "connectorName": "org.identityconnectors.databasetable.DatabaseTableConnector",
    "bundleName": "org.forgerock.openicf.connectors.databasetable-connector",
    "bundleVersion": "[1.4.0.0,2.0.0.0)"
  },
  "configurationProperties": {
    "quoting": "",
    "host": "sqlserver1.example.com",
    "port": "1433",
    "user": "idm_service",
    "password": "password",
    "database": "IdentityDB1",
    "table": "Users",
    "keyColumn": "UserID",
    "passwordColumn": "Password",
    "jdbcDriver": "com.microsoft.sqlserver.jdbc.SQLServerDriver",
    "jdbcUrlTemplate": "jdbc:sqlserver://%h:%p;databaseName=%d",
    "enableEmptyString": false,
    "rethrowAllSQLExceptions": true,
    "nativeTimestamps": true,
    "allNative": false,
    "changeLogColumn": "LastModified"
  },
  "poolConfigOption": {
    "maxObjects": 10,
    "maxIdle": 10,
    "maxWait": 150000,
    "minEvictableIdleTimeMillis": 120000,
    "minIdle": 1
  }
}
```

**SQL Database 2 Connector**:
- [ ] Create provisioner.mssql2.json
- [ ] Configure connection to SQL Database 2
- [ ] Map database schema to IDM attributes
- [ ] Copy configuration to IDM2

**Test SQL Connectors**:
- [ ] Restart IDM1 and IDM2 containers
- [ ] Test SQL1 connector: `curl -k -u admin:admin "https://localhost:8453/openidm/system/mssql1?_action=test"`
- [ ] Test SQL2 connector: `curl -k -u admin:admin "https://localhost:8453/openidm/system/mssql2?_action=test"`
- [ ] Verify "ok" status in response
- [ ] Check connector errors in IDM logs

**Active Directory Connector Setup**:

**AD Connector Configuration**:
- [ ] Create provisioner.ad.json in IDM1/conf/
- [ ] Configure LDAP connection to AD:
  - Host: ad.example.com
  - Port: 636 (LDAPS) or 389 (LDAP with StartTLS)
  - Base DN: DC=corp,DC=example,DC=com
  - Principal: CN=IDM Service,OU=Service Accounts,DC=corp,DC=example,DC=com
  - Credentials: [SECURE_PASSWORD]
- [ ] Configure SSL settings
- [ ] Map AD attributes to IDM attributes

**Example provisioner.ad.json**:
```json
{
  "name": "ad",
  "connectorRef": {
    "connectorHostRef": "#LOCAL",
    "connectorName": "org.identityconnectors.ldap.LdapConnector",
    "bundleName": "org.forgerock.openicf.connectors.ldap-connector",
    "bundleVersion": "[1.5.0.0,2.0.0.0)"
  },
  "configurationProperties": {
    "host": "ad.example.com",
    "port": 636,
    "ssl": true,
    "principal": "CN=IDM Service,OU=Service Accounts,DC=corp,DC=example,DC=com",
    "credentials": "password",
    "baseContexts": [
      "OU=Users,DC=corp,DC=example,DC=com"
    ],
    "baseContextsToSynchronize": [
      "OU=Users,DC=corp,DC=example,DC=com"
    ],
    "accountSearchFilter": "(&(objectClass=user)(objectCategory=person))",
    "accountSynchronizationFilter": "(&(objectClass=user)(objectCategory=person))",
    "readSchema": true,
    "usePagedResultControl": true,
    "blockSize": 100,
    "useBlocks": true
  },
  "poolConfigOption": {
    "maxObjects": 10,
    "maxIdle": 10,
    "maxWait": 150000,
    "minEvictableIdleTimeMillis": 120000,
    "minIdle": 1
  }
}
```

**Test AD Connector**:
- [ ] Restart IDM containers
- [ ] Test AD connector: `curl -k -u admin:admin "https://localhost:8453/openidm/system/ad?_action=test"`
- [ ] Verify "ok" status
- [ ] Query AD users: `curl -k -u admin:admin "https://localhost:8453/openidm/system/ad/account?_queryFilter=true&_pageSize=5"`
- [ ] Verify user data returns correctly

### Phase 5: Configure Synchronization Mappings

**Mapping from SQL DB 1 to PingDS**:
- [ ] Create sync.json with mapping "systemMssql1Account_managedUser"
- [ ] Map source attributes (SQL columns) to target attributes (DS)
- [ ] Configure reconciliation policies (SOURCE, TARGET, ALL_GONE, etc.)
- [ ] Configure data transformations (scripts)
- [ ] Set conflict resolution strategy

**Example Mapping**:
```json
{
  "mappings": [
    {
      "name": "systemMssql1Account_managedUser",
      "source": "system/mssql1/account",
      "target": "managed/user",
      "properties": [
        {
          "source": "UserID",
          "target": "userName"
        },
        {
          "source": "FirstName",
          "target": "givenName"
        },
        {
          "source": "LastName",
          "target": "sn"
        },
        {
          "source": "Email",
          "target": "mail"
        },
        {
          "source": "Phone",
          "target": "telephoneNumber"
        }
      ],
      "policies": [
        {
          "situation": "CONFIRMED",
          "action": "UPDATE"
        },
        {
          "situation": "FOUND",
          "action": "UPDATE"
        },
        {
          "situation": "ABSENT",
          "action": "CREATE"
        },
        {
          "situation": "AMBIGUOUS",
          "action": "EXCEPTION"
        },
        {
          "situation": "MISSING",
          "action": "IGNORE"
        },
        {
          "situation": "SOURCE_MISSING",
          "action": "IGNORE"
        },
        {
          "situation": "UNQUALIFIED",
          "action": "IGNORE"
        },
        {
          "situation": "UNASSIGNED",
          "action": "IGNORE"
        }
      ]
    }
  ]
}
```

**Mapping from SQL DB 2 to PingDS**:
- [ ] Create mapping "systemMssql2Account_managedUser"
- [ ] Map SQL DB 2 attributes to DS
- [ ] Handle potential duplicates (correlation query)
- [ ] Configure transformation scripts

**Mapping from Active Directory to PingDS**:
- [ ] Create mapping "systemAdAccount_managedUser"
- [ ] Map AD attributes (sAMAccountName, cn, mail) to DS
- [ ] Configure correlation to avoid duplicates
- [ ] Set up bi-directional sync (if required)

**Test Mappings**:
- [ ] Use IDM admin console > Configure > Mappings
- [ ] Test each mapping with "Reconcile Now"
- [ ] Review reconciliation results
- [ ] Check for errors and conflicts
- [ ] Verify users created in DS

### Phase 6: Configure Scheduled Reconciliation

**Create Schedule Configurations**:
- [ ] Create schedule-reconcile-mssql1.json
- [ ] Create schedule-reconcile-mssql2.json
- [ ] Create schedule-reconcile-ad.json
- [ ] Configure cron expressions (e.g., daily at 2 AM)
- [ ] Enable schedules

**Example Schedule** (schedule-reconcile-mssql1.json):
```json
{
  "enabled": true,
  "type": "cron",
  "schedule": "0 0 2 * * ?",
  "persisted": true,
  "misfirePolicy": "fireAndProceed",
  "invokeService": "sync",
  "invokeContext": {
    "action": "reconcile",
    "mapping": "systemMssql1Account_managedUser"
  }
}
```

**Configure LiveSync for AD** (optional):
- [ ] Create schedule-livesync-ad.json
- [ ] Configure LiveSync interval (e.g., every minute)
- [ ] Enable LiveSync
- [ ] Test real-time detection of AD changes

**Example LiveSync Schedule**:
```json
{
  "enabled": true,
  "type": "cron",
  "schedule": "0 0/1 * * * ?",
  "persisted": true,
  "misfirePolicy": "fireAndProceed",
  "invokeService": "provisioner.openicf",
  "invokeContext": {
    "action": "liveSync",
    "source": "system/ad/account"
  }
}
```

**Test Scheduled Jobs**:
- [ ] Verify schedules appear in IDM admin console > Configure > Schedules
- [ ] Manually trigger each schedule
- [ ] Monitor job execution in logs
- [ ] Verify scheduled jobs run at configured times
- [ ] Check cluster-aware job distribution (only one instance executes)

---

## PingAM Deployment Checklist

### Phase 1: AM Directory Structure

- [ ] Create AM1 directory: `mkdir -p AM1/{config,logs,tomcat}`
- [ ] Create AM2 directory: `mkdir -p AM2/{config,logs,tomcat}`
- [ ] Extract AM distribution (WAR or standalone)
- [ ] Set proper ownership

### Phase 2: AM1 Deployment (Primary)

**Container Setup**:
- [ ] Create Dockerfile for AM1
- [ ] Decide deployment method:
  - Option A: WAR file in Tomcat
  - Option B: Standalone JAR
- [ ] Create docker-compose.yml for AM1
- [ ] Configure volume mounts (config, logs)
- [ ] Set environment variables (JAVA_OPTS, AM_HOME)
- [ ] Configure network: ping-network
- [ ] Assign static IP: 172.20.0.31

**AM1 Deployment**:
- [ ] Build Docker image
- [ ] Start container: `docker-compose up -d`
- [ ] Check logs: `docker logs -f am1-container`
- [ ] Wait for application startup
- [ ] Access AM configurator: http://localhost:8100/am
- [ ] Verify configurator wizard loads

**AM1 Initial Configuration**:

**General Configuration**:
- [ ] Accept license agreement
- [ ] Select "Create New Configuration"
- [ ] Server settings:
  - Server URL: http://localhost:8100/am
  - Cookie domain: .example.com (or localhost for demo)
- [ ] Configuration store type: External directory server
- [ ] Configuration store settings:
  - Host: ds1-container
  - Port: 1636
  - Root suffix: ou=am-config,dc=example,dc=com
  - Login ID: cn=Directory Manager
  - Password: [DS_PASSWORD]
  - SSL/TLS: Enabled

**User Data Store**:
- [ ] Store type: External directory server
- [ ] Settings:
  - Host: ds1-container
  - Port: 1636
  - Root suffix: ou=identities,dc=example,dc=com
  - Login ID: uid=amldapuser,ou=identities,dc=example,dc=com
  - Password: [SERVICE_ACCOUNT_PASSWORD]
  - SSL/TLS: Enabled

**Site Configuration**:
- [ ] Enable site configuration: Yes
- [ ] Site name: ping-site
- [ ] Load balancer URL: http://localhost:8100/am (or future LB URL)

**Default Policy Agent**:
- [ ] Agent password: [SECURE_PASSWORD]
- [ ] Confirm password

**amadmin Account**:
- [ ] Set amadmin password: [SECURE_PASSWORD]
- [ ] Confirm password

**Submit Configuration**:
- [ ] Click "Create Configuration"
- [ ] Wait for configuration completion
- [ ] Verify success message
- [ ] Click "Proceed to Login"

**AM1 Post-Configuration**:
- [ ] Login as amadmin
- [ ] Access AM console: http://localhost:8100/am/console
- [ ] Navigate to Deployment > Servers
- [ ] Verify AM1 listed
- [ ] Navigate to Deployment > Sites
- [ ] Verify ping-site created

**Configure CTS**:
- [ ] Navigate to Configure > Global Services > CTS
- [ ] CTS store location: External DS
- [ ] Settings:
  - Host: ds1-container
  - Port: 1636
  - Root suffix: ou=tokens,dc=example,dc=com
  - Login ID: uid=amldapuser,ou=tokens,dc=example,dc=com
  - Password: [SERVICE_ACCOUNT_PASSWORD]
  - SSL/TLS: Enabled
  - Max connections: 10
- [ ] Save configuration

**Test AM1**:
- [ ] Create test realm: /demo
- [ ] Create test user in demo realm
- [ ] Test authentication: http://localhost:8100/am/XUI/?realm=/demo
- [ ] Login as test user
- [ ] Verify successful authentication
- [ ] Check audit logs

### Phase 3: AM2 Deployment (Fallback)

**Container Setup**:
- [ ] Create Dockerfile for AM2 (similar to AM1)
- [ ] Create docker-compose.yml for AM2
- [ ] Configure volume mounts
- [ ] Set environment variables
- [ ] Configure network: ping-network
- [ ] Assign static IP: 172.20.0.32

**AM2 Deployment**:
- [ ] Build Docker image
- [ ] Start container: `docker-compose up -d`
- [ ] Check logs: `docker logs -f am2-container`
- [ ] Wait for application startup
- [ ] Access AM configurator: http://localhost:8101/am

**AM2 Initial Configuration**:

**General Configuration**:
- [ ] Accept license agreement
- [ ] Select "Add to Existing Deployment"
- [ ] Server settings:
  - Server URL: http://localhost:8101/am
  - Cookie domain: .example.com (MUST match AM1)
- [ ] Configuration store settings:
  - Host: ds2-container (or ds1-container)
  - Port: 1637 (or 1636 if using ds1)
  - Root suffix: ou=am-config,dc=example,dc=com
  - Login ID: cn=Directory Manager
  - Password: [DS_PASSWORD]
  - SSL/TLS: Enabled

**Site Configuration**:
- [ ] Select existing site: ping-site
- [ ] Load balancer URL: http://localhost:8100/am (same as AM1)

**Admin Authentication**:
- [ ] amadmin password: [SAME_AS_AM1]

**Submit Configuration**:
- [ ] Click "Add to Deployment"
- [ ] Wait for configuration completion
- [ ] Verify success message
- [ ] Click "Proceed to Login"

**AM2 Post-Configuration**:
- [ ] Login as amadmin
- [ ] Navigate to Deployment > Servers
- [ ] Verify AM1 and AM2 both listed
- [ ] Check server status (both should be up)
- [ ] Navigate to Deployment > Sites > ping-site
- [ ] Verify both servers assigned to site

**Test Session Replication**:
- [ ] Login to AM1: http://localhost:8100/am/XUI/?realm=/demo
- [ ] Note session token (from cookie or query parameter)
- [ ] Access AM2 with same session token: http://localhost:8101/am/XUI/?realm=/demo
- [ ] Verify session recognized (user still logged in)
- [ ] Create session on AM2, verify on AM1
- [ ] Test logout on AM1, verify session cleared on AM2

### Phase 4: Configure Authentication Services

**Create Demo Realm** (if not already created):
- [ ] Navigate to Realms
- [ ] Click "New Realm"
- [ ] Name: demo
- [ ] DNS Aliases: demo.example.com (optional)
- [ ] Create

**Configure LDAP Authentication Module**:
- [ ] Navigate to Realms > demo > Authentication > Modules
- [ ] Create new module:
  - Name: DS-LDAP
  - Type: LDAP
- [ ] Configure LDAP settings:
  - Primary LDAP Server: ds1-container:1636
  - Secondary LDAP Server: ds2-container:1637
  - Base DN: ou=identities,dc=example,dc=com
  - Bind DN: uid=amldapuser,ou=identities,dc=example,dc=com
  - Bind Password: [SERVICE_ACCOUNT_PASSWORD]
  - SSL/TLS: Enabled
  - Search Filter: (uid=%s)
  - Search Scope: SUBTREE
- [ ] Save module

**Configure Data Store Authentication Module**:
- [ ] Navigate to Authentication > Modules
- [ ] Create new module:
  - Name: DS-DataStore
  - Type: Data Store
- [ ] Use default settings (authenticates against realm's user store)
- [ ] Save module

**Create Authentication Chain**:
- [ ] Navigate to Authentication > Chains
- [ ] Create new chain:
  - Name: demo-ldap-chain
- [ ] Add modules:
  - Module: DS-LDAP
  - Criteria: REQUIRED
- [ ] Save chain

**Set Default Authentication Chain**:
- [ ] Navigate to Authentication > Settings
- [ ] Organization Authentication Configuration: demo-ldap-chain
- [ ] Save

**Test Authentication**:
- [ ] Logout from AM console
- [ ] Access user login: http://localhost:8100/am/XUI/?realm=/demo
- [ ] Login as test user (from DS)
- [ ] Verify successful authentication
- [ ] Check AM audit logs for authentication event

### Phase 5: Configure OAuth2 Provider

**Enable OAuth2 Provider in demo Realm**:
- [ ] Navigate to Realms > demo > Services
- [ ] Add Service: OAuth2 Provider
- [ ] Configure settings:
  - Authorization Code Lifetime: 120 seconds
  - Access Token Lifetime: 3600 seconds
  - Refresh Token Lifetime: 604800 seconds
  - Issue Refresh Tokens: Enabled
  - Issue Refresh Tokens on Refreshing Access Tokens: Enabled
- [ ] Save

**Create OAuth2 Client**:
- [ ] Navigate to Realms > demo > Applications > OAuth 2.0
- [ ] Create new client:
  - Client ID: demo-client
  - Client Secret: [SECURE_SECRET]
  - Redirection URIs: http://localhost:8080/callback
  - Scope(s): openid profile email
  - Grant Types: Authorization Code, Refresh Token
  - Token Endpoint Authentication Method: client_secret_post
- [ ] Save

**Test OAuth2 Flow**:
- [ ] Construct authorization URL:
  ```
  http://localhost:8100/am/oauth2/authorize?
    client_id=demo-client&
    redirect_uri=http://localhost:8080/callback&
    response_type=code&
    scope=openid%20profile%20email&
    realm=/demo
  ```
- [ ] Access URL in browser
- [ ] Login if prompted
- [ ] Authorize client
- [ ] Verify redirect to callback URL with authorization code
- [ ] Exchange code for token:
  ```bash
  curl -X POST http://localhost:8100/am/oauth2/access_token \
    -d "grant_type=authorization_code" \
    -d "code=[AUTH_CODE]" \
    -d "client_id=demo-client" \
    -d "client_secret=[CLIENT_SECRET]" \
    -d "redirect_uri=http://localhost:8080/callback"
  ```
- [ ] Verify access token and refresh token returned
- [ ] Test token introspection:
  ```bash
  curl -X POST http://localhost:8100/am/oauth2/introspect \
    -d "token=[ACCESS_TOKEN]" \
    -d "client_id=demo-client" \
    -d "client_secret=[CLIENT_SECRET]"
  ```
- [ ] Verify token is active

---

## Integration & Testing Checklist

### End-to-End Flow Testing

**User Provisioning Flow**:
- [ ] Create test user in MS SQL DB 1
- [ ] Wait for scheduled reconciliation (or trigger manually)
- [ ] Verify user appears in IDM managed objects
- [ ] Verify user created in PingDS (ou=identities)
- [ ] Verify user visible in AM user management
- [ ] Check audit logs in IDM for sync event

**Authentication Flow**:
- [ ] User authenticates via AM (http://localhost:8100/am/XUI/?realm=/demo)
- [ ] AM validates credentials against DS
- [ ] Session token stored in CTS (in DS ou=tokens)
- [ ] Verify session visible in AM console > Sessions
- [ ] User accesses AM-protected resource
- [ ] User logs out
- [ ] Verify session removed from CTS

**Cross-Instance Session Test**:
- [ ] Login via AM1
- [ ] Verify session on AM2 (session replication via CTS)
- [ ] Create new session on AM2
- [ ] Verify session on AM1
- [ ] Logout from AM1
- [ ] Verify session cleared on AM2

**Data Consistency Test**:
- [ ] Create user in SQL DB 1
- [ ] Reconcile to DS via IDM
- [ ] Verify user replicates to all DS instances (DS1-DS4)
- [ ] Modify user in SQL DB 2
- [ ] Reconcile to DS
- [ ] Verify update replicates across DS cluster
- [ ] Delete user from AD
- [ ] Verify deletion handled per policy (reconciliation)

### High Availability Testing

**DS Failover Test**:
- [ ] Identify which DS instance IDM is using (check logs)
- [ ] Stop that DS instance: `docker stop ds1-container`
- [ ] Verify IDM switches to secondary DS
- [ ] Perform reconciliation operation
- [ ] Verify operation succeeds
- [ ] Restart stopped DS instance
- [ ] Verify replication catches up

**IDM Failover Test**:
- [ ] Access IDM1 admin console
- [ ] Stop IDM1 container: `docker stop idm1-container`
- [ ] Access IDM2 admin console
- [ ] Verify IDM2 operational
- [ ] Trigger scheduled job
- [ ] Verify job executes on IDM2
- [ ] Restart IDM1
- [ ] Verify IDM1 rejoins cluster

**AM Failover Test**:
- [ ] Login via AM1
- [ ] Note session token
- [ ] Stop AM1 container: `docker stop am1-container`
- [ ] Access AM2 with session token
- [ ] Verify session still valid (CTS failover)
- [ ] Create new session on AM2
- [ ] Verify AM2 operational
- [ ] Restart AM1
- [ ] Verify AM1 rejoins site

**DS Replication Lag Test**:
- [ ] Create 100 test entries in DS1 rapidly
- [ ] Check replication status: `dsreplication status`
- [ ] Monitor replication lag to DS2, DS3, DS4
- [ ] Verify lag returns to < 100ms after load
- [ ] Delete test entries
- [ ] Verify deletions replicate

### Performance Baseline

**DS Performance**:
- [ ] LDAP search response time (average): _____ ms (target: < 50ms)
- [ ] LDAP bind response time (average): _____ ms (target: < 50ms)
- [ ] Replication lag (average): _____ ms (target: < 100ms)
- [ ] Peak connections: _____ (monitor)
- [ ] CPU utilization during load: _____ % (monitor)
- [ ] Memory utilization: _____ MB (monitor)

**IDM Performance**:
- [ ] Reconciliation throughput: _____ users/minute
- [ ] Connector test response time: _____ ms
- [ ] API response time (GET /managed/user): _____ ms
- [ ] Scheduled job execution time: _____ seconds
- [ ] CPU utilization: _____ %
- [ ] Memory utilization: _____ MB

**AM Performance**:
- [ ] Authentication response time (average): _____ ms (target: < 200ms)
- [ ] OAuth2 token issuance time: _____ ms
- [ ] Session creation rate: _____ sessions/minute
- [ ] CTS token write time: _____ ms
- [ ] CPU utilization: _____ %
- [ ] Memory utilization: _____ MB

**Load Testing** (using JMeter or similar):
- [ ] Install JMeter
- [ ] Create test plan: 100 concurrent users authenticating
- [ ] Run test for 10 minutes
- [ ] Record results (response times, error rate)
- [ ] Create test plan: IDM reconciliation load
- [ ] Run test: reconcile 1000 users
- [ ] Record results (throughput, errors)
- [ ] Verify no memory leaks after load tests
- [ ] Verify services remain stable

### Security Validation

**Encryption Validation**:
- [ ] Verify TLS enabled for all DS connections (ldapsearch with -Z)
- [ ] Verify HTTPS enabled for IDM admin console
- [ ] Verify HTTPS enforced for AM (or HTTP behind reverse proxy)
- [ ] Check certificate validity: `openssl s_client -connect localhost:8443`
- [ ] Verify no plaintext passwords in configuration files
- [ ] Check configuration files for sensitive data exposure

**Access Control Validation**:
- [ ] Test LDAP access controls:
  - Anonymous bind disabled: `ldapsearch -h localhost -p 1636 -Z -X -b "dc=example,dc=com"`
  - Should fail without credentials
- [ ] Test unauthorized access to IDM:
  - Access https://localhost:8453/admin without login
  - Should redirect to login page
- [ ] Test unauthorized access to AM:
  - Access http://localhost:8100/am/console without login
  - Should redirect to login page
- [ ] Test privilege escalation:
  - Login as non-admin user
  - Attempt to access admin functions
  - Should be denied

**Password Policy Validation**:
- [ ] Test DS password policy:
  - Create user with weak password
  - Should be rejected per policy
- [ ] Test AM password policy:
  - Attempt to set weak amadmin password
  - Should be rejected
- [ ] Test password history
- [ ] Test account lockout after failed attempts
- [ ] Test password expiration

**Audit Logging Validation**:
- [ ] Verify DS audit log enabled
- [ ] Check DS audit log: `/path/to/DS1/logs/audit`
- [ ] Verify IDM audit log enabled
- [ ] Check IDM audit log: tail IDM1/logs/audit.csv
- [ ] Verify AM audit log enabled
- [ ] Check AM audit events in AM console > Configure > Global Services > Audit Logging
- [ ] Test audit completeness:
  - Perform authentication
  - Verify event logged
  - Perform reconciliation
  - Verify event logged
  - Modify configuration
  - Verify event logged

---

## Production Readiness Checklist

### Security Hardening

- [ ] Replace all default passwords
- [ ] Implement password rotation schedule
- [ ] Use CA-signed certificates (replace self-signed)
- [ ] Configure certificate expiration monitoring
- [ ] Enable two-factor authentication for admin accounts
- [ ] Implement least privilege access control
- [ ] Disable unnecessary services and endpoints
- [ ] Configure rate limiting and throttling
- [ ] Implement intrusion detection/prevention
- [ ] Conduct security audit
- [ ] Perform penetration testing
- [ ] Review and harden firewall rules
- [ ] Implement secrets management (Vault, CyberArk)
- [ ] Encrypt Docker volumes at rest

### Monitoring & Alerting

- [ ] Deploy Prometheus for metrics collection
- [ ] Deploy Grafana for visualization
- [ ] Configure Prometheus exporters for each service
- [ ] Create Grafana dashboards for DS, IDM, AM
- [ ] Set up alerting rules:
  - DS replication lag > 1 second
  - DS disk usage > 80%
  - IDM reconciliation failures
  - AM authentication failure rate spike
  - Container down/unhealthy
  - High CPU/memory utilization
- [ ] Configure alert destinations (email, Slack, PagerDuty)
- [ ] Test alerting pipeline
- [ ] Document alert response procedures

### Logging & Log Management

- [ ] Configure centralized logging (ELK, Splunk, etc.)
- [ ] Forward DS logs to centralized logging
- [ ] Forward IDM logs to centralized logging
- [ ] Forward AM logs to centralized logging
- [ ] Configure log retention policies
- [ ] Set up log rotation
- [ ] Configure log levels appropriately (INFO for production)
- [ ] Create log dashboards for troubleshooting
- [ ] Test log search and filtering
- [ ] Document log analysis procedures

### Backup & Disaster Recovery

**Backup Strategy**:
- [ ] Implement automated DS backups:
  - Daily incremental backups
  - Weekly full backups
  - Backup retention: 30 days
- [ ] Implement IDM configuration backups:
  - Daily configuration export
  - Version control for config files
- [ ] Implement AM configuration backups:
  - Daily configuration export via `amster`
- [ ] Backup Docker volumes
- [ ] Backup certificates and keys
- [ ] Test backup integrity (random restore tests)
- [ ] Store backups off-site or in separate storage

**Disaster Recovery**:
- [ ] Document disaster recovery procedures
- [ ] Define RTO (Recovery Time Objective): _____ minutes
- [ ] Define RPO (Recovery Point Objective): _____ hours
- [ ] Test DS restore from backup
- [ ] Test IDM restore from backup
- [ ] Test AM restore from backup
- [ ] Test complete environment rebuild
- [ ] Document rollback procedures
- [ ] Conduct disaster recovery drill

### Documentation

- [ ] Network diagram with IP addresses and ports
- [ ] Deployment architecture diagram
- [ ] Configuration management documentation
- [ ] Operational runbooks:
  - Service startup/shutdown procedures
  - Troubleshooting common issues
  - Backup/restore procedures
  - Failover procedures
  - Password reset procedures
- [ ] Security documentation:
  - Access control policies
  - Encryption standards
  - Compliance requirements
- [ ] Contact list:
  - Admin contacts
  - Vendor support contacts
  - Escalation procedures
- [ ] Change management procedures
- [ ] Incident response plan

### Performance Optimization

- [ ] Tune DS indexes for common queries
- [ ] Optimize DS cache sizes (database cache, entry cache)
- [ ] Tune IDM thread pools and connection pools
- [ ] Optimize AM session cache
- [ ] Configure JVM heap sizes appropriately:
  - DS: 2-4 GB for 5k users
  - IDM: 2-4 GB
  - AM: 2-4 GB
- [ ] Enable JVM garbage collection logging
- [ ] Tune JVM GC settings (G1GC recommended)
- [ ] Optimize Docker resource limits
- [ ] Review and optimize database queries (SQL connectors)
- [ ] Load test and validate performance targets

### Compliance & Governance

- [ ] Implement data retention policies
- [ ] Configure privacy controls (GDPR, CCPA)
- [ ] Enable consent management (if applicable)
- [ ] Implement data anonymization/pseudonymization
- [ ] Document data flows and data mappings
- [ ] Conduct privacy impact assessment
- [ ] Implement audit log retention per compliance
- [ ] Configure compliance reporting
- [ ] Review access control policies for compliance
- [ ] Conduct compliance audit

### Training & Knowledge Transfer

- [ ] Train operations team on Ping Identity platform
- [ ] Train support team on troubleshooting procedures
- [ ] Conduct knowledge transfer sessions
- [ ] Create video tutorials for common tasks
- [ ] Document lessons learned
- [ ] Establish support escalation process
- [ ] Schedule periodic refresher training

---

## Final Pre-Deployment Checklist

Before going live, verify:

- [ ] All services running without errors
- [ ] All health checks passing
- [ ] Replication functioning correctly
- [ ] Authentication working end-to-end
- [ ] Synchronization jobs running successfully
- [ ] High availability tested and verified
- [ ] Performance baselines established
- [ ] Security hardening complete
- [ ] Monitoring and alerting configured
- [ ] Backups tested and verified
- [ ] Documentation complete and accessible
- [ ] Operations team trained
- [ ] Disaster recovery plan tested
- [ ] Change management process in place
- [ ] Stakeholder sign-off obtained

---

## Post-Deployment Checklist

After deployment:

- [ ] Monitor services for 24 hours
- [ ] Review logs for errors or warnings
- [ ] Verify scheduled jobs executing
- [ ] Verify replication lag remains low
- [ ] Check resource utilization trends
- [ ] Conduct user acceptance testing
- [ ] Gather user feedback
- [ ] Create post-deployment report
- [ ] Schedule post-mortem meeting
- [ ] Update documentation with as-built config
- [ ] Plan phase 2 enhancements
- [ ] Schedule first backup test
- [ ] Schedule first disaster recovery drill

---

**Document Version**: 1.0
**Last Updated**: 2025-11-04
**Maintained By**: IAM Engineering Team

---

*End of Checklist*
