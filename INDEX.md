# ForgeRock Identity Platform - Documentation Index

## 🚀 Getting Started

**New to this project? Start here:**

1. 📖 **[README.md](README.md)** - Project overview, quick reference, and access URLs
2. ⚡ **[QUICKSTART.md](QUICKSTART.md)** - 5-step deployment in under 1 hour
3. 📘 **[instructions.md](instructions.md)** - Complete deployment guide (80+ pages)

## 📚 Documentation by Purpose

### I want to... Deploy the Stack

| Document | Purpose | Time Required |
|----------|---------|---------------|
| **[QUICKSTART.md](QUICKSTART.md)** | Fast deployment with minimal explanation | ~1 hour |
| **[instructions.md](instructions.md)** | Complete deployment with full details | ~4-6 hours |
| **[DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md)** | Architecture overview and deployment summary | 15 min read |

### I want to... Understand the Architecture

| Document | Purpose |
|----------|---------|
| **[DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md)** | Full architecture diagrams and network topology |
| **[README.md](README.md) - Architecture section** | Quick architecture overview |
| **[instructions.md](instructions.md) - Overview** | Component descriptions |

### I want to... Configure Integrations

| Document | Section | Purpose |
|----------|---------|---------|
| **[instructions.md](instructions.md)** | Active Directory Integration | Connect to AD domain controllers |
| **[instructions.md](instructions.md)** | ServiceNow Integration | SAML and OAuth/OIDC setup |
| **[config/am/](config/am/)** | Example configs | OAuth2, SAML configuration examples |
| **[config/idm/](config/idm/)** | Example configs | AD connector and sync mappings |

### I want to... Secure the Deployment

| Document | Section | Purpose |
|----------|---------|---------|
| **[instructions.md](instructions.md)** | DoD Zero Trust Hardening | Complete security hardening guide |
| **[DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md)** | Security Features | Implemented security controls |
| **[config/am/audit-config.example.json](config/am/audit-config.example.json)** | - | DoD-compliant audit logging |

### I want to... Manage Operations

| Document | Purpose |
|----------|---------|
| **[scripts/backup.ps1](scripts/backup.ps1)** | Automated backup script |
| **[scripts/restore.ps1](scripts/restore.ps1)** | Restore from backup |
| **[scripts/health-check.ps1](scripts/health-check.ps1)** | System health monitoring |
| **[instructions.md](instructions.md) - Backup & Recovery** | Backup strategies and procedures |

### I want to... Troubleshoot Issues

| Document | Section | Purpose |
|----------|---------|---------|
| **[instructions.md](instructions.md)** | Troubleshooting | Common issues and solutions |
| **[instructions.md](instructions.md)** | Verification & Testing | Health check procedures |
| **[DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md)** | Troubleshooting Quick Reference | Quick issue resolution |

### I want to... Understand the File Structure

| Document | Purpose |
|----------|---------|
| **[PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)** | Complete file and directory reference |
| **[config/*/README.md](config/)** | Service-specific configuration guides |

### I want to... Prepare for Air-Gapped Deployment

| Document | Section | Purpose |
|----------|---------|---------|
| **[instructions.md](instructions.md)** | Private Docker Registry Setup | Set up private registry |
| **[instructions.md](instructions.md)** | Migration to Air-Gapped Environment | Complete migration guide |
| **[DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md)** | Air-Gapped Deployment | Quick reference |

## 📂 File Organization

### Documentation Files

```
📘 README.md                    # Start here - project overview
📘 QUICKSTART.md                # Fast deployment guide
📘 instructions.md              # Complete documentation (80+ pages)
📘 DEPLOYMENT-SUMMARY.md        # Architecture and summary
📘 PROJECT-STRUCTURE.md         # File structure reference
📘 INDEX.md                     # This file - navigation guide
```

### Configuration Files

```
📄 docker-compose.yml           # Container orchestration
📄 .env                         # Environment variables (SENSITIVE)
📄 .gitignore                   # Git ignore rules
```

### Scripts

```
⚙️ scripts/create-directories.ps1   # Setup directory structure
⚙️ scripts/backup.ps1               # Automated backup
⚙️ scripts/restore.ps1              # Restore from backup
⚙️ scripts/health-check.ps1         # Health monitoring
```

### Example Configurations

```
📋 config/am/audit-config.example.json          # Audit logging
📋 config/gateway/servicenow-route.example.json # ServiceNow protection
📋 config/idm/ad-connector.example.json         # AD connector
📋 config/idm/sync-mapping.example.json         # Sync mapping
```

## 🎯 Common Tasks - Quick Links

### Initial Setup

1. **Install prerequisites** → [instructions.md - Prerequisites](instructions.md#prerequisites)
2. **Setup Windows Server** → [instructions.md - Initial Setup](instructions.md#initial-setup---windows-server-2019)
3. **Configure environment** → [instructions.md - Configuration](instructions.md#configuration)
4. **Deploy stack** → [QUICKSTART.md](QUICKSTART.md)

### Day-to-Day Operations

- **Check health** → Run `.\scripts\health-check.ps1`
- **View logs** → `docker-compose logs -f [service]`
- **Restart service** → `docker-compose restart [service]`
- **Backup** → Run `.\scripts\backup.ps1`

### Integration Tasks

- **Connect to AD** → [instructions.md - Active Directory Integration](instructions.md#active-directory-integration)
- **Setup ServiceNow SAML** → [instructions.md - ServiceNow SAML](instructions.md#saml-20-integration)
- **Setup ServiceNow OAuth** → [instructions.md - ServiceNow OAuth](instructions.md#oauth-20--oidc-integration)

### Security Tasks

- **Harden deployment** → [instructions.md - DoD Zero Trust Hardening](instructions.md#dod-zero-trust-hardening)
- **Configure audit logs** → [config/am/audit-config.example.json](config/am/audit-config.example.json)
- **Setup MFA** → [instructions.md - Multi-Factor Authentication](instructions.md#step-3-implement-multi-factor-authentication-mfa)
- **Configure certificates** → [instructions.md - TLS/SSL Configuration](instructions.md#step-1-tlsssl-configuration)

### Troubleshooting

- **Services won't start** → [instructions.md - Issue 1](instructions.md#issue-1-services-wont-start)
- **Can't connect to AD** → [instructions.md - Issue 2](instructions.md#issue-2-cannot-connect-to-active-directory)
- **Memory issues** → [instructions.md - Issue 3](instructions.md#issue-3-memory-issues)
- **SSL errors** → [instructions.md - Issue 4](instructions.md#issue-4-ssltls-certificate-issues)

## 📖 Reading Order by Role

### System Administrator (First Time Setup)

1. [README.md](README.md) - 5 minutes
2. [QUICKSTART.md](QUICKSTART.md) - 10 minutes
3. [instructions.md - Prerequisites](instructions.md#prerequisites) - 15 minutes
4. [instructions.md - Initial Setup](instructions.md#initial-setup---windows-server-2019) - 30 minutes
5. Deploy and configure following [QUICKSTART.md](QUICKSTART.md)

### Identity Administrator (Configuration)

1. [DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md) - Architecture overview
2. [instructions.md - Active Directory Integration](instructions.md#active-directory-integration)
3. [instructions.md - ServiceNow Integration](instructions.md#servicenow-integration)
4. [config/ examples](config/) - Review example configurations

### Security Officer (Compliance)

1. [DEPLOYMENT-SUMMARY.md - Security Features](DEPLOYMENT-SUMMARY.md#security-features-implemented)
2. [instructions.md - DoD Zero Trust Hardening](instructions.md#dod-zero-trust-hardening)
3. [config/am/audit-config.example.json](config/am/audit-config.example.json)
4. [instructions.md - Backup & Recovery](instructions.md#backup--recovery)

### Operations (Day-to-Day)

1. [README.md - Common Commands](README.md#common-commands)
2. [scripts/health-check.ps1](scripts/health-check.ps1)
3. [instructions.md - Troubleshooting](instructions.md#troubleshooting)
4. [DEPLOYMENT-SUMMARY.md - Monitoring](DEPLOYMENT-SUMMARY.md#monitoring--health-checks)

### DevOps Engineer (Air-Gapped Deployment)

1. [instructions.md - Private Docker Registry](instructions.md#private-docker-registry-setup-air-gapped)
2. [instructions.md - Migration to Air-Gapped](instructions.md#migration-to-air-gapped-environment)
3. [DEPLOYMENT-SUMMARY.md - Air-Gapped](DEPLOYMENT-SUMMARY.md#air-gapped-deployment)

## 🔍 Search Guide

### Finding Information

**How to find configuration for...**

| Topic | Search In |
|-------|-----------|
| Passwords, credentials | `.env` file, `secrets/` directory |
| SAML configuration | [instructions.md](instructions.md), search "SAML" |
| OAuth configuration | [instructions.md](instructions.md), search "OAuth" |
| AD integration | [instructions.md](instructions.md), search "Active Directory" |
| Audit logging | [config/am/audit-config.example.json](config/am/audit-config.example.json) |
| TLS/SSL | [instructions.md](instructions.md), search "TLS" or "certificate" |
| Backup procedures | [instructions.md](instructions.md), search "backup" |
| Port configuration | [DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md), "Network & Port Configuration" |

**PowerShell commands for searching:**

```powershell
# Search all markdown files for a term
Get-ChildItem -Filter "*.md" | Select-String "Active Directory"

# Search all JSON files
Get-ChildItem -Recurse -Filter "*.json" | Select-String "oauth"

# Find all references to a service
Get-ChildItem -Recurse | Select-String "pingam"
```

## 🆘 Help & Support

### Internal Documentation

- Complete guide: [instructions.md](instructions.md)
- Quick help: [README.md](README.md)
- Troubleshooting: [instructions.md - Troubleshooting](instructions.md#troubleshooting)

### External Resources

- **ForgeRock Documentation**: https://backstage.forgerock.com/docs/platform/8
- **ForgeRock Community**: https://community.forgerock.com/
- **DoD Zero Trust Reference Architecture**: https://dodcio.defense.gov/zero-trust/
- **NIST SP 800-207**: https://csrc.nist.gov/publications/detail/sp/800-207/final

### Getting Help

1. ✅ Check [instructions.md - Troubleshooting](instructions.md#troubleshooting)
2. ✅ Run `.\scripts\health-check.ps1` for diagnostics
3. ✅ Review `docker-compose logs` for errors
4. ✅ Search ForgeRock Community forums
5. ✅ Contact ForgeRock Support (if licensed)

## 📌 Quick Reference Cards

### Essential Commands

```powershell
# Start/Stop
docker-compose up -d              # Start all services
docker-compose down               # Stop all services
docker-compose restart [service]  # Restart specific service

# Monitoring
docker-compose ps                 # Service status
docker-compose logs -f            # Follow logs
.\scripts\health-check.ps1        # Health check

# Maintenance
.\scripts\backup.ps1              # Create backup
.\scripts\restore.ps1 -BackupFile "path"  # Restore
```

### Essential URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| PingAM Console | http://localhost:8081/am/console | amadmin / (see .env) |
| PingIDM Admin | http://localhost:8082/admin | openidm-admin / (see .env) |
| PingGateway | http://localhost:8083 | N/A |

### Essential Files

| File | Purpose |
|------|---------|
| `.env` | All configuration variables |
| `docker-compose.yml` | Service definitions |
| `scripts/health-check.ps1` | System diagnostics |
| `config/am/audit-config.example.json` | Audit configuration |

## 📝 Notes

### Document Versions

- **All documents**: Version 1.0
- **Last Updated**: 2024
- **ForgeRock Version**: 8.0
- **Target OS**: Windows Server 2019

### Document Length

| Document | Pages | Reading Time |
|----------|-------|--------------|
| README.md | 2 | 5 minutes |
| QUICKSTART.md | 3 | 10 minutes |
| instructions.md | 80+ | 2-3 hours |
| DEPLOYMENT-SUMMARY.md | 15 | 30 minutes |
| PROJECT-STRUCTURE.md | 12 | 20 minutes |
| INDEX.md | 8 | 15 minutes |

### Recommended Reading Path

**For fast deployment:**
1. README.md → QUICKSTART.md → Deploy

**For complete understanding:**
1. README.md → DEPLOYMENT-SUMMARY.md → instructions.md → Deploy

**For security focus:**
1. DEPLOYMENT-SUMMARY.md (Security) → instructions.md (DoD Hardening) → Deploy

---

## 🎓 Training Paths

### Path 1: Quick Deployment (1 day)

- Morning: [QUICKSTART.md](QUICKSTART.md) + Deploy
- Afternoon: [instructions.md - AD Integration](instructions.md#active-directory-integration)
- Evening: [instructions.md - ServiceNow](instructions.md#servicenow-integration)

### Path 2: Complete Deployment (1 week)

- Day 1: Read all documentation
- Day 2: Windows Server setup + Docker
- Day 3: Deploy ForgeRock stack
- Day 4: AD integration
- Day 5: ServiceNow integration
- Day 6: Security hardening
- Day 7: Testing and validation

### Path 3: Production Ready (2 weeks)

- Week 1: Follow "Complete Deployment" path
- Week 2:
  - Security audit
  - Performance tuning
  - Backup/restore testing
  - Documentation of customizations
  - Team training

---

**Need help navigating? Start with [README.md](README.md)**

**Ready to deploy? Go to [QUICKSTART.md](QUICKSTART.md)**

**Want full details? Read [instructions.md](instructions.md)**
