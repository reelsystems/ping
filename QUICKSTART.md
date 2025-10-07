# ForgeRock Identity Platform - Quick Start Guide

This is a **condensed** quick start guide. For complete instructions, see [instructions.md](instructions.md).

## Prerequisites

- Windows Server 2019
- Docker Desktop installed and running
- 16 GB RAM, 8 CPU cores
- 200 GB free disk space
- Access to AD domain controllers (192.168.1.2, 192.168.1.3)

## Quick Setup (5 Steps)

### 1. Clone/Extract Repository

```powershell
cd $env:USERPROFILE\Documents\ping
```

### 2. Configure Environment

```powershell
# Edit .env file
notepad .env

# Update these critical values:
# - DEPLOYMENT_KEY (generate with: openssl rand -base64 32)
# - All passwords (minimum 15 characters)
# - AD_BIND_DN and AD_BIND_PASSWORD
# - SNOW_INSTANCE_URL (your ServiceNow instance)
```

### 3. Create Directory Structure

```powershell
.\scripts\create-directories.ps1
```

### 4. Start the Stack

```powershell
# Start all services
docker-compose up -d

# Monitor logs (services take 10-15 minutes to start)
docker-compose logs -f
```

### 5. Verify Health

```powershell
# Run health check
.\scripts\health-check.ps1

# Check service status
docker-compose ps
```

## Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **PingAM Console** | http://localhost:8081/am/console | amadmin / (from .env) |
| **PingIDM Admin** | http://localhost:8082/admin | openidm-admin / (from .env) |
| **PingGateway** | http://localhost:8083 | N/A |

## Next Steps

### Configure Active Directory Integration

1. Access PingAM Console: http://localhost:8081/am/console
2. Navigate to: **Data Stores** → **Add Data Store** → **Active Directory**
3. Configure:
   - LDAP Server: `192.168.1.2:389`
   - Bind DN: `CN=svc-forgerock,CN=Users,DC=devnetwork,DC=dev`
   - Password: (your AD service account password)
   - Base DN: `DC=devnetwork,DC=dev`
4. Add failover server: `192.168.1.3:389`
5. Test connection and save

### Configure ServiceNow Integration

See [instructions.md - ServiceNow Integration](instructions.md#servicenow-integration) for complete SAML and OAuth/OIDC setup.

## Common Commands

```powershell
# View service status
docker-compose ps

# View logs for specific service
docker-compose logs -f pingam

# Restart a service
docker-compose restart pingam

# Stop all services
docker-compose down

# Run backup
.\scripts\backup.ps1

# Run health check
.\scripts\health-check.ps1
```

## Troubleshooting

### Services won't start?

```powershell
# Check logs
docker-compose logs

# Verify Docker resources
docker info

# Restart Docker Desktop if needed
```

### Can't connect to AD?

```powershell
# Test connectivity from container
docker exec pingds.devnetwork.dev ping 192.168.1.2

# Verify firewall rules on AD server
```

### Out of memory?

```powershell
# Increase Docker Desktop memory allocation
# Settings → Resources → Advanced → Memory: 16 GB
```

## Important Security Notes

⚠️ **Before going to production:**

1. ✅ Change ALL default passwords
2. ✅ Generate secure deployment key
3. ✅ Use proper CA-signed certificates
4. ✅ Enable all audit logging
5. ✅ Configure backup schedule
6. ✅ Review DoD Zero Trust hardening steps

## Documentation

- **Complete Setup:** [instructions.md](instructions.md)
- **README:** [README.md](README.md)
- **ForgeRock Docs:** https://backstage.forgerock.com/docs/

## Support

For issues or questions:
- Review [instructions.md - Troubleshooting](instructions.md#troubleshooting)
- Check ForgeRock Community: https://community.forgerock.com/
- Review Docker logs: `docker-compose logs`

---

**Ready for Production?**

Before deploying to production:
1. Complete all sections in [instructions.md](instructions.md)
2. Implement DoD Zero Trust hardening
3. Set up monitoring and alerting
4. Configure automated backups
5. Test disaster recovery procedures
6. Document your custom configurations
