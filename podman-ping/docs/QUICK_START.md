# Quick Start Guide - Ping Identity Platform on Podman

This guide will get you up and running in under 30 minutes.

## Prerequisites Check

```bash
# Verify Podman is installed
podman --version  # Should be 4.0+

# Verify Podman Compose is installed
podman-compose --version

# Check available resources
free -h  # Should have at least 8GB RAM
df -h    # Should have at least 50GB free disk
```

## Step 1: Initial Setup (5 minutes)

```bash
# Clone or navigate to the repository
cd /path/to/podman-ping

# Generate self-signed certificates (for testing only)
./scripts/setup-certificates.sh

# Copy certificates to Podman volume
podman volume create shared-certs
podman run --rm -v $(pwd)/certs:/src -v shared-certs:/dest alpine \
  sh -c 'cp -r /src/* /dest/ && chmod -R 755 /dest'
```

## Step 2: Pull Base Images (10 minutes)

```bash
# Pull Ping Identity base images
# Note: Some images may require authentication

podman pull docker.io/pingidentity/pingdirectory:latest
podman pull docker.io/pingidentity/pingaccess:latest
podman pull docker.io/pingidentity/pingidentitymanager:latest
podman pull docker.io/pingidentity/pinggateway:latest
podman pull docker.io/library/mysql:8.0

# Or let Podman Compose pull them automatically during build
```

## Step 3: Build Images (5 minutes)

```bash
cd compose
podman-compose build
```

## Step 4: Start Services (5 minutes)

```bash
# Start all services
podman-compose up -d

# Watch the logs
podman-compose logs -f
```

Wait for all services to start. You should see:
- MySQL: `ready for connections`
- DS: `The Directory Server has started successfully`
- AM: `Server startup in X ms`
- IDM: `OpenIDM ready`

## Step 5: Verify Installation (5 minutes)

```bash
# Run health check script
cd ..
./scripts/health-check.sh

# Or manually check each service:
curl http://localhost:8082/am/isAlive.jsp
curl -k https://localhost:8446/openidm/info/ping
curl http://localhost:8084/ig/status
```

## Step 6: Access the Services

Open your browser and navigate to:

| Service | URL | Credentials |
|---------|-----|-------------|
| Access Manager | http://localhost:8082/am | amadmin / changeme |
| Identity Manager | https://localhost:8446/admin | openidm-admin / changeme |
| Admin UI | http://localhost:8085 | (uses AM/IDM) |
| Login UI | http://localhost:8086 | (auth interface) |

## Common First-Time Issues

### Issue: Port Already in Use

**Error**: `bind: address already in use`

**Solution**:
```bash
# Find what's using the port
sudo ss -tulpn | grep :8080

# Either stop that service or change the port in podman-compose.yml
```

### Issue: Services Not Starting

**Error**: Container exits immediately

**Solution**:
```bash
# Check logs for specific error
podman logs ping-ds-1

# Common causes:
# 1. Insufficient memory - increase Docker resources
# 2. SELinux blocking - check with: sudo ausearch -m avc -ts recent
# 3. Volume permissions - fix with: podman exec -u root <container> chown -R forgerock:root /data
```

### Issue: Can't Access Services from Browser

**Error**: Connection refused or timeout

**Solution**:
```bash
# Check firewall
sudo firewall-cmd --list-all

# Open ports
sudo firewall-cmd --permanent --add-port=8080-8086/tcp
sudo firewall-cmd --permanent --add-port=8443-8448/tcp
sudo firewall-cmd --reload
```

### Issue: DS Replication Not Working

**Error**: Replication lag or errors

**Solution**:
```bash
# Check replication status
podman exec ping-ds-1 /opt/opendj/bin/dsreplication status \
  --hostname ds-1.ping.local --port 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt

# If broken, reinitialize
podman exec ping-ds-1 /opt/opendj/bin/dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds-1.ping.local --portSource 4444 \
  --hostDestination ds-2.ping.local --portDestination 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt
```

## Next Steps

### 1. Change Default Passwords

**Critical for any non-development environment!**

Edit `compose/podman-compose.yml` and change:
- `ROOT_USER_PASSWORD`: DS directory manager password
- `AM_ADMIN_PASSWORD`: AM amadmin password
- `OPENIDM_ADMIN_PASSWORD`: IDM admin password
- `MYSQL_ROOT_PASSWORD`: MySQL root password
- `MYSQL_PASSWORD`: MySQL openidm user password

After changing, restart services:
```bash
cd compose
podman-compose down
podman-compose up -d
```

### 2. Configure Active Directory Connector

If integrating with Active Directory:

1. Edit `configs/ad-connector/provisioner.openicf-ad.json`
2. Update connection details (host, port, base DN)
3. Encrypt the service account password:
   ```bash
   podman exec -it ping-idm /opt/openidm/cli.sh encrypt YOUR_PASSWORD
   ```
4. Copy encrypted value to configuration
5. Restart IDM:
   ```bash
   podman-compose restart idm
   ```

### 3. Set Up Monitoring

```bash
# Install and configure Prometheus/Grafana for monitoring
# Or use simple monitoring with:
watch -n 5 'podman stats --no-stream'
```

### 4. Configure Backups

```bash
# Set up automated daily backups
sudo crontab -e

# Add line:
# 0 2 * * * /path/to/podman-ping/scripts/backup-all.sh
```

### 5. Review Documentation

- [README.md](../README.md) - Comprehensive setup guide
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Architecture and design decisions
- [NOTES.md](../NOTES.md) - Important notes and tips

## Troubleshooting Commands

```bash
# Check all container status
podman ps -a

# View logs for specific service
podman logs -f ping-am

# Restart specific service
podman-compose restart idm

# Restart all services
podman-compose restart

# Stop all services
podman-compose down

# Start with fresh volumes (WARNING: deletes all data)
podman-compose down -v
podman-compose up -d

# Execute command in container
podman exec -it ping-am bash

# Check resource usage
podman stats

# Inspect container configuration
podman inspect ping-ds-1

# Check network connectivity
podman exec ping-am ping ds-1.ping.local
```

## Getting Help

1. Check the logs: `podman logs <container-name>`
2. Run health check: `./scripts/health-check.sh`
3. Review [NOTES.md](../NOTES.md) for common issues
4. Check Ping Identity documentation: https://docs.pingidentity.com/
5. Open an issue in the repository

## What's Next?

Now that your platform is running:

1. **Learn the Components**: Read [ARCHITECTURE.md](../ARCHITECTURE.md)
2. **Configure Authentication**: Set up AM policies and authentication chains
3. **Set Up Provisioning**: Configure IDM connectors and mappings
4. **Deploy Applications**: Integrate applications with the platform
5. **Implement SSO**: Configure SAML or OAuth for your apps
6. **Plan for Production**: Review security and HA considerations

---

**Congratulations!** Your Ping Identity Platform is now running on Podman.
