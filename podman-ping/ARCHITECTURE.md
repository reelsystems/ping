# Ping Identity Platform Architecture on Podman

## Table of Contents

- [System Overview](#system-overview)
- [Architectural Principles](#architectural-principles)
- [Component Architecture](#component-architecture)
- [Data Flow Patterns](#data-flow-patterns)
- [Security Architecture](#security-architecture)
- [High Availability and Scalability](#high-availability-and-scalability)
- [Integration Patterns](#integration-patterns)
- [Deployment Considerations](#deployment-considerations)
- [Podman vs Kubernetes](#podman-vs-kubernetes)
- [Design Decisions](#design-decisions)

## System Overview

The Ping Identity Platform provides a comprehensive identity and access management (IAM) solution consisting of multiple interconnected services. This architecture document describes the design, interactions, and deployment considerations for running the platform on RHEL using Podman.

### Platform Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                       │
├──────────────────┬───────────────────┬────────────────────────┤
│    Login UI      │     Admin UI      │   External Clients      │
│  (User-facing)   │   (Management)    │   (API consumers)       │
└────────┬─────────┴─────────┬─────────┴──────────┬──────────────┘
         │                   │                    │
┌────────▼───────────────────▼────────────────────▼──────────────┐
│                      Gateway Layer                              │
│                   Identity Gateway (IG)                         │
│          (Reverse Proxy, Policy Enforcement)                    │
└────────┬─────────────────┬───────────────────┬─────────────────┘
         │                 │                   │
┌────────▼─────────────────▼───────────────────▼─────────────────┐
│                      Core Services Layer                        │
├─────────────────┬────────────────────┬────────────────────────┤
│  Access Manager │  Identity Manager  │   DS Proxy             │
│      (AM)       │      (IDM)         │   (Load Balancer)      │
│  (AuthN/AuthZ)  │  (Provisioning)    │   (Config Store)       │
└────────┬────────┴──────────┬─────────┴────────┬───────────────┘
         │                   │                  │
┌────────▼───────────────────▼──────────────────▼────────────────┐
│                      Data Layer                                 │
├─────────────────┬──────────────────┬──────────────────────────┤
│  Directory      │   Directory      │      MySQL               │
│  Server DS-1    │   Server DS-2    │   (IDM Repository)       │
│  (User Store,   │  (Replication)   │   (Workflow, Audit)      │
│   CTS Store)    │                  │                          │
└─────────────────┴──────────────────┴──────────────────────────┘
```

### Technology Stack

- **Container Runtime**: Podman 4.x (OCI-compliant, daemonless)
- **Container Orchestration**: Podman Compose
- **Operating System**: RHEL 8.x/9.x (or compatible)
- **Directory Protocol**: LDAP/LDAPS (RFC 4511)
- **Identity Protocols**: OAuth 2.0, OpenID Connect, SAML 2.0
- **Database**: MySQL 8.0
- **Networking**: Podman bridge network with DNS resolution

## Architectural Principles

### 1. Separation of Concerns

Each component has a distinct responsibility:

- **DS (Directory Server)**: Data persistence and LDAP operations
- **AM (Access Manager)**: Authentication, authorization, SSO
- **IDM (Identity Manager)**: User lifecycle, provisioning, governance
- **IG (Identity Gateway)**: API gateway, policy enforcement
- **UI Components**: User interaction and administration

### 2. Loose Coupling

Components communicate via well-defined APIs:

- LDAP protocol for DS access
- REST APIs for AM, IDM, IG
- Standard protocols (OAuth, OIDC, SAML) for federation

### 3. Scalability Through Replication

- **DS Multi-Master Replication**: Horizontal scaling of directory services
- **Stateless Services**: AM, IDM, IG can scale horizontally
- **Session Externalization**: CTS (Core Token Service) in DS for session storage

### 4. Defense in Depth

Multiple security layers:

- Network isolation via Podman networks
- Authentication at each service layer
- Encryption in transit (LDAPS, HTTPS)
- Encryption at rest for sensitive data
- Least privilege access controls

### 5. Data Persistence

- **Volumes**: All stateful data in named Podman volumes
- **Separation**: Each service has dedicated storage
- **Backup Strategy**: Volume-based backups for disaster recovery

## Component Architecture

### Directory Server (DS)

#### Purpose
Provides LDAP directory services for storing and managing identity data, authentication credentials, and AM runtime data (CTS).

#### Architecture

```
┌─────────────────────────────────────────────────────┐
│              Directory Server Instance               │
├─────────────────────────────────────────────────────┤
│  ┌─────────────────┐         ┌──────────────────┐  │
│  │  LDAP Listener  │◄────────►  Admin Port      │  │
│  │  (1389/1636)    │         │  (4444)          │  │
│  └────────┬────────┘         └──────────────────┘  │
│           │                                          │
│  ┌────────▼─────────────────────────────────────┐  │
│  │         Backend Database Engine               │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────┐  │  │
│  │  │ User DB │  │ CTS DB  │  │  Index DB   │  │  │
│  │  └─────────┘  └─────────┘  └─────────────┘  │  │
│  └───────────────────┬──────────────────────────┘  │
│                      │                              │
│  ┌───────────────────▼──────────────────────────┐  │
│  │         Replication Engine                    │  │
│  │  (Multi-Master, Port 8989)                    │  │
│  └───────────────────┬──────────────────────────┘  │
│                      │                              │
│  ┌───────────────────▼──────────────────────────┐  │
│  │         Persistent Storage                    │  │
│  │      /opt/opendj/data                         │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

#### Key Features

1. **Schema**: Extensible LDAP schema supporting standard and custom object classes
2. **Indexing**: Optimized indexes for common queries (eq, sub, pres)
3. **Replication**: Multi-master topology with automatic conflict resolution
4. **Backup**: Online backup capability without service interruption
5. **Monitoring**: JMX monitoring, LDAP monitoring entries, HTTP status endpoints

#### Data Model

```
dc=example,dc=com (Base DN)
├── ou=people (User Entries)
│   ├── uid=user1,ou=people,dc=example,dc=com
│   └── uid=user2,ou=people,dc=example,dc=com
├── ou=groups (Group Entries)
│   ├── cn=admins,ou=groups,dc=example,dc=com
│   └── cn=users,ou=groups,dc=example,dc=com
├── ou=am-config (AM Configuration Store - via DS-Proxy)
│   ├── ou=services
│   └── ou=policies
└── ou=tokens (CTS - Core Token Service)
    ├── coreTokenId=token1,...
    └── coreTokenId=token2,...
```

#### Replication Strategy

**Topology**: Multi-master (all servers are read-write)

**Replication Flow**:
1. Write operation occurs on DS-1
2. Change recorded in changelog
3. Change transmitted to DS-2 via replication port (8989)
4. DS-2 applies change locally
5. Bidirectional: DS-2 writes also replicate to DS-1

**Conflict Resolution**:
- Timestamp-based: Latest write wins
- Modify conflicts: Per-attribute resolution
- Delete conflicts: Delete takes precedence

**Monitoring Replication Lag**:
- Acceptable lag: < 100ms under normal load
- Warning threshold: > 500ms
- Critical threshold: > 5000ms

### DS Proxy

#### Purpose
LDAP proxy distributing AM configuration store requests across DS instances for load balancing and high availability.

#### Architecture

```
┌──────────────────────────────────────────┐
│          DS Proxy Instance                │
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │      LDAP Proxy Listener           │  │
│  │        (1391/1638)                 │  │
│  └──────────────┬─────────────────────┘  │
│                 │                         │
│  ┌──────────────▼─────────────────────┐  │
│  │    Load Balancer / Router          │  │
│  │  - Round-robin distribution        │  │
│  │  - Health checking                 │  │
│  │  - Failover logic                  │  │
│  └──────────────┬─────────────────────┘  │
│                 │                         │
│  ┌──────────────▼─────────────────────┐  │
│  │       Backend Connections          │  │
│  │                                    │  │
│  │  ┌──────────┐    ┌──────────┐    │  │
│  │  │  DS-1    │    │  DS-2    │    │  │
│  │  │  :1389   │    │  :1389   │    │  │
│  │  └──────────┘    └──────────┘    │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

#### Use Case
AM's configuration store requires high availability. DS-Proxy ensures:
- Load distribution across DS instances
- Automatic failover if a DS instance is down
- Connection pooling for performance
- Separation of configuration data from user data

### Access Manager (AM)

#### Purpose
Provides authentication, authorization, SSO, and federation services. Central policy enforcement point for access decisions.

#### Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Access Manager (AM)                         │
├─────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────┐ │
│  │           Web Container (Tomcat)                    │ │
│  │                  (Port 8080/8443)                   │ │
│  └─────────────────────┬───────────────────────────────┘ │
│                        │                                  │
│  ┌─────────────────────▼───────────────────────────────┐ │
│  │             Authentication Module                    │ │
│  │  - Username/Password                                 │ │
│  │  - OAuth 2.0 / OpenID Connect                        │ │
│  │  - SAML 2.0                                          │ │
│  │  - Multi-factor Authentication                       │ │
│  └─────────────────────┬───────────────────────────────┘ │
│                        │                                  │
│  ┌─────────────────────▼───────────────────────────────┐ │
│  │             Authorization Module                     │ │
│  │  - Policy Engine                                     │ │
│  │  - Entitlements                                      │ │
│  │  - Resource-based permissions                        │ │
│  └─────────────────────┬───────────────────────────────┘ │
│                        │                                  │
│  ┌─────────────────────▼───────────────────────────────┐ │
│  │           Session Management (CTS)                   │ │
│  │  - Session tokens in DS                              │ │
│  │  - Stateless sessions (JWT)                          │ │
│  └─────────────────────┬───────────────────────────────┘ │
│                        │                                  │
│  ┌─────────────────────▼───────────────────────────────┐ │
│  │              Data Store Connections                  │ │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────────┐   │ │
│  │  │User Store│  │CTS Store │  │Configuration    │   │ │
│  │  │(DS 1/2)  │  │(DS 1/2)  │  │Store (DS-Proxy) │   │ │
│  │  └──────────┘  └──────────┘  └─────────────────┘   │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### Key Components

1. **Authentication Module**:
   - Authentication chains (multiple methods)
   - Adaptive authentication (risk-based)
   - Federation protocols (SAML, OAuth, OIDC)

2. **Policy Engine**:
   - Resource-based policies
   - Attribute-based access control (ABAC)
   - Dynamic policy evaluation

3. **Session Management**:
   - Server-side sessions (stored in CTS)
   - Client-side sessions (JWT)
   - Session failover via CTS replication

4. **Token Services**:
   - OAuth 2.0 authorization server
   - Token introspection and validation
   - JWT signing and encryption

#### Data Stores

| Store Type | Purpose | Backend | Characteristics |
|------------|---------|---------|-----------------|
| User Store | Authentication credentials, user profiles | DS-1, DS-2 | Read-heavy, high availability |
| CTS Store | Sessions, OAuth tokens, SAML artifacts | DS-1, DS-2 | Write-heavy, short TTL |
| Config Store | AM configuration, policies, services | DS-Proxy → DS-1/DS-2 | Read-heavy, infrequent updates |

#### Session Architecture

**Server-Side Sessions**:
```
1. User authenticates → AM creates session
2. Session data written to CTS (DS)
3. Session ID returned to client (cookie)
4. Client presents session ID on subsequent requests
5. AM validates session from CTS
6. CTS replication ensures failover capability
```

**Stateless Sessions (JWT)**:
```
1. User authenticates → AM creates JWT
2. JWT signed with AM's private key
3. JWT returned to client (no server storage)
4. Client presents JWT on subsequent requests
5. AM validates JWT signature and expiration
6. No CTS lookup required (better performance)
```

### Identity Manager (IDM)

#### Purpose
Manages user lifecycle, provisioning to external systems, reconciliation, and identity governance.

#### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Identity Manager (IDM)                          │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │           OSGi Framework (Felix)                       │  │
│  │                (Port 8080/8443)                        │  │
│  └────────────────────┬──────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐  │
│  │            RESTful API Layer                          │  │
│  │  - Managed Objects (users, roles, orgs)               │  │
│  │  - System Objects (external systems)                  │  │
│  │  - Workflow APIs                                      │  │
│  └────────────────────┬──────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐  │
│  │            Synchronization Engine                     │  │
│  │  - Mappings: Source → Target                          │  │
│  │  - Policies: CREATE, UPDATE, DELETE, IGNORE           │  │
│  │  - Transformations: Script-based                      │  │
│  └────────────────────┬──────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐  │
│  │         Connector Framework (ICF)                     │  │
│  │  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │  │
│  │  │LDAP Connector│ │AD Connector │ │REST Connector│  │  │
│  │  └──────┬──────┘ └──────┬───────┘ └──────┬───────┘  │  │
│  │         │                │                │          │  │
│  │  ┌──────▼────────────────▼────────────────▼───────┐ │  │
│  │  │         External Systems                        │ │  │
│  │  │  - Active Directory                             │ │  │
│  │  │  - HR Systems                                   │ │  │
│  │  │  - Cloud Applications                           │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────▼──────────────────────────────────┐  │
│  │         Repository Layer                              │  │
│  │  - Managed Objects Storage                            │  │
│  │  - Workflow State                                     │  │
│  │  - Audit Logs                                         │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │           MySQL Database                         │ │  │
│  │  │  Tables: managedobjects, links, audit*, etc     │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

#### Key Concepts

**1. Managed Objects**:
- Represent identities within IDM (users, roles, organizations)
- Stored in MySQL repository
- Accessible via REST API
- Support for custom schemas

**2. System Objects**:
- Represent identities in external systems (AD users, database records)
- Accessed via connectors
- Not stored in IDM (pass-through)
- Synchronized to/from managed objects

**3. Mappings**:
```
Source System → Transformation Logic → Target System

Example:
system/ad/account → [Script/Policy] → managed/user

Attributes:
  sAMAccountName → userName
  givenName → givenName
  sn → sn
  mail → mail
```

**4. Synchronization Situations**:

| Situation | Description | Default Action |
|-----------|-------------|----------------|
| ABSENT | Source exists, target doesn't | CREATE |
| FOUND | Source and target exist, match | UPDATE |
| AMBIGUOUS | Multiple targets match source | IGNORE (error) |
| MISSING | Target exists, source doesn't | DELETE |
| UNQUALIFIED | Source doesn't meet criteria | IGNORE |

#### Connector Architecture

```
┌─────────────────────────────────────────────────────────┐
│               Connector Framework                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │         Provisioner Configuration                   │ │
│  │  - Connection details                               │ │
│  │  - Authentication credentials                       │ │
│  │  - Object types and attributes                      │ │
│  │  - Operation configuration                          │ │
│  └──────────────────────┬─────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼──────────────────────────────┐ │
│  │           Connector Operations                      │ │
│  │  - CREATE: Create accounts                          │ │
│  │  - READ: Query accounts                             │ │
│  │  - UPDATE: Modify accounts                          │ │
│  │  - DELETE: Remove accounts                          │ │
│  │  - SEARCH: Find accounts                            │ │
│  │  - SYNC: Detect changes                             │ │
│  │  - TEST: Validate connection                        │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│  ┌──────────────────────▼──────────────────────────────┐ │
│  │        Protocol/API Layer                           │ │
│  │  - LDAP (for DS, AD)                                │ │
│  │  - REST (for cloud apps)                            │ │
│  │  - JDBC (for databases)                             │ │
│  │  - SCIM (for modern identity APIs)                  │ │
│  └──────────────────────┬──────────────────────────────┘ │
│                         │                                │
│                   External System                         │
└─────────────────────────────────────────────────────────┘
```

### Identity Gateway (IG)

#### Purpose
Reverse proxy and API gateway providing authentication, authorization, and policy enforcement for backend services.

#### Architecture

```
┌─────────────────────────────────────────────────────────┐
│            Identity Gateway (IG)                         │
├─────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────┐  │
│  │          HTTP/HTTPS Listener                       │  │
│  │             (Port 8080/8443)                       │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                  │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │             Router                                 │  │
│  │  - Route selection based on conditions             │  │
│  │  - URL pattern matching                            │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                  │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │             Filter Chain                           │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐ │  │
│  │  │  1. OAuth2ResourceServerFilter              │ │  │
│  │  │     - Token validation                       │ │  │
│  │  │     - Token introspection (via AM)           │ │  │
│  │  └──────────────────────────────────────────────┘ │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐ │  │
│  │  │  2. PolicyEnforcementFilter                  │ │  │
│  │  │     - Authorization decisions (via AM)       │ │  │
│  │  │     - Resource-based access control          │ │  │
│  │  └──────────────────────────────────────────────┘ │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐ │  │
│  │  │  3. HeaderFilter                             │ │  │
│  │  │     - Add/remove headers                     │ │  │
│  │  │     - Identity injection                     │ │  │
│  │  └──────────────────────────────────────────────┘ │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐ │  │
│  │  │  4. TransformationFilter (optional)          │ │  │
│  │  │     - Request/response transformation        │ │  │
│  │  │     - Data mapping                           │ │  │
│  │  └──────────────────────────────────────────────┘ │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                  │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │           Client Handler                          │  │
│  │  - HTTP client for backend                        │  │
│  │  - Connection pooling                             │  │
│  │  - SSL/TLS configuration                          │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                  │
│                 Backend Service                          │
│              (AM, IDM, Custom APIs)                      │
└─────────────────────────────────────────────────────────┘
```

#### Use Cases

**1. API Gateway**:
```
Client → IG → Backend API
       ↓
    [Token Validation]
    [Authorization]
    [Rate Limiting]
    [Header Injection]
```

**2. Zero Trust Gateway**:
```
External Client → IG → Internal Service
                 ↓
              [AuthN required]
              [AuthZ per-request]
              [Audit logging]
```

**3. Legacy Integration**:
```
Modern Client (OAuth) → IG → Legacy App (Basic Auth)
                        ↓
                    [Token → Credential]
                    [Header transformation]
```

## Data Flow Patterns

### Authentication Flow (AM)

```
1. User → Browser → Login UI
2. Login UI → AM: POST /am/json/authenticate
3. AM → DS (User Store): LDAP BIND (validate credentials)
4. DS → AM: Success
5. AM → DS (CTS Store): LDAP ADD (create session token)
6. DS → AM: Success
7. AM → Login UI: Session token (cookie)
8. Login UI → User: Redirect to application
```

### Provisioning Flow (IDM)

```
1. HR System Update: New employee hired
2. IDM Reconciliation: Detects new record
3. IDM Sync Engine: Evaluates mapping policies
4. IDM → MySQL: CREATE managed/user
5. IDM → DS (via LDAP Connector): ADD user entry
6. IDM → AD (via AD Connector): CREATE user account
7. IDM → Audit (MySQL): Log provisioning activity
8. IDM → Workflow Engine: Trigger approval (if configured)
```

### Token Validation Flow (IG)

```
1. Client → IG: GET /api/resource
   Header: Authorization: Bearer <token>
2. IG → AM: POST /am/oauth2/introspect
   Body: token=<token>&client_id=ig-client
3. AM → DS (CTS Store): LDAP SEARCH (find token)
4. DS → AM: Token data
5. AM → IG: {"active": true, "scope": "read", ...}
6. IG: Evaluate authorization policy
7. IG → Backend: GET /api/resource
   Header: X-User-ID: user123
8. Backend → IG: Response
9. IG → Client: Response
```

### Replication Flow (DS)

```
Time T0: User update on DS-1
├─ DS-1: LDAP MODIFY uid=user1,ou=people,dc=example,dc=com
├─ DS-1: Update local database
├─ DS-1: Write to changelog (CSN: change sequence number)
├─ DS-1: Notify replication engine
│
Time T0 + 10ms: Replication to DS-2
├─ DS-1 → DS-2 (port 8989): Replicate change (CSN: xyz)
├─ DS-2: Receive change
├─ DS-2: Check CSN (ensure ordering)
├─ DS-2: Apply change to local database
├─ DS-2: Update changelog
└─ DS-2 → DS-1 (port 8989): ACK
```

## Security Architecture

### Defense in Depth Layers

**Layer 1: Network Isolation**
- Podman bridge network isolates containers
- Only necessary ports exposed to host
- Firewall rules restrict external access

**Layer 2: Transport Encryption**
- LDAPS (port 1636) for DS connections
- HTTPS (port 8443) for web services
- TLS 1.2+ with strong cipher suites

**Layer 3: Authentication**
- Multi-factor authentication support in AM
- Service accounts for inter-component communication
- Credential rotation policies

**Layer 4: Authorization**
- Role-based access control (RBAC) in IDM
- Policy-based access control (PBAC) in AM
- Attribute-based access control (ABAC) via IG

**Layer 5: Audit and Monitoring**
- Comprehensive audit logs in IDM MySQL repository
- AM session auditing to CTS
- Container logs via Podman logging drivers

### Secrets Management

**Current Implementation**:
- Environment variables in `podman-compose.yml`
- Encrypted passwords in IDM connectors

**Production Recommendations**:
1. Use Podman secrets:
   ```bash
   echo "secret" | podman secret create my-secret -
   ```
2. Mount secrets as files in containers
3. Use external secret management (Vault, etc.)
4. Never commit secrets to version control

### Certificate Management

**Self-Signed Certificates** (Development):
```
shared-certs/
├── ca.crt (CA certificate)
├── server.crt (Server certificate)
├── server.key (Private key)
└── truststore.jks (Java truststore)
```

**Production Certificates**:
- Obtain certificates from trusted CA
- Use wildcard certificates for simplicity
- Implement certificate rotation process
- Monitor certificate expiration

### Network Security

```
┌────────────────────────────────────────────────────────┐
│                    Host Firewall                        │
│  - Allow: 8080-8086, 8443-8448 (from specific IPs)     │
│  - Deny: All other incoming                             │
└────────────────────────────────────────────────────────┘
                        │
┌────────────────────────────────────────────────────────┐
│              Podman Bridge Network                      │
│               (Internal: 172.28.0.0/16)                 │
│  - Containers can communicate freely                    │
│  - DNS resolution provided                              │
└────────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
   ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
   │   AM    │    │   IDM   │    │   IG    │
   │172.28.0 │    │172.28.0 │    │172.28.0 │
   │   .30   │    │   .40   │    │   .50   │
   └─────────┘    └─────────┘    └─────────┘
```

## High Availability and Scalability

### Current Architecture (Single Host)

The provided configuration runs all services on a single host with limited HA:

**High Availability Components**:
- DS-1 and DS-2 (multi-master replication)
- DS-Proxy (distributes load, provides failover)

**Single Points of Failure**:
- AM (single instance)
- IDM (single instance)
- IG (single instance)
- MySQL (single instance)

### Scaling Strategies

#### Horizontal Scaling (Multiple Hosts)

**Option 1: Podman with External Load Balancer**
```
        ┌─────────────────┐
        │  Load Balancer  │
        │   (HAProxy)     │
        └────────┬────────┘
                 │
      ┌──────────┼──────────┐
      │          │          │
┌─────▼────┐ ┌──▼──────┐ ┌─▼────────┐
│ Host 1   │ │ Host 2  │ │ Host 3   │
│ - AM     │ │ - AM    │ │ - AM     │
│ - IDM    │ │ - IDM   │ │ - IDM    │
│ - IG     │ │ - IG    │ │ - IG     │
└──────────┘ └─────────┘ └──────────┘
      │          │          │
      └──────────┼──────────┘
                 │
        ┌────────▼────────┐
        │  Shared DS      │
        │  Cluster        │
        │  (3+ nodes)     │
        └─────────────────┘
```

**Option 2: Kubernetes Migration**
- For true cloud-native HA
- Leverage Kubernetes services and ingress
- Auto-scaling based on load
- See [Podman vs Kubernetes](#podman-vs-kubernetes)

#### Vertical Scaling

Increase resources for containers:

```yaml
services:
  am:
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '4.0'
    environment:
      JAVA_OPTS: "-Xms4g -Xmx6g"
```

#### Database Scaling

**MySQL Replication**:
```
IDM → MySQL Primary (writes)
     ├─ MySQL Replica 1 (reads)
     └─ MySQL Replica 2 (reads)
```

**MySQL Cluster** (advanced):
- MySQL Group Replication
- Multi-master writes
- Automatic failover

### Load Balancing Considerations

**DS Load Balancing**:
- Built-in via DS-Proxy for AM config store
- Application-level for user store (AM uses multiple DS)

**AM Load Balancing**:
- Requires external load balancer (HAProxy, Nginx)
- Session stickiness not required (CTS provides session failover)
- Health check: `/am/isAlive.jsp`

**IDM Load Balancing**:
- Requires external load balancer
- MySQL handles concurrent connections
- Health check: `/openidm/info/ping`

**IG Load Balancing**:
- Stateless, easy to load balance
- External load balancer recommended
- Health check: `/ig/status`

## Integration Patterns

### Pattern 1: Centralized Authentication (SSO)

```
Application 1 ─┐
Application 2 ─┼─→ IG ─→ AM (AuthN/AuthZ) ─→ DS (User Store)
Application 3 ─┘
```

**Use Case**: Multiple applications require SSO
**Flow**:
1. User accesses Application 1
2. IG intercepts request (no session)
3. IG redirects to AM login
4. User authenticates with AM
5. AM creates session in CTS (DS)
6. User redirected back to Application 1
7. IG validates session with AM
8. User accesses Application 2 (already authenticated, SSO)

### Pattern 2: API Gateway with OAuth

```
Mobile App ─┐
Web App    ─┼─→ IG ─→ [Token Validation] ─→ AM ─→ Backend API
Third-party─┘        [Authorization]
```

**Use Case**: Securing REST APIs with OAuth 2.0
**Flow**:
1. Client obtains OAuth token from AM
2. Client includes token in API request to IG
3. IG validates token with AM (introspection)
4. IG enforces authorization policy
5. IG forwards request to backend API
6. Response returned through IG

### Pattern 3: Identity Provisioning

```
HR System ─→ IDM ─┬─→ DS (LDAP)
                  ├─→ AM (implicit via DS)
                  ├─→ Active Directory
                  ├─→ Office 365
                  └─→ Custom Applications
```

**Use Case**: Automated user lifecycle management
**Flow**:
1. HR system updates employee status
2. IDM reconciliation detects change
3. IDM updates managed/user in MySQL
4. IDM provisions to DS (available for AM authentication)
5. IDM provisions to AD (for Windows login)
6. IDM provisions to cloud apps (Office 365, etc.)
7. All changes logged to audit tables

### Pattern 4: Federation

```
Partner IdP ─→ AM (SAML SP) ─→ Internal Apps
```

**Use Case**: Federated authentication with external partners
**Flow**:
1. User attempts to access internal app
2. AM redirects to Partner IdP (SAML SSO)
3. User authenticates at Partner IdP
4. Partner IdP returns SAML assertion to AM
5. AM validates assertion, creates local session
6. User granted access to internal app

## Deployment Considerations

### Resource Requirements

**Minimum (Development)**:
- 8GB RAM
- 4 CPU cores
- 50GB disk

**Recommended (Production)**:
- 16GB+ RAM
- 8+ CPU cores
- 200GB+ disk (including logs and backups)

**Per-Component Estimates**:
| Component | Memory | CPU | Disk |
|-----------|--------|-----|------|
| DS (each) | 2GB | 1.0 | 20GB |
| AM | 2GB | 1.0 | 10GB |
| IDM | 2GB | 1.0 | 10GB |
| IG | 1GB | 0.5 | 5GB |
| MySQL | 2GB | 1.0 | 20GB |
| UI (each) | 512MB | 0.5 | 1GB |

### Persistent Storage

**Volume Locations** (bind mounts for better control):
```bash
/var/lib/ping/
├── ds-1/
│   └── data/
├── ds-2/
│   └── data/
├── am/
│   └── data/
├── idm/
│   └── data/
├── mysql/
│   └── data/
└── certs/
    └── shared/
```

**Backup Strategy**:
- Daily automated backups of volumes
- Retain 7 daily, 4 weekly, 12 monthly backups
- Offsite backup replication
- Quarterly restore testing

### Monitoring and Observability

**Metrics Collection**:
```
Podman → Prometheus Exporter → Prometheus → Grafana
         (cAdvisor)
```

**Key Metrics**:
- CPU, memory, disk usage per container
- Network traffic
- DS replication lag
- AM session count
- IDM reconciliation success rate
- API response times

**Logging**:
```
Containers → Podman logging → Rsyslog → ELK Stack / Splunk
```

**Health Checks**:
- Podman health checks (configured in Containerfiles)
- External monitoring (Nagios, Zabbix)
- Application-level health endpoints

### Disaster Recovery

**RTO (Recovery Time Objective)**: 4 hours
**RPO (Recovery Point Objective)**: 1 hour

**DR Procedures**:
1. Stop all services
2. Restore volumes from backup
3. Start services in order:
   - MySQL
   - DS-1, DS-2
   - DS-Proxy
   - AM, IDM, IG
   - UIs
4. Verify replication status
5. Validate service connectivity
6. Run smoke tests

**DR Testing**:
- Quarterly full DR drills
- Monthly partial restores
- Automated restore scripts

## Podman vs Kubernetes

### When to Use Podman

**Advantages**:
- Simpler setup (no cluster management)
- Lower resource overhead
- Better for single-host deployments
- Rootless containers (better security)
- Docker compatibility
- No daemon required

**Suitable For**:
- Development and testing
- Small to medium deployments (< 1000 users)
- Single-host production (with caveats)
- Organizations without Kubernetes expertise
- Air-gapped environments

### When to Migrate to Kubernetes

**Kubernetes Advantages**:
- True high availability
- Horizontal pod autoscaling
- Self-healing (automatic restarts)
- Rolling updates with zero downtime
- Service discovery and load balancing
- Centralized configuration (ConfigMaps, Secrets)
- Rich ecosystem (Helm, Operators)

**Migration Triggers**:
- User base > 1000
- HA requirements mandate multi-host
- Need for auto-scaling
- Compliance requires HA (e.g., SOC 2)
- Organization adopts Kubernetes elsewhere

### Migration Path

**Phase 1: Containerization** (Current State)
- Containerfiles created ✓
- Podman Compose orchestration ✓
- Configuration externalized ✓

**Phase 2: Kubernetes Preparation**
- Convert Compose to Kubernetes manifests
- Use Kompose tool: `kompose convert -f podman-compose.yml`
- Create Helm charts
- Define PersistentVolumeClaims
- Set up Ingress

**Phase 3: Kubernetes Deployment**
- Deploy to test Kubernetes cluster
- Validate functionality
- Performance testing
- Production cutover

**Example Kubernetes Manifest** (DS deployment):
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ping-ds
spec:
  serviceName: ping-ds
  replicas: 2
  selector:
    matchLabels:
      app: ping-ds
  template:
    metadata:
      labels:
        app: ping-ds
    spec:
      containers:
      - name: ds
        image: ping-ds:latest
        ports:
        - containerPort: 1389
          name: ldap
        - containerPort: 8989
          name: replication
        volumeMounts:
        - name: data
          mountPath: /opt/opendj/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```

## Design Decisions

### Why Multi-Master DS Replication?

**Decision**: Use multi-master (multimaster) replication instead of master-replica.

**Rationale**:
- Eliminates single point of failure for writes
- All DS instances can accept writes
- Simplifies application configuration (no write/read routing)
- Automatic conflict resolution

**Trade-offs**:
- Slightly more complex setup
- Requires conflict resolution strategy
- More network traffic between replicas

### Why Separate DS-Proxy for AM Config Store?

**Decision**: Use DS-Proxy for AM configuration store instead of direct DS access.

**Rationale**:
- Load distribution across DS instances
- Automatic failover if DS instance fails
- Isolates AM config traffic from user traffic
- Allows independent scaling of config store

**Trade-offs**:
- Additional component to manage
- Extra network hop (minimal latency)

### Why MySQL for IDM Instead of Postgres?

**Decision**: Use MySQL 8.0 for IDM repository.

**Rationale**:
- ForgeRock officially supports MySQL
- Better JSON support in MySQL 8.0
- Larger community and ecosystem
- Easier to find MySQL expertise

**Trade-offs**:
- Postgres may offer better features for some use cases
- MySQL licensing considerations (use MariaDB alternative if needed)

### Why Static IP Assignments?

**Decision**: Use static IP addresses for containers in the Podman network.

**Rationale**:
- Predictable networking for troubleshooting
- Easier to configure external monitoring
- No reliance on dynamic DNS resolution
- Simplifies firewall rules

**Trade-offs**:
- Less flexible than dynamic IPs
- Must manage IP allocation manually
- Not scalable to many containers

**Note**: In Kubernetes, this would be replaced by Service discovery.

### Why Podman Instead of Docker?

**Decision**: Use Podman instead of Docker for RHEL deployments.

**Rationale**:
- Native RHEL support (Red Hat's preferred container runtime)
- Rootless containers (better security)
- Daemonless architecture (no single point of failure)
- Docker CLI compatible (drop-in replacement)
- Better systemd integration

**Trade-offs**:
- Slightly smaller community than Docker
- Some Docker Compose features not fully compatible
- Requires Podman Compose separately

---

**Document Version**: 1.0.0
**Last Updated**: 2024-01-15
**Author**: Platform Architecture Team
