# Ping Identity Platform on Podman - Documentation Index

Welcome to the Ping Identity Platform Podman deployment. This index helps you navigate the documentation and find what you need quickly.

## Getting Started

**New to this project?** Start here:

1. [Quick Start Guide](docs/QUICK_START.md) - Get running in 30 minutes
2. [README.md](README.md) - Comprehensive setup and configuration guide
3. [ARCHITECTURE.md](ARCHITECTURE.md) - Understand the platform architecture

## Documentation Structure

```
podman-ping/
├── INDEX.md                          ← You are here
├── README.md                         ← Main documentation
├── ARCHITECTURE.md                   ← Architecture and design
├── NOTES.md                          ← Development notes and tips
├── docs/
│   ├── QUICK_START.md               ← Quick start guide
│   └── PRODUCTION_CERTIFICATES.md   ← Production cert management
├── am/                              ← Access Manager
│   ├── Containerfile
│   ├── config/                      ← AM configuration files
│   └── scripts/                     ← AM setup scripts
├── ds/                              ← Directory Server
│   ├── Containerfile
│   ├── config/
│   │   ├── schema/                  ← Custom LDAP schema
│   │   └── ldif-ext/                ← LDIF initialization
│   └── scripts/                     ← DS scripts
├── ds-proxy/                        ← DS Proxy
│   ├── Containerfile
│   ├── config/
│   └── scripts/
├── idm/                             ← Identity Manager
│   ├── Containerfile
│   ├── config/                      ← IDM configuration
│   └── scripts/
├── ig/                              ← Identity Gateway
│   ├── Containerfile
│   ├── config/                      ← IG routes and policies
│   └── scripts/
├── admin-ui/                        ← Admin UI
│   └── Containerfile
├── login-ui/                        ← Login UI
│   └── Containerfile
├── compose/
│   └── podman-compose.yml           ← Main orchestration file
├── configs/
│   ├── shared/                      ← Shared configs
│   ├── mysql/
│   │   └── init.sql                 ← MySQL schema initialization
│   └── ad-connector/
│       └── provisioner.openicf-ad.json  ← AD connector config
└── scripts/
    ├── setup-certificates.sh        ← Generate SSL certificates
    ├── backup-all.sh                ← Backup script
    ├── restore-backup.sh            ← Restore script
    └── health-check.sh              ← Health check script
```

## Quick Reference by Task

### Installation and Setup

- [Prerequisites](README.md#prerequisites)
- [Quick Start](docs/QUICK_START.md)
- [System Requirements](README.md#system-requirements)
- [Firewall Configuration](README.md#firewall-configuration)
- [Building Images](README.md#2-build-all-container-images)
- [Starting Services](README.md#3-start-the-platform)

### Configuration

- [Environment Variables](README.md#environment-variables)
- [Customizing Configuration](README.md#customizing-configuration)
- [Volume Persistence](README.md#volume-persistence)
- [Certificate Setup](NOTES.md#4-certificate-management)
- [Security Considerations](README.md#security-considerations)

### Components

#### Directory Server (DS)
- [DS Overview](ARCHITECTURE.md#directory-server-ds)
- [DS Replication Setup](README.md#ds-replication-setup)
- [Replication Architecture](ARCHITECTURE.md#replication-strategy)
- [DS Troubleshooting](NOTES.md#replication-not-working)
- [DS Commands](NOTES.md#ds-commands)

#### Access Manager (AM)
- [AM Overview](ARCHITECTURE.md#access-manager-am)
- [AM Data Stores](ARCHITECTURE.md#data-stores)
- [Session Management](ARCHITECTURE.md#session-architecture)
- [AM Configuration](README.md#pingaccess-manager-am)
- [AM Commands](NOTES.md#am-commands)

#### Identity Manager (IDM)
- [IDM Overview](ARCHITECTURE.md#identity-manager-idm)
- [IDM Connectors](README.md#idm-connectors)
- [Active Directory Connector](README.md#active-directory-connector)
- [MySQL Connector](README.md#mysql-connector-idm-repository)
- [Provisioning Flow](ARCHITECTURE.md#provisioning-flow-idm)
- [IDM Commands](NOTES.md#idm-commands)

#### Identity Gateway (IG)
- [IG Overview](ARCHITECTURE.md#identity-gateway-ig)
- [PingGateway Integration](README.md#pinggateway-integration)
- [IG Routes Configuration](README.md#sample-ig-route-configuration)
- [Token Validation](README.md#ig-oauth-20-token-validation)
- [Testing IG](README.md#testing-ig-integration)

### Operations

#### Daily Operations
- [Starting Services](README.md#3-start-the-platform)
- [Stopping Services](NOTES.md#shutdown-order)
- [Checking Status](README.md#4-verify-services)
- [Viewing Logs](NOTES.md#log-locations)
- [Health Checks](scripts/health-check.sh)

#### Backup and Recovery
- [Backup Strategy](README.md#backup-and-restore)
- [Running Backups](scripts/backup-all.sh)
- [Restoring from Backup](scripts/restore-backup.sh)
- [Disaster Recovery](ARCHITECTURE.md#disaster-recovery)

#### Troubleshooting
- [Common Issues](README.md#common-issues)
- [Troubleshooting Guide](README.md#troubleshooting)
- [Performance Tuning](README.md#performance-tuning)
- [Debugging Tools](README.md#debugging-tools)
- [Troubleshooting Tips](NOTES.md#9-troubleshooting-tips)

### Architecture and Design

- [System Overview](ARCHITECTURE.md#system-overview)
- [Component Architecture](ARCHITECTURE.md#component-architecture)
- [Data Flow Patterns](ARCHITECTURE.md#data-flow-patterns)
- [Security Architecture](ARCHITECTURE.md#security-architecture)
- [High Availability](ARCHITECTURE.md#high-availability-and-scalability)
- [Integration Patterns](ARCHITECTURE.md#integration-patterns)
- [Design Decisions](ARCHITECTURE.md#design-decisions)

### Advanced Topics

#### Networking
- [Network Architecture](README.md#network-architecture)
- [Container Network](ARCHITECTURE.md#container-network)
- [Service Communication](README.md#service-communication)
- [DNS Resolution](NOTES.md#container-dns)

#### Security
- [SSL/TLS Certificates](README.md#ssltls-certificates)
- **[Production Certificates Guide](docs/PRODUCTION_CERTIFICATES.md)** - Comprehensive certificate management
- [Secrets Management](ARCHITECTURE.md#secrets-management)
- [Network Security](ARCHITECTURE.md#network-security)
- [SELinux](NOTES.md#selinux)

#### Scaling
- [Horizontal Scaling](ARCHITECTURE.md#horizontal-scaling-multiple-hosts)
- [Vertical Scaling](ARCHITECTURE.md#vertical-scaling)
- [Database Scaling](ARCHITECTURE.md#database-scaling)
- [Load Balancing](ARCHITECTURE.md#load-balancing-considerations)

#### Migration
- [Podman vs Kubernetes](ARCHITECTURE.md#podman-vs-kubernetes)
- [When to Migrate](ARCHITECTURE.md#when-to-migrate-to-kubernetes)
- [Migration Path](ARCHITECTURE.md#migration-path)

### Development

- [Project Origins](NOTES.md#project-origins)
- [What Was Converted](NOTES.md#what-was-converted)
- [Implementation Notes](NOTES.md#important-implementation-notes)
- [Future Enhancements](NOTES.md#future-enhancements)
- [Known Limitations](NOTES.md#known-limitations)

## Component Port Reference

| Service | Internal Port | Host Port | Protocol | Purpose |
|---------|--------------|-----------|----------|---------|
| DS-1 | 1389 | 1389 | LDAP | Directory access |
| DS-1 | 1636 | 1636 | LDAPS | Secure directory access |
| DS-1 | 4444 | 4444 | HTTPS | Admin console |
| DS-1 | 8989 | 8989 | TCP | Replication |
| DS-2 | 1389 | 1390 | LDAP | Directory access |
| DS-2 | 1636 | 1637 | LDAPS | Secure directory access |
| DS-2 | 4444 | 4445 | HTTPS | Admin console |
| DS-2 | 8989 | 8990 | TCP | Replication |
| DS-Proxy | 1389 | 1391 | LDAP | Proxy access |
| DS-Proxy | 1636 | 1638 | LDAPS | Secure proxy access |
| DS-Proxy | 4444 | 4446 | HTTPS | Admin console |
| AM | 8080 | 8082 | HTTP | Access Manager |
| AM | 8443 | 8445 | HTTPS | Secure Access Manager |
| IDM | 8080 | 8083 | HTTP | Identity Manager |
| IDM | 8443 | 8446 | HTTPS | Secure Identity Manager |
| IDM | 8444 | 8447 | HTTPS | Mutual auth |
| IG | 8080 | 8084 | HTTP | Identity Gateway |
| IG | 8443 | 8448 | HTTPS | Secure Gateway |
| Admin UI | 8080 | 8085 | HTTP | Admin Interface |
| Login UI | 8080 | 8086 | HTTP | Login Interface |
| MySQL | 3306 | 3306 | MySQL | Database |

## Default Credentials Reference

**CRITICAL**: Change all default passwords before production use!

| Service | Username | Password | Purpose |
|---------|----------|----------|---------|
| DS | cn=Directory Manager | changeme | LDAP admin |
| AM | amadmin | changeme | AM admin console |
| IDM | openidm-admin | changeme | IDM admin |
| MySQL | root | changeme | Database admin |
| MySQL | openidm | openidm | IDM database user |

## Command Quick Reference

### Service Management
```bash
# Start all services
cd compose && podman-compose up -d

# Stop all services
cd compose && podman-compose down

# Restart service
cd compose && podman-compose restart <service>

# View logs
cd compose && podman-compose logs -f <service>

# Check status
cd compose && podman-compose ps
```

### Health Checks
```bash
# Run full health check
./scripts/health-check.sh

# Check individual services
curl http://localhost:8082/am/isAlive.jsp
curl -k https://localhost:8446/openidm/info/ping
curl http://localhost:8084/ig/status
```

### Backup and Restore
```bash
# Backup all data
./scripts/backup-all.sh

# Restore from backup
./scripts/restore-backup.sh <timestamp>

# List available backups
ls -lh /backup/ping/
```

### Container Management
```bash
# List containers
podman ps -a

# Execute command in container
podman exec -it <container> bash

# View container logs
podman logs -f <container>

# Check resource usage
podman stats
```

## Support and Community

### Documentation
- [Ping Identity Docs](https://docs.pingidentity.com/)
- [ForgeOps GitHub](https://github.com/ForgeRock/forgeops)
- [Podman Documentation](https://docs.podman.io/)

### Getting Help
1. Check the documentation (start with this index)
2. Review [NOTES.md](NOTES.md) for common issues
3. Run health check: `./scripts/health-check.sh`
4. Check container logs: `podman logs <container-name>`
5. Open an issue in the repository
6. Contact the platform team

### Contributing
- Document any changes in the appropriate files
- Update version numbers
- Test thoroughly before committing
- See [Contribution Guidelines](NOTES.md#contribution-guidelines)

## Version Information

- **Current Version**: 1.0.0
- **Last Updated**: 2024-01-15
- **Based On**: ForgeRock ForgeOps (Kubernetes)
- **Target Platform**: RHEL 8.x/9.x with Podman 4.x

## License

This deployment configuration is provided as-is for use with Ping Identity products. Consult Ping Identity licensing for product usage terms.

---

**Need help?** Start with the [Quick Start Guide](docs/QUICK_START.md) or [README.md](README.md).
