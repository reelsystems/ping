# Ping Identity Platform - Demo Environment

**Version**: 7.5.2
**Purpose**: Demo/Development environment for Ping Identity platform evaluation
**Target Scale**: ~5,000 users
**Last Updated**: 2025-11-04

---

## Overview

This repository contains the configuration, documentation, and deployment scripts for a complete Ping Identity platform demonstration environment including:

- **PingDS (Directory Server)** - 4 instances with multi-master replication
- **PingIDM (Identity Management)** - 2 instances in active-active cluster
- **PingAM (Access Manager)** - 2 instances in site-based clustering
- **Future**: PingGateway for API protection

### Key Features

- High availability architecture with redundancy at all tiers
- Consolidation of identity data from MS SQL databases and Active Directory
- Docker-based deployment for portability and consistency
- Comprehensive documentation and operational runbooks
- Production-ready architecture patterns (suitable for scaling)

---

## Quick Start

### Prerequisites

Before starting, ensure you have:
- Linux host (Ubuntu 20.04+ / RHEL 8+ / CentOS 8+)
- Docker 20.10.0+
- Docker Compose v2.0.0+
- Java 11.0.6+ or Java 17.0.3+
- 16 GB RAM (32 GB recommended)
- 100 GB disk space (SSD recommended)
- Access to Ping Identity Backstage for software downloads

### Initial Setup

1. **Clone/Download this repository**:
   ```bash
   cd /home/thepackle/repos/ping
   ```

2. **Review the documentation** (Start here!):
   - [architecture.md](architecture.md) - Complete architecture diagrams and design
   - [checklist.md](checklist.md) - Comprehensive deployment checklist
   - [WORKFLOW.md](WORKFLOW.md) - Step-by-step workflow with progress tracking
   - [CONSIDERATIONS.md](CONSIDERATIONS.md) - Production considerations and best practices
   - [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md) - Detailed installation instructions

3. **Download and extract Ping Identity software**:
   - Sign in to [Ping Identity Backstage](https://backstage.forgerock.com)
   - Download PingDS 7.5.2, PingIDM 7.5.2, and PingAM 7.5.2
   - Extract to `shared/install/` directory (see detailed instructions below)

4. **Follow the installation guide**:
   - See [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md) for complete step-by-step instructions

---

## Installation File Locations

### Where to Place Downloaded Files

All Ping Identity software distributions must be extracted to the `shared/install/` directory:

```bash
shared/install/
├── opendj/              # Extract PingDS 7.5.2 here (DS-7.5.2.zip)
├── openidm/             # Extract PingIDM 7.5.2 here (IDM-7.5.2.zip)
├── AM-7.5.2.war         # Copy PingAM WAR file here
└── README.md            # Instructions for extraction
```

### Step-by-Step Download and Extraction

1. **Access ForgeRock Backstage**:
   ```bash
   # Open browser to: https://backstage.forgerock.com
   # Sign in with your Ping Identity credentials
   ```

2. **Download PingDS 7.5.2**:
   ```bash
   # After downloading DS-7.5.2.zip to ~/Downloads/
   cd /home/thepackle/repos/ping
   unzip ~/Downloads/DS-7.5.2.zip -d shared/install/

   # Verify installation
   ls -la shared/install/opendj/bin/setup
   # Should show the setup executable
   ```

3. **Download PingIDM 7.5.2**:
   ```bash
   # After downloading IDM-7.5.2.zip to ~/Downloads/
   unzip ~/Downloads/IDM-7.5.2.zip -d shared/install/

   # Verify installation
   ls -la shared/install/openidm/startup.sh
   # Should show the startup script
   ```

4. **Download PingAM 7.5.2**:
   ```bash
   # After downloading AM-7.5.2.zip to ~/Downloads/
   unzip ~/Downloads/AM-7.5.2.zip -d /tmp/
   cp /tmp/AM-7.5.2/AM-7.5.2.war shared/install/

   # Verify installation
   ls -lh shared/install/AM-7.5.2.war
   # Should show WAR file (approximately 200-300 MB)
   ```

5. **Verify All Files**:
   ```bash
   # Run verification script
   ./shared/scripts/verify-install.sh

   # Or manually check:
   tree -L 2 shared/install/
   ```

**Important Notes**:
- Total extracted size: ~1-2 GB
- Ensure proper permissions: `chmod -R 755 shared/install/`
- Do NOT commit these files to Git (already in .gitignore)
- See [shared/install/README.md](shared/install/README.md) for detailed extraction instructions

---

## Repository Structure

```
/home/thepackle/repos/ping/
├── README.md                   # This file
├── architecture.md             # Architecture documentation with diagrams
├── checklist.md                # Complete deployment checklist
├── WORKFLOW.md                 # Deployment workflow and progress tracking
├── CONSIDERATIONS.md           # Additional guidance and best practices
├── INSTALLATION-GUIDE.md       # Step-by-step installation instructions
│
├── DS1/                        # PingDS Instance 1 (Primary)
│   ├── config/                 # DS configuration files
│   ├── data/                   # DS database files
│   ├── logs/                   # DS log files
│   ├── .env                    # Environment variables for DS1
│   ├── docker-compose.yml      # DS1 deployment config
│   └── setup.sh                # DS1 initialization script
│
├── DS2/                        # PingDS Instance 2 (Fallback)
│   └── (same structure as DS1)
│
├── DS3/                        # PingDS Instance 3 (Replica)
│   └── (same structure as DS1)
│
├── DS4/                        # PingDS Instance 4 (Replica)
│   └── (same structure as DS1)
│
├── IDM1/                       # PingIDM Instance 1 (Primary)
│   ├── conf/                   # IDM configuration files
│   ├── connectors/             # JDBC and LDAP connectors
│   ├── script/                 # IDM scripts (JS/Groovy)
│   ├── logs/                   # IDM log files
│   ├── .env                    # Environment variables for IDM1
│   ├── docker-compose.yml      # IDM1 deployment config
│   └── startup.sh              # IDM1 initialization script
│
├── IDM2/                       # PingIDM Instance 2 (Fallback)
│   └── (same structure as IDM1)
│
├── AM1/                        # PingAM Instance 1 (Primary)
│   ├── config/                 # AM configuration files
│   ├── logs/                   # AM log files
│   ├── .env                    # Environment variables for AM1
│   ├── docker-compose.yml      # AM1 deployment config
│   └── setenv.sh               # Tomcat environment setup
│
├── AM2/                        # PingAM Instance 2 (Fallback)
│   └── (same structure as AM1)
│
├── shared/                     # Shared resources
│   ├── install/                # Ping Identity software installations
│   │   ├── opendj/             # PingDS extracted here
│   │   ├── openidm/            # PingIDM extracted here
│   │   ├── AM-7.5.2.war        # PingAM WAR file
│   │   └── README.md           # Installation instructions
│   ├── certs/                  # SSL/TLS certificates
│   ├── scripts/                # Deployment and utility scripts
│   └── backups/                # Backup storage location
│
└── k8s/                        # Kubernetes migration roadmap (future)
    └── README.md               # K8s deployment guide
```

---

## Documentation Guide

### For First-Time Users

**Start with these documents in order**:

1. **[README.md](README.md)** (you are here) - Overview and quick start
2. **[architecture.md](architecture.md)** - Understand the platform architecture
3. **[checklist.md](checklist.md)** - Review all requirements before starting
4. **[INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md)** - Follow step-by-step instructions
5. **[WORKFLOW.md](WORKFLOW.md)** - Track your progress through deployment

### For Experienced Users

**Quick reference**:

- **[CONSIDERATIONS.md](CONSIDERATIONS.md)** - Best practices and production guidance
- **[architecture.md](architecture.md)** - Port allocation, network topology
- **[checklist.md](checklist.md)** - Troubleshooting and operations

---

## Key URLs (Post-Deployment)

After successful deployment, access the following web interfaces:

| Service | Instance | URL | Default Credentials |
|---------|----------|-----|---------------------|
| **PingDS** | DS1 Admin | https://localhost:8443 | cn=Directory Manager / password |
| **PingDS** | DS2 Admin | https://localhost:8444 | cn=Directory Manager / password |
| **PingDS** | DS3 Admin | https://localhost:8445 | cn=Directory Manager / password |
| **PingDS** | DS4 Admin | https://localhost:8446 | cn=Directory Manager / password |
| **PingIDM** | IDM1 Admin | https://localhost:8453/admin | admin / admin |
| **PingIDM** | IDM2 Admin | https://localhost:8454/admin | admin / admin |
| **PingAM** | AM1 Console | http://localhost:8100/am/console | amadmin / password |
| **PingAM** | AM2 Console | http://localhost:8101/am/console | amadmin / password |

**Security Note**: Change all default passwords immediately after initial setup!

---

## Quick Reference Commands

### Check Service Status

```bash
# Check all containers
docker ps -a

# Check specific service
docker logs -f ds1-container
docker logs -f idm1-container
docker logs -f am1-container
```

### PingDS Operations

```bash
# Check DS status
docker exec ds1-container status

# Check replication status
docker exec ds1-container dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname localhost --port 4444 \
  --trustAll --no-prompt

# Search LDAP
docker exec ds1-container ldapsearch \
  -h localhost -p 1636 -Z -X \
  -D "cn=Directory Manager" -w password \
  -b "dc=example,dc=com" "(objectClass=*)"
```

### PingIDM Operations

```bash
# Check IDM health
curl -k -u admin:admin https://localhost:8453/openidm/info/ping

# Test connector
curl -k -u admin:admin "https://localhost:8453/openidm/system/mssql1?_action=test"

# Check cluster status
curl -k -u admin:admin https://localhost:8453/openidm/cluster
```

### PingAM Operations

```bash
# Check AM health
curl http://localhost:8100/am/isAlive.jsp

# Check server info
curl http://localhost:8100/am/json/serverinfo/*
```

---

## Deployment Phases

This deployment is organized into phases. Track progress in [WORKFLOW.md](WORKFLOW.md):

- [x] **Phase 0**: Planning & Documentation (Complete)
- [ ] **Phase 1**: Infrastructure Setup (Docker network, directories)
- [ ] **Phase 2**: PingDS Deployment (4 instances with replication)
- [ ] **Phase 3**: PingIDM Deployment (2 instances with clustering)
- [ ] **Phase 4**: PingAM Deployment (2 instances with site configuration)
- [ ] **Phase 5**: Integration & Testing (End-to-end validation)
- [ ] **Phase 6**: Data Migration (Sync from SQL and AD)

---

## Architecture Highlights

### High Availability Design

- **PingDS**: 4-instance multi-master replication topology
  - DS1 and DS2 serve as primary/fallback for IDM and AM
  - DS3 and DS4 provide additional redundancy and load distribution
  - Automatic failover via DS replication

- **PingIDM**: Active-active clustering
  - IDM1 and IDM2 share repository backend (DS)
  - Scheduled jobs distributed across cluster
  - Seamless failover between instances

- **PingAM**: Site-based clustering
  - AM1 and AM2 in same site configuration
  - Session replication via CTS (stored in DS)
  - Load balancer required for production (future)

### Data Flow

```
External Systems (SQL, AD)
         │
         ▼
    PingIDM (Reconciliation)
         │
         ▼
    PingDS (Consolidated Identity Store)
         │
         ▼
    PingAM (Authentication & Authorization)
         │
         ▼
    Applications (SSO, OAuth2, SAML)
```

### Port Allocation Summary

**PingDS**: 1636-1639 (LDAPS), 4444-4447 (Admin), 8080-8083 (HTTP), 8443-8446 (HTTPS)
**PingIDM**: 8090-8091 (HTTP), 8453-8454 (HTTPS)
**PingAM**: 8100-8101 (HTTP)

---

## Support and Troubleshooting

### Common Issues

See [CONSIDERATIONS.md](CONSIDERATIONS.md) section "Troubleshooting Common Issues" for detailed solutions.

**Quick fixes**:

- **Service won't start**: Check logs with `docker logs <container-name>`
- **Replication lag**: Check `dsreplication status` and network connectivity
- **IDM sync fails**: Test connector with `/openidm/system/<connector>?_action=test`
- **AM authentication fails**: Verify DS connectivity and LDAP module configuration

### Getting Help

- **Official Docs**: https://docs.pingidentity.com
- **Community Forum**: https://support.pingidentity.com/s/
- **Internal Documentation**: See [WORKFLOW.md](WORKFLOW.md) for issue tracking

---

## Production Considerations

**This is a demo environment**. Before deploying to production, address:

1. **Security Hardening**:
   - Replace self-signed certificates with CA-signed certificates
   - Change all default passwords
   - Implement secrets management (Vault)
   - Configure firewalls and network segmentation

2. **High Availability**:
   - Deploy load balancers (F5, HAProxy, Nginx)
   - Implement geographic redundancy
   - Set up monitoring and alerting (Prometheus, Grafana)

3. **Backup & DR**:
   - Implement automated backup solution
   - Test disaster recovery procedures
   - Document RTO/RPO requirements

4. **Scalability**:
   - Size resources appropriately for user load
   - Plan for horizontal scaling
   - Optimize JVM and database settings

See [CONSIDERATIONS.md](CONSIDERATIONS.md) for comprehensive production guidance.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-04 | Initial documentation and project structure |

---

## License and Support

This demo environment is provided for evaluation purposes. For production deployments, contact Ping Identity for licensing and support.

- **Ping Identity Website**: https://www.pingidentity.com
- **Support Portal**: https://support.pingidentity.com

---

## Contributors

- IAM Engineering Team
- Document maintained by: [Your Team/Contact]

---

## Next Steps

1. Review [checklist.md](checklist.md) to ensure all prerequisites are met
2. Follow [INSTALLATION-GUIDE.md](INSTALLATION-GUIDE.md) for step-by-step deployment
3. Track progress in [WORKFLOW.md](WORKFLOW.md)
4. Refer to [CONSIDERATIONS.md](CONSIDERATIONS.md) for best practices

**Ready to start? Begin with the [Installation Guide](INSTALLATION-GUIDE.md)!**

---

*For questions or issues, please refer to the troubleshooting sections in the documentation or contact the IAM team.*
