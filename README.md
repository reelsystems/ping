# ForgeRock Identity Platform - Zero Trust Implementation

## Overview

This repository contains a complete ForgeRock Identity Platform deployment for Zero Trust architecture, compliant with DoD security requirements.

### Stack Components

- **PingDS (ForgeRock Directory Services)** - LDAP directory and configuration store
- **PingAM (ForgeRock Access Management)** - Authentication, SSO, SAML/OAuth/OIDC
- **PingIDM (ForgeRock Identity Management)** - Identity lifecycle and provisioning
- **PingGateway (ForgeRock Identity Gateway)** - Reverse proxy and policy enforcement

### Quick Start

```powershell
# 1. Clone or extract this repository
cd $env:USERPROFILE\Documents\ping

# 2. Update environment variables
notepad .env

# 3. Create directory structure
.\scripts\create-directories.ps1

# 4. Start the stack
docker-compose up -d

# 5. Monitor startup (takes 10-15 minutes)
docker-compose logs -f
```

### Documentation

**📖 Complete setup instructions:** [instructions.md](instructions.md)

The instructions include:
- Prerequisites and system requirements
- Windows Server 2019 setup
- Private Docker registry for air-gapped deployment
- Active Directory integration
- ServiceNow SAML/OIDC integration
- DoD Zero Trust security hardening
- Backup and recovery procedures
- Troubleshooting guide

### Access URLs

After deployment:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| PingAM Console | http://localhost:8081/am/console | amadmin / (see .env) |
| PingIDM Admin | http://localhost:8082/admin | openidm-admin / (see .env) |
| PingGateway | http://localhost:8083 | N/A |

### Architecture

```
                    ServiceNow
                        │
                   PingGateway
                        │
        ┌───────────────┼───────────────┐
        │                               │
     PingAM ←────────────────────→ PingIDM
        │                               │
        └───────────────┬───────────────┘
                        │
                     PingDS
                        │
              ┌─────────┴─────────┐
           AD DC1             AD DC2
         192.168.1.2       192.168.1.3
```

### Directory Structure

```
ping/
├── docker-compose.yml       # Container orchestration
├── .env                     # Environment variables (sensitive - not committed)
├── instructions.md          # Complete setup guide
├── README.md               # This file
├── config/                 # Service configurations
│   ├── ds/
│   ├── am/
│   ├── idm/
│   └── gateway/
├── scripts/               # Utility scripts
│   ├── backup.ps1
│   ├── restore.ps1
│   ├── compliance-check.ps1
│   └── e2e-test.ps1
├── certs/                 # SSL/TLS certificates
└── secrets/               # Sensitive files (not committed)
```

### Common Commands

```powershell
# View status
docker-compose ps

# View logs
docker-compose logs -f [service-name]

# Restart a service
docker-compose restart pingam

# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: Data loss!)
docker-compose down -v

# Run health check
docker-compose ps | Select-String "healthy"

# Run backup
.\scripts\backup.ps1

# Run compliance check
.\scripts\compliance-check.ps1
```

### Security Notice

⚠️ **IMPORTANT SECURITY NOTES:**

1. **Change all default passwords** in `.env` before deployment
2. **Generate new deployment key** using: `openssl rand -base64 32`
3. **Use proper SSL/TLS certificates** in production (not self-signed)
4. **Secure the `.env` file** - contains sensitive credentials
5. **Review audit logs regularly** for compliance
6. **Follow DoD Zero Trust guidelines** outlined in instructions.md

### Support & Resources

- **Full Documentation:** [instructions.md](instructions.md)
- **ForgeRock Docs:** https://backstage.forgerock.com/docs/
- **ForgeRock Community:** https://community.forgerock.com/
- **DoD Zero Trust RA:** https://dodcio.defense.gov/zero-trust/

### Requirements

- Windows Server 2019
- Docker Desktop 4.x+
- 16 GB RAM (32 GB recommended)
- 8 CPU cores (16 recommended)
- 200 GB free disk space
- Access to Active Directory domain controllers

### License

ForgeRock products require proper licensing. Contact ForgeRock for licensing information:
https://www.forgerock.com/

### Version

- **Platform Version:** ForgeRock 8.0
- **Deployment Version:** 1.0
- **Last Updated:** 2024

---

For detailed setup instructions, troubleshooting, and integration guides, see [instructions.md](instructions.md).
