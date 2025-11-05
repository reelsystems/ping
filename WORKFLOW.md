# Ping Identity Deployment Workflow

**Project**: Ping Identity Platform Demo Environment
**Version**: 7.5.2
**Started**: 2025-11-04
**Status**: In Progress - Planning Phase

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Current Status](#current-status)
3. [Phase 1: Planning & Preparation](#phase-1-planning--preparation)
4. [Phase 2: Infrastructure Setup](#phase-2-infrastructure-setup)
5. [Phase 3: PingDS Deployment](#phase-3-pingds-deployment)
6. [Phase 4: PingIDM Deployment](#phase-4-pingidm-deployment)
7. [Phase 5: PingAM Deployment](#phase-5-pingam-deployment)
8. [Phase 6: Integration & Testing](#phase-6-integration--testing)
9. [Phase 7: Data Migration](#phase-7-data-migration)
10. [Issues & Resolutions](#issues--resolutions)
11. [Next Steps](#next-steps)

---

## Project Overview

### Objective
Deploy a highly available Ping Identity platform consisting of:
- PingDS (Directory Server) - 4 instances (DS1-DS4)
- PingIDM (Identity Management) - 2 instances (IDM1-IDM2)
- PingAM (Access Manager) - 2 instances (AM1-AM2)

### Goals
- Consolidate identity data from 2 MS SQL databases and Active Directory into PingDS
- Establish high availability with primary/fallback configuration
- Create reproducible Docker-based deployment
- Support ~5,000 users
- Demonstrate platform capabilities for future production deployment

### Success Criteria
- [ ] All services running and accessible
- [ ] Replication functioning between all DS instances
- [ ] IDM successfully syncing from external data sources
- [ ] AM authenticating users from DS identity store
- [ ] Web-based admin consoles accessible
- [ ] Documentation complete and accurate

---

## Current Status

### Completed Tasks
✅ **2025-11-04**: Research completed on Ping Identity 7.5.2 documentation
✅ **2025-11-04**: Architecture document created ([architecture.md](architecture.md))
✅ **2025-11-04**: Workflow document initialized (this file)

### In Progress Tasks
🔄 **Requirements checklist development**
🔄 **Directory structure creation**
🔄 **Installation guide research**

### Pending Tasks
⏳ Docker environment setup
⏳ Network configuration
⏳ Service deployment
⏳ Data connector configuration
⏳ Testing and validation

---

## Phase 1: Planning & Preparation

### Status: IN PROGRESS

#### 1.1 Documentation Creation
**Started**: 2025-11-04
**Target Completion**: 2025-11-04

- [x] Create architecture.md with deployment diagrams
- [x] Initialize WORKFLOW.md (this document)
- [ ] Create checklist.md with all requirements
- [ ] Create CONSIDERATIONS.md with additional guidance
- [ ] Research and document installation procedures

**Notes**:
- Architecture document includes ASCII diagrams for all components
- Port allocation matrix defined to avoid conflicts
- Redundancy strategy documented

#### 1.2 System Requirements Validation
**Status**: Pending

Tasks:
- [ ] Verify Docker installation and version
- [ ] Confirm Java version compatibility
- [ ] Check available disk space (minimum 50GB recommended)
- [ ] Verify network connectivity
- [ ] Check RAM availability (minimum 16GB recommended)
- [ ] Confirm DNS resolution or /etc/hosts configuration

#### 1.3 Software Acquisition
**Status**: Pending

Tasks:
- [ ] Register for Ping Identity account (if not already done)
- [ ] Access Ping Identity Support Portal / Backstage
- [ ] Download PingDS 7.5.2 distribution
- [ ] Download PingIDM 7.5.2 distribution
- [ ] Download PingAM 7.5.2 distribution
- [ ] Verify SHA checksums of downloaded files
- [ ] Extract distributions to appropriate directories

**Download Links** (Ping Identity Support Portal):
- PingDS: https://backstage.forgerock.com (requires login)
- PingIDM: https://backstage.forgerock.com (requires login)
- PingAM: https://backstage.forgerock.com (requires login)

---

## Phase 2: Infrastructure Setup

### Status: NOT STARTED

#### 2.1 Directory Structure Creation
**Target Completion**: TBD

Create the following directory structure:
```
/home/thepackle/repos/ping/
├── DS1/
│   ├── config/
│   ├── data/
│   ├── logs/
│   ├── docker-compose.yml
│   └── Dockerfile
├── DS2/ (same structure)
├── DS3/ (same structure)
├── DS4/ (same structure)
├── IDM1/
│   ├── conf/
│   ├── connectors/
│   ├── script/
│   ├── logs/
│   ├── docker-compose.yml
│   └── Dockerfile
├── IDM2/ (same structure)
├── AM1/
│   ├── config/
│   ├── logs/
│   ├── docker-compose.yml
│   └── Dockerfile
├── AM2/ (same structure)
├── shared/
│   ├── certs/
│   ├── scripts/
│   └── backups/
├── architecture.md
├── WORKFLOW.md
├── checklist.md
└── CONSIDERATIONS.md
```

Commands to execute:
```bash
# Create main service directories
mkdir -p DS1/{config,data,logs}
mkdir -p DS2/{config,data,logs}
mkdir -p DS3/{config,data,logs}
mkdir -p DS4/{config,data,logs}
mkdir -p IDM1/{conf,connectors,script,logs}
mkdir -p IDM2/{conf,connectors,script,logs}
mkdir -p AM1/{config,logs}
mkdir -p AM2/{config,logs}
mkdir -p shared/{certs,scripts,backups}
```

#### 2.2 Docker Network Setup
**Target Completion**: TBD

Tasks:
- [ ] Create custom Docker bridge network
- [ ] Configure subnet (172.20.0.0/16)
- [ ] Set up DNS resolution between containers
- [ ] Test network connectivity

Commands:
```bash
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network
```

#### 2.3 Certificate Generation
**Target Completion**: TBD

Tasks:
- [ ] Generate self-signed CA certificate
- [ ] Generate server certificates for each DS instance
- [ ] Generate server certificates for IDM instances
- [ ] Generate server certificates for AM instances
- [ ] Configure certificate trust between services

**Notes**:
- Self-signed certificates acceptable for demo
- Production requires CA-signed certificates
- Consider using Let's Encrypt for production

---

## Phase 3: PingDS Deployment

### Status: NOT STARTED

#### 3.1 Deploy DS1 (Primary)
**Target Completion**: TBD

**Pre-requisites**:
- PingDS 7.5.2 distribution extracted
- Docker network created
- Certificates prepared

**Steps**:
1. [ ] Create Dockerfile for DS1
2. [ ] Create docker-compose.yml for DS1
3. [ ] Configure setup profile (ds-evaluation)
4. [ ] Define base DN (dc=example,dc=com)
5. [ ] Set admin credentials
6. [ ] Configure ports (LDAP: 1636, Admin: 4444, HTTP: 8080, HTTPS: 8443)
7. [ ] Start DS1 container
8. [ ] Verify DS1 is running (`ldapsearch` test)
9. [ ] Create initial admin user
10. [ ] Configure password policy

**Commands**:
```bash
cd DS1/
docker-compose up -d
docker logs -f ds1-container

# Verify service
ldapsearch -h localhost -p 1636 -Z -X -D "cn=Directory Manager" \
  -w password -b "dc=example,dc=com" "(objectClass=*)"
```

**Success Criteria**:
- DS1 container running without errors
- LDAP port responsive
- Admin console accessible on https://localhost:8443
- Directory Manager can authenticate

#### 3.2 Deploy DS2 (Fallback)
**Target Completion**: TBD

**Steps**:
1. [ ] Create Dockerfile for DS2
2. [ ] Create docker-compose.yml for DS2
3. [ ] Configure setup profile (ds-evaluation)
4. [ ] Use same base DN as DS1
5. [ ] Set admin credentials (same as DS1)
6. [ ] Configure ports (LDAP: 1637, Admin: 4445, HTTP: 8081, HTTPS: 8444)
7. [ ] Start DS2 container
8. [ ] Verify DS2 is running independently

**Success Criteria**:
- DS2 container running without errors
- LDAP port responsive on 1637
- Admin console accessible on https://localhost:8444

#### 3.3 Configure Replication (DS1 ↔ DS2)
**Target Completion**: TBD

**Steps**:
1. [ ] Enable replication on DS1
2. [ ] Enable replication on DS2
3. [ ] Initialize replication from DS1 to DS2
4. [ ] Verify replication status
5. [ ] Test data replication (create entry on DS1, verify on DS2)
6. [ ] Test bi-directional sync (create entry on DS2, verify on DS1)

**Commands**:
```bash
# On DS1 container
dsreplication enable \
  --host1 ds1-container --port1 4444 --bindDN1 "cn=Directory Manager" \
  --bindPassword1 password --replicationPort1 8989 \
  --host2 ds2-container --port2 4445 --bindDN2 "cn=Directory Manager" \
  --bindPassword2 password --replicationPort2 8990 \
  --adminUID admin --adminPassword password \
  --baseDN "dc=example,dc=com" --trustAll --no-prompt

# Initialize replication
dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds1-container --portSource 4444 \
  --hostDestination ds2-container --portDestination 4445 \
  --adminUID admin --adminPassword password \
  --trustAll --no-prompt

# Check status
dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt
```

**Success Criteria**:
- `dsreplication status` shows both servers connected
- Replication lag < 100ms
- Test entries replicate bi-directionally
- No errors in replication logs

#### 3.4 Deploy DS3 and DS4 (Additional Replicas)
**Target Completion**: TBD

**Steps**:
1. [ ] Deploy DS3 (ports: LDAP 1638, Admin 4446, HTTP 8082, HTTPS 8445)
2. [ ] Deploy DS4 (ports: LDAP 1639, Admin 4447, HTTP 8083, HTTPS 8446)
3. [ ] Add DS3 to replication topology
4. [ ] Add DS4 to replication topology
5. [ ] Initialize replication for DS3 and DS4
6. [ ] Verify 4-way replication

**Success Criteria**:
- All 4 DS instances showing in `dsreplication status`
- Multi-master replication functioning
- Test data replicates to all 4 instances
- Replication lag acceptable across all nodes

#### 3.5 Configure DS for PingAM
**Target Completion**: TBD

**Steps**:
1. [ ] Run `setup` with `am-identity-store` profile on DS1
2. [ ] Run `setup` with `am-config-store` profile on DS1
3. [ ] Run `setup` with `am-cts` profile on DS1
4. [ ] Verify AM-specific schema additions
5. [ ] Replicate AM schema to all DS instances
6. [ ] Create AM service account in DS

**Notes**:
- AM requires specific LDAP schema extensions
- Config store: ou=am-config,dc=example,dc=com
- CTS store: ou=tokens,dc=example,dc=com
- Identity store: ou=identities,dc=example,dc=com

---

## Phase 4: PingIDM Deployment

### Status: NOT STARTED

#### 4.1 Deploy IDM1 (Primary)
**Target Completion**: TBD

**Pre-requisites**:
- PingIDM 7.5.2 distribution extracted
- DS1 and DS2 operational with replication
- Docker network configured

**Steps**:
1. [ ] Create Dockerfile for IDM1
2. [ ] Create docker-compose.yml for IDM1
3. [ ] Configure repository connection to DS1
4. [ ] Set up boot.properties (openidm.host, ports)
5. [ ] Configure cluster settings
6. [ ] Configure ports (HTTP: 8090, HTTPS: 8453)
7. [ ] Start IDM1 container
8. [ ] Access admin console (https://localhost:8453/admin)
9. [ ] Verify repository connection

**Repository Configuration** (repo.ds.json):
```json
{
  "ldapConnectionFactories": [
    {
      "primaryLdapServers": [
        {
          "hostname": "ds1-container",
          "port": 1636,
          "sslCertAlias": "ds1-cert"
        }
      ],
      "secondaryLdapServers": [
        {
          "hostname": "ds2-container",
          "port": 1637,
          "sslCertAlias": "ds2-cert"
        }
      ]
    }
  ]
}
```

**Success Criteria**:
- IDM1 container running
- Admin console accessible (admin/admin default)
- Dashboard shows healthy status
- Repository connectivity confirmed

#### 4.2 Deploy IDM2 (Fallback)
**Target Completion**: TBD

**Steps**:
1. [ ] Create Dockerfile for IDM2
2. [ ] Create docker-compose.yml for IDM2
3. [ ] Configure repository connection to DS2 (primary) and DS1 (fallback)
4. [ ] Configure clustering to join IDM1
5. [ ] Configure ports (HTTP: 8091, HTTPS: 8454)
6. [ ] Start IDM2 container
7. [ ] Verify cluster formation with IDM1
8. [ ] Access admin console (https://localhost:8454/admin)

**Clustering Configuration**:
- Use shared DS repository for cluster coordination
- Configure cluster.json with both IDM instances
- Verify scheduled tasks distribute across cluster

**Success Criteria**:
- IDM2 container running
- IDM2 joined to IDM1 cluster
- Both instances visible in admin console
- Scheduled tasks show cluster-aware distribution

#### 4.3 Configure MS SQL Database Connectors
**Target Completion**: TBD

**Pre-requisites**:
- MS SQL database credentials
- JDBC driver for SQL Server
- Network connectivity to SQL databases

**Steps**:
1. [ ] Download Microsoft JDBC driver
2. [ ] Add JDBC driver to IDM1 and IDM2 connectors directory
3. [ ] Create provisioner configuration for SQL DB 1 (provisioner.mssql1.json)
4. [ ] Create provisioner configuration for SQL DB 2 (provisioner.mssql2.json)
5. [ ] Test database connectivity
6. [ ] Map SQL schema to IDM managed objects
7. [ ] Create reconciliation mappings

**Provisioner Example** (provisioner.mssql1.json):
```json
{
  "name": "mssql1",
  "connectorRef": {
    "connectorName": "org.identityconnectors.databasetable.DatabaseTableConnector",
    "bundleName": "org.forgerock.openicf.connectors.databasetable-connector",
    "bundleVersion": "[1.4.0.0,2.0.0.0)"
  },
  "configurationProperties": {
    "database": "IdentityDB1",
    "host": "sqlserver1.example.com",
    "port": "1433",
    "user": "idm_service",
    "password": "encrypted_password",
    "table": "Users"
  }
}
```

**Success Criteria**:
- Connector test successful for both SQL databases
- Schema discovery completes
- Test reconciliation retrieves user records

#### 4.4 Configure Active Directory Connector
**Target Completion**: TBD

**Steps**:
1. [ ] Create provisioner configuration for AD (provisioner.ad.json)
2. [ ] Configure LDAP connection settings
3. [ ] Set base context for user searches
4. [ ] Configure attribute mappings
5. [ ] Test connectivity to AD
6. [ ] Create reconciliation mappings from AD to DS
7. [ ] Configure LiveSync for real-time updates

**Provisioner Example** (provisioner.ad.json):
```json
{
  "name": "ad",
  "connectorRef": {
    "connectorName": "org.identityconnectors.ldap.LdapConnector",
    "bundleName": "org.forgerock.openicf.connectors.ldap-connector",
    "bundleVersion": "[1.5.0.0,2.0.0.0)"
  },
  "configurationProperties": {
    "host": "ad.example.com",
    "port": 636,
    "ssl": true,
    "principal": "CN=IDM Service,OU=Service Accounts,DC=example,DC=com",
    "credentials": "encrypted_password",
    "baseContexts": ["OU=Users,DC=example,DC=com"]
  }
}
```

**Success Criteria**:
- AD connector test successful
- User search returns expected results
- Attribute mapping configured
- LiveSync detects changes in AD

#### 4.5 Create Reconciliation Jobs
**Target Completion**: TBD

**Steps**:
1. [ ] Create mapping from SQL DB 1 to DS (sync.json)
2. [ ] Create mapping from SQL DB 2 to DS (sync.json)
3. [ ] Create mapping from AD to DS (sync.json)
4. [ ] Configure reconciliation schedules
5. [ ] Set up conflict resolution policies
6. [ ] Configure data transformation scripts
7. [ ] Test reconciliation with small dataset

**Reconciliation Schedule**:
- Initial: Manual reconciliation for testing
- Production:
  - SQL databases: Daily at 2 AM
  - Active Directory: LiveSync (real-time) + hourly reconciliation

**Success Criteria**:
- Reconciliation jobs complete without errors
- Users from external systems appear in DS
- Conflicts handled according to policy
- Transformation scripts execute correctly

---

## Phase 5: PingAM Deployment

### Status: NOT STARTED

#### 5.1 Deploy AM1 (Primary)
**Target Completion**: TBD

**Pre-requisites**:
- PingAM 7.5.2 distribution extracted
- DS cluster operational with AM schema installed
- Java servlet container (Tomcat) or standalone deployment

**Steps**:
1. [ ] Create Dockerfile for AM1
2. [ ] Create docker-compose.yml for AM1
3. [ ] Deploy AM WAR file or use standalone JAR
4. [ ] Access initial configuration wizard (http://localhost:8100/am)
5. [ ] Configure AM with following settings:
   - Server URL: http://localhost:8100/am
   - Cookie domain: .example.com
   - Configuration store: DS1 (ldaps://ds1-container:1636)
   - Identity store: DS1 (ldaps://ds1-container:1636)
   - CTS store: DS1 (ldaps://ds1-container:1636)
6. [ ] Complete initial configuration
7. [ ] Login to AM console (amadmin/password)
8. [ ] Verify connection to DS

**Configuration Details**:
- Base DN for config: ou=am-config,dc=example,dc=com
- Base DN for users: ou=identities,dc=example,dc=com
- Base DN for CTS: ou=tokens,dc=example,dc=com

**Success Criteria**:
- AM1 accessible at http://localhost:8100/am/console
- Successfully login as amadmin
- Dashboard shows all stores connected
- Test user authentication against DS

#### 5.2 Configure AM Realms and Authentication
**Target Completion**: TBD

**Steps**:
1. [ ] Create demo realm (e.g., "/demo")
2. [ ] Configure authentication modules:
   - LDAP authentication (to DS)
   - Username/Password authentication
   - Multi-factor authentication (future)
3. [ ] Create authentication chains
4. [ ] Configure password policies
5. [ ] Set up user self-service (password reset, registration)
6. [ ] Test authentication flow

**Success Criteria**:
- Demo realm created
- Users can authenticate via LDAP
- Authentication chains working
- Self-service pages accessible

#### 5.3 Deploy AM2 (Fallback)
**Target Completion**: TBD

**Steps**:
1. [ ] Create Dockerfile for AM2
2. [ ] Create docker-compose.yml for AM2
3. [ ] Configure AM2 to join existing site
4. [ ] Point to DS2 as primary config/identity/CTS store
5. [ ] Configure ports (HTTP: 8101)
6. [ ] Start AM2 container
7. [ ] Verify AM2 joins site
8. [ ] Test session replication via CTS

**Site Configuration**:
- Site name: "ping-site"
- Load balancer URL: https://sso.example.com/am (future)
- Session failover: Enabled via CTS

**Success Criteria**:
- AM2 running and joined to site
- Both AM1 and AM2 visible in console under Deployment > Servers
- Session created on AM1 is accessible from AM2
- CTS replication functioning

#### 5.4 Configure OAuth2 and Federation
**Target Completion**: TBD

**Steps**:
1. [ ] Enable OAuth2 provider in demo realm
2. [ ] Create OAuth2 client applications
3. [ ] Configure scopes and claims
4. [ ] Test OAuth2 authorization code flow
5. [ ] Configure SAML 2.0 (if needed)
6. [ ] Set up federation with test SP

**Success Criteria**:
- OAuth2 provider operational
- Test client can obtain access tokens
- Token introspection working
- Federation metadata available

---

## Phase 6: Integration & Testing

### Status: NOT STARTED

#### 6.1 End-to-End Authentication Test
**Target Completion**: TBD

**Test Scenario**:
1. [ ] User exists in MS SQL DB 1
2. [ ] IDM reconciliation imports user to DS
3. [ ] User authenticates via AM
4. [ ] Session stored in CTS
5. [ ] User accesses protected resource
6. [ ] User logs out

**Success Criteria**:
- User data flows from SQL → IDM → DS → AM
- Authentication succeeds
- Session management works
- Audit logs capture all events

#### 6.2 High Availability Testing
**Target Completion**: TBD

**Test Scenarios**:
1. [ ] Stop DS1, verify DS2 serves requests
2. [ ] Stop DS1 and DS2, verify DS3/DS4 serve requests
3. [ ] Stop IDM1, verify IDM2 continues operations
4. [ ] Stop AM1, verify AM2 serves authentication
5. [ ] Test replication lag during high load
6. [ ] Verify session failover between AM instances

**Success Criteria**:
- No service interruption during single server failure
- Failover occurs within < 1 minute
- Data consistency maintained
- No data loss during failover

#### 6.3 Performance Baseline
**Target Completion**: TBD

**Metrics to Capture**:
1. [ ] DS: LDAP search response time (target: < 50ms)
2. [ ] DS: Replication lag (target: < 100ms)
3. [ ] IDM: Reconciliation throughput (users/minute)
4. [ ] AM: Authentication response time (target: < 200ms)
5. [ ] AM: Session creation rate
6. [ ] System: CPU and memory utilization

**Tools**:
- Apache JMeter for load testing
- Prometheus metrics from each service
- Custom monitoring scripts

**Success Criteria**:
- Baseline established for future comparison
- System stable under expected load (5,000 users)
- No memory leaks detected
- Response times within targets

#### 6.4 Security Validation
**Target Completion**: TBD

**Security Checks**:
1. [ ] Verify TLS/SSL enabled for all services
2. [ ] Test certificate validation
3. [ ] Verify encrypted passwords in configuration
4. [ ] Test LDAP access controls
5. [ ] Validate AM policy enforcement
6. [ ] Review audit log completeness
7. [ ] Test password policies

**Success Criteria**:
- All communications encrypted
- No plaintext passwords in configs
- Access controls properly enforced
- Audit logs comprehensive

---

## Phase 7: Data Migration

### Status: NOT STARTED

#### 7.1 Initial Data Import
**Target Completion**: TBD

**Steps**:
1. [ ] Export sample data from MS SQL DB 1
2. [ ] Export sample data from MS SQL DB 2
3. [ ] Export sample data from Active Directory
4. [ ] Run IDM reconciliation for all sources
5. [ ] Validate data in PingDS
6. [ ] Resolve conflicts and duplicates
7. [ ] Verify attribute mappings

**Success Criteria**:
- All user accounts imported
- No duplicate accounts
- Critical attributes mapped correctly
- Reconciliation reports clean

#### 7.2 Ongoing Synchronization
**Target Completion**: TBD

**Steps**:
1. [ ] Enable scheduled reconciliation jobs
2. [ ] Enable LiveSync for AD
3. [ ] Monitor sync job execution
4. [ ] Set up alerts for sync failures
5. [ ] Create operational runbook for sync issues

**Monitoring**:
- IDM console > Configure > Schedules
- Review reconciliation reports daily
- Alert on failures via email/Slack

**Success Criteria**:
- Scheduled jobs running reliably
- LiveSync detecting AD changes within 1 minute
- Sync errors logged and alerting
- Runbook complete and tested

---

## Issues & Resolutions

### Issue Log

#### Issue #1: [Placeholder]
**Date**: TBD
**Component**: TBD
**Description**: TBD
**Impact**: TBD
**Resolution**: TBD
**Status**: TBD

---

## Next Steps

### Immediate Actions Required

1. **Complete Planning Phase**:
   - [ ] Finalize checklist.md
   - [ ] Create CONSIDERATIONS.md
   - [ ] Review and approve architecture

2. **Prepare Environment**:
   - [ ] Validate system requirements
   - [ ] Download Ping software distributions
   - [ ] Set up Docker environment

3. **Begin Deployment**:
   - [ ] Create directory structure
   - [ ] Deploy DS1 as first instance
   - [ ] Document any deviations from plan

### Decision Points

- **Certificate Strategy**: Self-signed for demo vs. CA-signed
- **Backup Solution**: Local disk vs. external backup service
- **Monitoring**: Built-in tools vs. external monitoring (Prometheus/Grafana)
- **Load Balancer**: Software-based (Nginx) vs. hardware-based (future)

### Questions for User

1. Do you have access to Ping Identity Support Portal for software downloads?
2. What are the connection details for the MS SQL databases?
3. What are the connection details for Active Directory?
4. Do you have preferred naming conventions for base DNs and realms?
5. Do you have existing certificates, or should we generate self-signed?

---

## Appendix: Quick Reference

### Service URLs (Planned)

| Service | Instance | Admin Console URL | Port |
|---------|----------|------------------|------|
| PingDS | DS1 | https://localhost:8443 | 8443 |
| PingDS | DS2 | https://localhost:8444 | 8444 |
| PingDS | DS3 | https://localhost:8445 | 8445 |
| PingDS | DS4 | https://localhost:8446 | 8446 |
| PingIDM | IDM1 | https://localhost:8453/admin | 8453 |
| PingIDM | IDM2 | https://localhost:8454/admin | 8454 |
| PingAM | AM1 | http://localhost:8100/am/console | 8100 |
| PingAM | AM2 | http://localhost:8101/am/console | 8101 |

### Default Credentials (Demo Only - Change in Production)

| Service | Username | Password |
|---------|----------|----------|
| PingDS | cn=Directory Manager | password |
| PingIDM | admin | admin |
| PingAM | amadmin | password |

### Key Commands

**Check DS Replication**:
```bash
docker exec ds1-container dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname localhost --port 4444 \
  --trustAll --no-prompt
```

**Check IDM Status**:
```bash
curl -k -u admin:admin https://localhost:8453/openidm/info/ping
```

**Check AM Health**:
```bash
curl http://localhost:8100/am/isAlive.jsp
```

**View Docker Logs**:
```bash
docker logs -f ds1-container
docker logs -f idm1-container
docker logs -f am1-container
```

---

**Document Maintenance**:
- Update this document after completing each phase
- Log all issues and resolutions
- Keep next steps current
- Record all configuration changes

---

*Last Updated*: 2025-11-04
*Next Review*: Upon completion of each phase

---

*End of Workflow Document*
