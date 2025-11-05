# Ping Identity Platform Architecture
**Version 7.5.2 Deployment Architecture**

Last Updated: 2025-11-04

---

## Executive Summary

This document outlines the architectural design for deploying a highly available Ping Identity platform consisting of PingDS (Directory Server), PingIDM (Identity Management), and PingAM (Access Manager) in an on-premise environment. The platform is designed to support approximately 5,000 users with redundancy and high availability built into each layer.

---

## Table of Contents

1. [Architectural Overview](#architectural-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow Architecture](#data-flow-architecture)
4. [Network Architecture](#network-architecture)
5. [High Availability & Redundancy](#high-availability--redundancy)
6. [Security Architecture](#security-architecture)
7. [Deployment Topology](#deployment-topology)
8. [Future Considerations](#future-considerations)

---

## Architectural Overview

### Platform Components

The Ping Identity platform consists of three core services deployed in a redundant configuration:

- **PingDS (Directory Server)**: Primary identity data store with replication
- **PingIDM (Identity Management)**: Identity lifecycle management and synchronization engine
- **PingAM (Access Manager)**: Authentication, authorization, and federation services
- **PingGateway**: (Future) API gateway and policy enforcement point

### Design Principles

1. **Redundancy First**: Every component has a minimum of two instances (primary/fallback)
2. **Data Sovereignty**: PingDS serves as the consolidated source of truth
3. **Separation of Concerns**: Each service runs in isolated Docker containers
4. **Configuration Immutability**: Each instance maintains separate configuration directories
5. **Scalability**: Architecture supports horizontal scaling for increased load

---

## Component Architecture

### 1. PingDS Layer (Directory Services)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PingDS Replication Topology                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│    ┌──────────────┐         ┌──────────────┐                   │
│    │     DS1      │◄───────►│     DS2      │                   │
│    │  (Primary)   │  Sync   │  (Fallback)  │                   │
│    │              │         │              │                   │
│    │ Port: 1636   │         │ Port: 1637   │                   │
│    │ Admin: 4444  │         │ Admin: 4445  │                   │
│    │ HTTP: 8080   │         │ HTTP: 8081   │                   │
│    │ HTTPS: 8443  │         │ HTTPS: 8444  │                   │
│    └──────┬───────┘         └──────┬───────┘                   │
│           │                        │                            │
│           │  Bi-directional       │                            │
│           │  Multi-Master         │                            │
│           │  Replication          │                            │
│           │                        │                            │
│    ┌──────▼───────┐         ┌──────▼───────┐                   │
│    │     DS3      │◄───────►│     DS4      │                   │
│    │(Extra Replica)│  Sync  │(Extra Replica)│                   │
│    │              │         │              │                   │
│    │ Port: 1638   │         │ Port: 1639   │                   │
│    │ Admin: 4446  │         │ Admin: 4447  │                   │
│    │ HTTP: 8082   │         │ HTTP: 8083   │                   │
│    │ HTTPS: 8445  │         │ HTTPS: 8446  │                   │
│    └──────────────┘         └──────────────┘                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

Data Sources (External Systems):
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ MS SQL DB 1  │   │ MS SQL DB 2  │   │   Active     │
│              │   │              │   │  Directory   │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                    (via PingIDM)
```

**PingDS Characteristics:**

- **Replication Model**: Multi-master replication across all DS instances
- **Consistency**: Eventual consistency with configurable replication lag monitoring
- **Setup Profile**: `ds-evaluation` for initial setup, `am-identity-store` for AM integration
- **Base DN**: `dc=example,dc=com` (to be customized)
- **Schema**: Extended schema for PingAM and PingIDM managed objects
- **Backup Strategy**: Daily incremental backups, weekly full backups

**Instance Distribution:**

| Instance | Role | Container | LDAP Port | Admin Port | HTTP Port | HTTPS Port |
|----------|------|-----------|-----------|------------|-----------|------------|
| DS1 | Primary | ds1-container | 1636 | 4444 | 8080 | 8443 |
| DS2 | Fallback | ds2-container | 1637 | 4445 | 8081 | 8444 |
| DS3 | Replica | ds3-container | 1638 | 4446 | 8082 | 8445 |
| DS4 | Replica | ds4-container | 1639 | 4447 | 8083 | 8446 |

---

### 2. PingIDM Layer (Identity Management)

```
┌─────────────────────────────────────────────────────────────────┐
│                  PingIDM Cluster Architecture                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│    ┌──────────────────┐       ┌──────────────────┐             │
│    │      IDM1        │       │      IDM2        │             │
│    │   (Primary)      │       │   (Fallback)     │             │
│    │                  │       │                  │             │
│    │  Port: 8090      │       │  Port: 8091      │             │
│    │  HTTPS: 8453     │       │  HTTPS: 8454     │             │
│    │                  │       │                  │             │
│    │  ┌────────────┐  │       │  ┌────────────┐  │             │
│    │  │ Repository │  │       │  │ Repository │  │             │
│    │  │   (DS1)    │  │       │  │   (DS2)    │  │             │
│    │  └─────┬──────┘  │       │  └─────┬──────┘  │             │
│    └────────┼─────────┘       └────────┼─────────┘             │
│             │                           │                        │
│             ▼                           ▼                        │
│    ┌────────────────────────────────────────────┐               │
│    │         Shared DS Repository Layer         │               │
│    │      (DS1 = Primary, DS2 = Fallback)       │               │
│    └────────────────────────────────────────────┘               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

External System Connections:
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ MS SQL DB 1  │   │ MS SQL DB 2  │   │   Active     │
│  (Connector) │   │  (Connector) │   │  Directory   │
│              │   │              │   │  (Connector) │
└──────▲───────┘   └──────▲───────┘   └──────▲───────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                   Reconciliation
                   & Synchronization
                          │
                ┌─────────▼────────┐
                │   IDM1 / IDM2    │
                │  Sync Engines    │
                └─────────┬────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │  PingDS      │
                   │  Repository  │
                   └──────────────┘
```

**PingIDM Characteristics:**

- **Cluster Mode**: Active-active clustering with shared DS repository
- **Repository**: External PingDS (DS1 primary, DS2 fallback)
- **Connectors**: JDBC connectors for MS SQL databases, LDAP connector for Active Directory
- **Reconciliation**: Scheduled sync jobs consolidating data into PingDS
- **Admin UI**: Web-based admin console on HTTPS port
- **Workflow Engine**: Flowable BPMN 2.0 for approval workflows

**Instance Distribution:**

| Instance | Role | Container | HTTP Port | HTTPS Port | Repository |
|----------|------|-----------|-----------|------------|------------|
| IDM1 | Primary | idm1-container | 8090 | 8453 | DS1 (primary) |
| IDM2 | Fallback | idm2-container | 8091 | 8454 | DS2 (fallback) |

---

### 3. PingAM Layer (Access Manager)

```
┌─────────────────────────────────────────────────────────────────┐
│                  PingAM Cluster Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│         Load Balancer / Reverse Proxy (Future)                  │
│         ┌──────────────────────────────┐                        │
│         │  https://sso.example.com     │                        │
│         └──────────┬──────────┬────────┘                        │
│                    │          │                                  │
│         ┌──────────▼─────┐  ┌▼──────────────┐                  │
│         │      AM1       │  │      AM2      │                  │
│         │   (Primary)    │  │  (Fallback)   │                  │
│         │                │  │               │                  │
│         │  Port: 8100    │  │  Port: 8101   │                  │
│         │                │  │               │                  │
│         │  ┌──────────┐  │  │  ┌──────────┐ │                  │
│         │  │Config    │  │  │  │Config    │ │                  │
│         │  │Store     │  │  │  │Store     │ │                  │
│         │  │(DS1)     │  │  │  │(DS2)     │ │                  │
│         │  └────┬─────┘  │  │  └────┬─────┘ │                  │
│         │       │        │  │       │       │                  │
│         │  ┌────▼─────┐  │  │  ┌────▼─────┐ │                  │
│         │  │Identity  │  │  │  │Identity  │ │                  │
│         │  │Store     │  │  │  │Store     │ │                  │
│         │  │(DS1)     │  │  │  │(DS2)     │ │                  │
│         │  └──────────┘  │  │  └──────────┘ │                  │
│         └────────────────┘  └───────────────┘                  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

Session Failover (CTS - Core Token Service):
┌────────────────────────────────────────────┐
│         CTS Token Store (in DS)            │
│  - Session tokens                          │
│  - OAuth2 tokens                           │
│  - SAML assertions                         │
│  - Replicated across all DS instances      │
└────────────────────────────────────────────┘
```

**PingAM Characteristics:**

- **Deployment**: Site-based clustering for high availability
- **Config Store**: Shared configuration stored in DS (ou=am-config)
- **Identity Store**: User authentication data in DS (dc=example,dc=com)
- **CTS Store**: Core Token Service for sessions/tokens in DS
- **SSO**: Single Sign-On across federated applications
- **Admin Console**: Web-based administration on HTTPS

**Instance Distribution:**

| Instance | Role | Container | HTTP Port | Config Store | Identity Store |
|----------|------|-----------|-----------|--------------|----------------|
| AM1 | Primary | am1-container | 8100 | DS1 | DS1 |
| AM2 | Fallback | am2-container | 8101 | DS2 | DS2 |

---

## Data Flow Architecture

### 1. Identity Provisioning Flow

```
┌─────────────┐
│ External    │
│ Data Sources│
│ (SQL/AD)    │
└──────┬──────┘
       │
       │ (1) Scheduled Reconciliation
       ▼
┌─────────────────┐
│    PingIDM      │──┐
│  Sync Engine    │  │ (2) Transform & Map
└────────┬────────┘  │     User Attributes
         │           │
         │           ▼
         │    ┌─────────────┐
         │    │  Workflow   │
         │    │   Engine    │
         │    └─────────────┘
         │
         │ (3) Provision to DS
         ▼
┌─────────────────┐
│     PingDS      │
│  Identity Store │◄─────┐
└────────┬────────┘      │
         │               │ (4) Replication
         │               │
         └───────────────┘
```

### 2. Authentication Flow

```
┌─────────────┐
│   User      │
│   Browser   │
└──────┬──────┘
       │
       │ (1) Access Protected Resource
       ▼
┌─────────────────┐
│    PingAM       │
│  (AM1 or AM2)   │
└────────┬────────┘
         │
         │ (2) Authentication Request
         ▼
┌─────────────────┐
│     PingDS      │
│  (DS1 or DS2)   │──────┐
└────────┬────────┘      │
         │               │ (3) Validate Credentials
         │               │
         └───────────────┘
         │
         │ (4) Create Session Token
         ▼
┌─────────────────┐
│   CTS Store     │
│    (in DS)      │
└─────────────────┘
```

### 3. Data Synchronization Flow

```
External Systems           PingIDM              PingDS
─────────────────         ─────────            ─────────

┌──────────┐              ┌────────┐          ┌────────┐
│ MS SQL 1 │──Sync───────►│        │          │        │
└──────────┘              │        │          │        │
                          │  IDM   │──Write──►│  DS1   │
┌──────────┐              │ Recon- │          │        │
│ MS SQL 2 │──Sync───────►│ cilia- │          │   ↕    │
└──────────┘              │  tion  │          │ Repli- │
                          │        │          │ cation │
┌──────────┐              │        │          │        │
│  Active  │──LiveSync───►│        │          │  DS2   │
│ Directory│              │        │          │        │
└──────────┘              └────────┘          └────────┘
```

---

## Network Architecture

### Port Allocation Matrix

| Service | Instance | Container Name | LDAP/HTTP | Admin/HTTPS | Protocol |
|---------|----------|----------------|-----------|-------------|----------|
| PingDS | DS1 | ds1-container | 1636 (LDAPS) / 8080 | 4444 / 8443 | LDAP/HTTP |
| PingDS | DS2 | ds2-container | 1637 (LDAPS) / 8081 | 4445 / 8444 | LDAP/HTTP |
| PingDS | DS3 | ds3-container | 1638 (LDAPS) / 8082 | 4446 / 8445 | LDAP/HTTP |
| PingDS | DS4 | ds4-container | 1639 (LDAPS) / 8083 | 4447 / 8446 | LDAP/HTTP |
| PingIDM | IDM1 | idm1-container | 8090 (HTTP) | 8453 (HTTPS) | HTTP/REST |
| PingIDM | IDM2 | idm2-container | 8091 (HTTP) | 8454 (HTTPS) | HTTP/REST |
| PingAM | AM1 | am1-container | 8100 (HTTP) | - | HTTP |
| PingAM | AM2 | am2-container | 8101 (HTTP) | - | HTTP |

### Docker Network Configuration

```
┌───────────────────────────────────────────────────────────┐
│            Docker Bridge Network: ping-network             │
│                  Subnet: 172.20.0.0/16                     │
├───────────────────────────────────────────────────────────┤
│                                                             │
│  DS Tier                IDM Tier              AM Tier      │
│  ┌─────────┐           ┌─────────┐          ┌─────────┐   │
│  │ DS1     │           │ IDM1    │          │ AM1     │   │
│  │.0.11    │           │ .0.21   │          │ .0.31   │   │
│  └─────────┘           └─────────┘          └─────────┘   │
│  ┌─────────┐           ┌─────────┐          ┌─────────┐   │
│  │ DS2     │           │ IDM2    │          │ AM2     │   │
│  │ .0.12   │           │ .0.22   │          │ .0.32   │   │
│  └─────────┘           └─────────┘          └─────────┘   │
│  ┌─────────┐                                               │
│  │ DS3     │                                               │
│  │ .0.13   │                                               │
│  └─────────┘                                               │
│  ┌─────────┐                                               │
│  │ DS4     │                                               │
│  │ .0.14   │                                               │
│  └─────────┘                                               │
│                                                             │
└───────────────────────────────────────────────────────────┘
         │                    │                    │
         └────────────────────┴────────────────────┘
                              │
                    Host Network Interface
                   (Port Forwarding Enabled)
```

---

## High Availability & Redundancy

### Redundancy Strategy

**Tier-Based Redundancy:**

1. **PingDS Layer**:
   - Minimum 2 instances (DS1/DS2) for primary/fallback
   - Additional replicas (DS3/DS4) for load distribution and geographic redundancy
   - Multi-master replication ensures no single point of failure
   - All DS instances can serve read/write requests

2. **PingIDM Layer**:
   - 2 instances (IDM1/IDM2) in active-active cluster
   - IDM1 uses DS1 as primary repository
   - IDM2 uses DS2 as fallback repository
   - Shared configuration via clustered DS backend
   - Automatic failover between instances

3. **PingAM Layer**:
   - 2 instances (AM1/AM2) in site-based deployment
   - Shared configuration and CTS in DS cluster
   - Session replication via CTS ensures SSO continuity
   - Load balancer (future) for automatic failover

### Failure Scenarios & Recovery

| Failure Scenario | Impact | Recovery Mechanism | RTO | RPO |
|------------------|--------|-------------------|-----|-----|
| DS1 failure | None (DS2 takes over) | Automatic replication failover | < 1 min | 0 (sync replication) |
| DS1 + DS2 failure | Read/write from DS3/DS4 | Manual promotion of DS3/DS4 | < 5 min | 0 (multi-master) |
| IDM1 failure | None (IDM2 continues) | Load balancer redirects to IDM2 | < 1 min | 0 (shared repository) |
| AM1 failure | None (AM2 continues) | Load balancer redirects to AM2 | < 1 min | 0 (CTS replication) |
| Complete DS cluster failure | All services down | Restore from backup to new DS instances | < 30 min | < 24 hrs (daily backup) |
| Network partition | Eventual consistency delay | Continue operations, sync when restored | 0 | 0 (eventual consistency) |

### Monitoring & Health Checks

**Critical Metrics to Monitor:**

1. **PingDS**:
   - Replication lag (target: < 100ms)
   - Disk space utilization (alert: > 80%)
   - Connection pool status
   - LDAP response times (target: < 50ms)

2. **PingIDM**:
   - Reconciliation job status
   - Connector health
   - Repository connection status
   - Workflow queue depth

3. **PingAM**:
   - Session count and CTS token count
   - Authentication success/failure rates
   - Config/Identity store connectivity
   - Policy evaluation times

---

## Security Architecture

### Network Security

```
┌─────────────────────────────────────────────────────────────┐
│                     Firewall / Security                      │
│                                                               │
│  External Zone    │    DMZ Zone      │   Internal Zone      │
│                   │                   │                       │
│  ┌─────────┐     │   ┌─────────┐    │   ┌──────────┐       │
│  │ Internet│────────►│ PingAM  │───────►│  PingIDM  │       │
│  │ Users   │     │   │ (AM1/2) │    │   │ (IDM1/2)  │       │
│  └─────────┘     │   └─────────┘    │   └──────────┘       │
│                   │        │         │         │             │
│                   │        │         │         │             │
│                   │        ▼         │         ▼             │
│                   │   ┌─────────┐   │   ┌──────────┐       │
│                   │   │ Load    │   │   │  PingDS   │       │
│                   │   │Balancer │   │   │ (DS1-4)   │       │
│                   │   └─────────┘   │   └──────────┘       │
│                   │                  │         │             │
│                   │                  │         ▼             │
│                   │                  │   ┌──────────┐       │
│                   │                  │   │ External │       │
│                   │                  │   │  Data    │       │
│                   │                  │   │ Sources  │       │
│                   │                  │   └──────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Authentication & Authorization

- **DS**: LDAP simple bind with TLS/SSL encryption (LDAPS)
- **IDM**: Certificate-based authentication for internal services, OAuth2 for admin console
- **AM**: Supports multiple authentication modules (LDAP, RADIUS, OAuth2, SAML)
- **Secrets Management**: Kubernetes secrets or HashiCorp Vault (future consideration)

### Encryption

- **In-Transit**: TLS 1.2+ for all HTTP/LDAP communications
- **At-Rest**: Consider Linux LUKS or similar for Docker volume encryption
- **Certificates**: Self-signed for demo; production requires CA-signed certificates
- **Password Policies**: Enforced via DS password policy and AM authentication chains

---

## Deployment Topology

### Physical/Container Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                         Host Server                              │
│                    (Linux with Docker)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Directory Structure:                                            │
│  /home/thepackle/repos/ping/                                     │
│  │                                                                │
│  ├── DS1/                                                        │
│  │   ├── docker-compose.yml                                     │
│  │   ├── Dockerfile (custom)                                    │
│  │   ├── config/                                                │
│  │   ├── data/                                                  │
│  │   └── logs/                                                  │
│  │                                                                │
│  ├── DS2/                                                        │
│  │   ├── docker-compose.yml                                     │
│  │   ├── config/                                                │
│  │   ├── data/                                                  │
│  │   └── logs/                                                  │
│  │                                                                │
│  ├── DS3/ (similar structure)                                   │
│  ├── DS4/ (similar structure)                                   │
│  │                                                                │
│  ├── IDM1/                                                       │
│  │   ├── docker-compose.yml                                     │
│  │   ├── Dockerfile (custom)                                    │
│  │   ├── conf/                                                  │
│  │   ├── connectors/                                            │
│  │   ├── script/                                                │
│  │   └── logs/                                                  │
│  │                                                                │
│  ├── IDM2/ (similar structure)                                  │
│  │                                                                │
│  ├── AM1/                                                        │
│  │   ├── docker-compose.yml                                     │
│  │   ├── Dockerfile (custom)                                    │
│  │   ├── config/                                                │
│  │   └── logs/                                                  │
│  │                                                                │
│  ├── AM2/ (similar structure)                                   │
│  │                                                                │
│  ├── shared/                                                     │
│  │   ├── certs/          # SSL certificates                     │
│  │   ├── scripts/        # Deployment scripts                   │
│  │   └── backups/        # Backup storage                       │
│  │                                                                │
│  ├── architecture.md     # This file                            │
│  ├── WORKFLOW.md         # Deployment workflow                  │
│  ├── checklist.md        # Requirements checklist               │
│  └── CONSIDERATIONS.md   # Additional guidance                  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Startup Order

Critical for proper initialization:

1. **Start DS1** (primary directory server)
2. **Start DS2** (configure replication from DS1)
3. **Start DS3 and DS4** (join replication topology)
4. **Wait for DS replication convergence** (verify with `dsreplication status`)
5. **Start IDM1** (configure DS1 as repository)
6. **Start IDM2** (configure DS2 as repository, join cluster with IDM1)
7. **Configure IDM connectors** (SQL and AD)
8. **Start AM1** (first AM instance, creates config in DS)
9. **Start AM2** (joins AM site, uses replicated config)

---

## Future Considerations

### PingGateway Integration

When ready to implement PingGateway:

```
┌──────────────────────────────────────────────────────────┐
│                    PingGateway Layer                      │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  Internet ──► PingGateway ──► Policy Enforcement ──► Apps│
│                    │                                       │
│                    └──► PingAM (Policy Decision Point)   │
│                                                            │
│  Capabilities:                                            │
│  - API Gateway                                            │
│  - Rate limiting                                          │
│  - Request transformation                                 │
│  - OAuth2 resource server                                │
│  - Fine-grained authorization                             │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

**PingGateway Use Cases:**
- Protecting REST APIs with OAuth2 token validation
- Step-up authentication for sensitive operations
- Request/response transformation
- API rate limiting and throttling
- Integration with AM for policy-based access control

### Scaling Considerations

**Horizontal Scaling:**
- Add more DS replicas for read-heavy workloads
- Deploy additional IDM instances for sync job distribution
- Add AM instances behind load balancer for SSO scaling

**Vertical Scaling:**
- Increase DS memory for larger directory datasets
- Add CPU cores for IDM reconciliation performance
- Optimize AM heap size for session management

**Geographic Distribution:**
- Deploy DS replicas in multiple data centers
- Use DS replication groups to control WAN traffic
- Consider AM sites in different regions for global SSO

### Production Hardening

Items to address before production:
1. Replace self-signed certificates with CA-signed certificates
2. Implement enterprise backup solution (Veeam, NetBackup, etc.)
3. Deploy dedicated load balancers (F5, HAProxy, Nginx)
4. Implement centralized logging (Splunk, ELK stack)
5. Configure enterprise monitoring (Prometheus + Grafana, Datadog)
6. Implement secrets management (HashiCorp Vault, CyberArk)
7. Configure firewall rules between zones
8. Implement intrusion detection/prevention (IDS/IPS)
9. Establish disaster recovery procedures
10. Conduct security audit and penetration testing

---

## Appendix: Network Diagram - Full Integration

```
                           ┌─────────────────┐
                           │  External Users │
                           └────────┬────────┘
                                    │
                                    │ HTTPS
                                    ▼
                           ┌─────────────────┐
                           │ Load Balancer   │
                           │   (Future)      │
                           └────────┬────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
           ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
           │    AM1      │ │    AM2      │ │  PingGateway│
           │  (Primary)  │ │ (Fallback)  │ │   (Future)  │
           └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
                  │                │                │
                  │    ┌───────────┴────────┐       │
                  │    │                    │       │
                  ▼    ▼                    ▼       ▼
           ┌─────────────────────────────────────────────┐
           │         PingDS Cluster (DS1-DS4)            │
           │                                             │
           │  Config Store │ Identity Store │ CTS Store │
           └──────────────────┬──────────────────────────┘
                              │
                              │
                  ┌───────────┴───────────┐
                  │                       │
                  ▼                       ▼
         ┌─────────────────┐    ┌─────────────────┐
         │      IDM1       │    │      IDM2       │
         │   (Primary)     │    │   (Fallback)    │
         └────────┬────────┘    └────────┬────────┘
                  │                       │
                  │  Connectors          │
                  │                       │
    ┌─────────────┼───────────────────────┼──────────────┐
    │             │                       │              │
    ▼             ▼                       ▼              ▼
┌─────────┐  ┌─────────┐            ┌─────────┐    ┌─────────┐
│MS SQL 1 │  │MS SQL 2 │            │ Active  │    │ Other   │
│         │  │         │            │Directory│    │ Systems │
└─────────┘  └─────────┘            └─────────┘    └─────────┘
```

---

**Document Control:**
- **Version**: 1.0
- **Created**: 2025-11-04
- **Author**: IAM Architecture Team
- **Review Cycle**: Quarterly
- **Next Review**: 2025-02-04

---

*End of Architecture Document*
