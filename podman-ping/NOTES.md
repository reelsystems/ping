# Ping Identity Platform on Podman - Development Notes

## Context Between Sessions

This document serves as a knowledge transfer and context preservation mechanism for ongoing development and maintenance.

## Project Origins

**Source**: [ForgeRock/forgeops GitHub Repository](https://github.com/ForgeRock/forgeops)

This project is a conversion of the ForgeRock ForgeOps Kubernetes deployment to a Podman-based deployment suitable for RHEL systems. The original ForgeOps project is designed for cloud-native Kubernetes deployments, but many organizations require:

1. Single-host deployments for development/testing
2. Non-Kubernetes container orchestration
3. RHEL-native container runtime (Podman)
4. Simpler operational model without Kubernetes complexity

## What Was Converted

### From ForgeOps Kubernetes

The original ForgeOps repository provides:
- Base Docker images for PingAM, PingIDM, PingDS, and PingGateway
- Kubernetes manifests (Kustomize-based)
- Helm charts
- Configuration profiles for different deployment scenarios
- Development tooling (skaffold, etc.)

### To Podman Deployment

This conversion provides:
- **Containerfiles** for each component (based on ForgeOps Dockerfiles)
- **Podman Compose** orchestration (replacing Kubernetes)
- **Static networking** configuration (replacing Kubernetes Services)
- **Volume management** via Podman volumes (replacing PVCs)
- **RHEL-optimized** images (microdnf instead of apt)

## Important Implementation Notes

### 1. Base Image References

The Containerfiles reference Ping Identity's public images:
```dockerfile
ARG BASE_IMAGE=docker.io/pingidentity/pingdirectory:latest
```

**Note**: These are **upstream base images** that you may need to:
- Pull from Ping Identity's registry (requires authentication for some versions)
- Replace with your organization's internal registry
- Pin to specific version tags (not `latest`) for production

**Production Recommendation**:
```dockerfile
ARG BASE_IMAGE=docker.io/pingidentity/pingdirectory:8.0.1.0
```

### 2. Configuration Profiles

The original ForgeOps uses configuration profiles (e.g., `config-profiles/cdk/`). This conversion assumes a `default` profile but **does not include the actual configuration files**.

**What You Need to Do**:
1. Clone the ForgeOps repository
2. Copy configuration profiles from `docker/*/config-profiles/` to the respective `config/` directories
3. Customize for your environment

Example:
```bash
git clone https://github.com/ForgeRock/forgeops.git
cp -r forgeops/docker/am/config-profiles/cdk/ podman-ping/am/config/
cp -r forgeops/docker/idm/config-profiles/cdk/ podman-ping/idm/config/
cp -r forgeops/docker/ds/config-profiles/ds-idrepo/ podman-ping/ds/config/
```

### 3. Secrets and Passwords

**CRITICAL**: All passwords in the configuration are **defaults** and **MUST** be changed for any real deployment.

Default passwords to change:
- DS root user: `changeme`
- AM amadmin: `changeme`
- IDM openidm-admin: `changeme`
- MySQL root: `changeme`
- MySQL openidm user: `openidm`

**How to Change**:
1. Edit `compose/podman-compose.yml` environment variables
2. For IDM connectors, use the encryption CLI:
   ```bash
   podman exec -it ping-idm /opt/openidm/cli.sh encrypt YOUR_PASSWORD
   ```

### 4. Certificate Management

The deployment references a `shared-certs` volume but **does not generate certificates**.

**What You Need**:
- CA certificate
- Server certificates for each service
- Java keystores for Java-based services (AM, IDM)
- PEM format for DS

**Generate Self-Signed Certs** (testing only):
```bash
# Create certificate directory
mkdir -p certs

# Generate CA
openssl genrsa -out certs/ca.key 4096
openssl req -x509 -new -nodes -key certs/ca.key -sha256 -days 1024 -out certs/ca.crt \
  -subj "/CN=Ping Identity CA"

# Generate server cert
openssl genrsa -out certs/server.key 2048
openssl req -new -key certs/server.key -out certs/server.csr \
  -subj "/CN=*.ping.local"
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key \
  -CAcreateserial -out certs/server.crt -days 500 -sha256

# Create Java keystore (for AM, IDM)
openssl pkcs12 -export -in certs/server.crt -inkey certs/server.key \
  -out certs/server.p12 -name server -passout pass:changeit
keytool -importkeystore -srckeystore certs/server.p12 -srcstoretype PKCS12 \
  -srcstorepass changeit -destkeystore certs/keystore.jks \
  -deststorepass changeit -noprompt

# Import CA to truststore
keytool -import -trustcacerts -file certs/ca.crt -alias ca \
  -keystore certs/truststore.jks -storepass changeit -noprompt

# Copy to shared volume
podman volume create shared-certs
podman run --rm -v $(pwd)/certs:/src -v shared-certs:/dest alpine \
  cp -r /src/* /dest/
```

### 5. RHEL-Specific Considerations

#### SELinux

If SELinux is enforcing (which it should be in production):

**Volume Mount Issues**:
```bash
# Check SELinux context
ls -lZ /var/lib/containers/storage/volumes/

# If containers can't access volumes:
sudo chcon -R -t container_file_t /var/lib/containers/storage/volumes/

# Or use :Z suffix in volume mounts (for private volumes)
volumes:
  - ds-data-1:/opt/opendj/data:Z

# Or :z for shared volumes
volumes:
  - shared-certs:/var/run/secrets/keys:z,ro
```

**Service Account Access**:
The Containerfiles create and use service accounts (`forgerock` user). SELinux may restrict operations. Test thoroughly with SELinux enforcing.

#### Firewalld

RHEL's firewall is strict by default. The README includes commands to open ports, but consider:

**Zone-Based Configuration**:
```bash
# Create a dedicated zone for Ping services
sudo firewall-cmd --permanent --new-zone=ping
sudo firewall-cmd --permanent --zone=ping --add-source=192.168.1.0/24
sudo firewall-cmd --permanent --zone=ping --add-port=8080-8086/tcp
sudo firewall-cmd --permanent --zone=ping --add-port=8443-8448/tcp
sudo firewall-cmd --reload
```

**Service Definitions**:
Create custom services for cleaner management:
```bash
# Create /etc/firewalld/services/ping-platform.xml
sudo firewall-cmd --permanent --new-service=ping-platform
sudo firewall-cmd --permanent --service=ping-platform --add-port=8080-8086/tcp
sudo firewall-cmd --permanent --service=ping-platform --add-port=8443-8448/tcp
sudo firewall-cmd --permanent --zone=public --add-service=ping-platform
```

#### Systemd Integration

For production, run as systemd services:

**Generate Systemd Units**:
```bash
cd compose
podman-compose up -d

# Generate systemd unit for each service
for svc in ping-ds-1 ping-ds-2 ping-am ping-idm ping-ig; do
  podman generate systemd --name --files $svc
done

# Move to systemd directory
sudo mv container-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable container-ping-ds-1.service
sudo systemctl enable container-ping-am.service
# ... etc
```

**Pod as Systemd Service**:
Alternatively, create a pod and generate a single service:
```bash
podman pod create --name ping-platform \
  -p 8080-8086:8080-8086 \
  -p 8443-8448:8443-8448

# Start containers in the pod
# ... (modify compose to use pod)

podman generate systemd --name --files ping-platform
sudo mv pod-ping-platform.service /etc/systemd/system/
sudo systemctl enable pod-ping-platform.service
```

### 6. Networking Nuances

#### Static IPs

The `podman-compose.yml` assigns static IPs for predictability. This works well for single-host but:

**Limitations**:
- Cannot span multiple hosts (use Kubernetes for that)
- IP changes require service restarts
- Manual IP management required

**Alternative - DNS Only**:
Remove static IPs and rely on DNS:
```yaml
services:
  ds-1:
    # Remove ipv4_address
    # Podman DNS will resolve ds-1.ping-network
```

#### Container DNS

Podman provides DNS resolution for container hostnames within the network. However:

**DNS Search Domains**:
If using `.ping.local` hostnames, ensure DNS resolution works:
```bash
podman exec ping-am cat /etc/resolv.conf
# Should contain:
# nameserver 172.28.0.1
# search ping.local
```

**External DNS**:
For production, consider:
- Using a real DNS domain (`ping.company.com`)
- External DNS server for inter-host communication
- Split-horizon DNS for internal/external resolution

### 7. Performance Tuning

#### JVM Heap Sizing

The Containerfiles set JVM heap sizes based on container memory. **Tune for your workload**:

**Current Settings**:
- AM: 75% of container memory (`-XX:MaxRAMPercentage=75.0`)
- IDM: 65% of initial and max (`-XX:InitialRAMPercentage=65.0 -XX:MaxRAMPercentage=65.0`)
- IG: 75% of container memory

**Production Tuning**:
```yaml
services:
  am:
    deploy:
      resources:
        limits:
          memory: 8G
    environment:
      JAVA_OPTS: >-
        -Xms4g -Xmx6g
        -XX:+UseG1GC
        -XX:MaxGCPauseMillis=200
        -XX:InitiatingHeapOccupancyPercent=45
        -XX:+ParallelRefProcEnabled
        -XX:+UseStringDeduplication
        -verbose:gc
        -Xlog:gc*:file=/var/log/am/gc.log:time,uptime,level,tags
```

#### DS Performance

**JVM Tuning for DS**:
DS also runs on Java. For high-load environments:
```bash
# Edit /opt/opendj/config/java.properties in the container
# Or set via environment variable:
environment:
  OPENDJ_JAVA_ARGS: "-Xms2g -Xmx2g -XX:+UseG1GC"
```

**Database Cache**:
DS uses a database cache. Tune based on working set size:
```bash
podman exec ping-ds-1 /opt/opendj/bin/dsconfig set-backend-prop \
  --backend-name userRoot \
  --set db-cache-percent:50 \
  --hostname localhost --port 4444 \
  --bindDN "cn=Directory Manager" --bindPassword changeme \
  --trustAll --no-prompt
```

#### MySQL Performance

For IDM, MySQL performance is critical. See `configs/mysql/my.cnf` example in README.

**Additional Tuning**:
```ini
[mysqld]
# InnoDB settings
innodb_buffer_pool_size = 4G              # 70-80% of MySQL container memory
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2        # Better performance, slight risk
innodb_flush_method = O_DIRECT

# Connection settings
max_connections = 500
thread_cache_size = 100

# Query cache (deprecated in MySQL 8, but available in older versions)
query_cache_type = 0                      # Disable in MySQL 8

# InnoDB I/O tuning
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 4
innodb_write_io_threads = 4
```

### 8. Operational Procedures

#### Startup Order

Services have dependencies. **Correct startup order**:

1. **MySQL** (IDM repository)
2. **DS-1** (primary directory)
3. **DS-2** (replica)
4. **DS-Proxy** (depends on DS-1 and DS-2)
5. **AM** (depends on DS-1, DS-2, DS-Proxy)
6. **IDM** (depends on MySQL, DS-1)
7. **IG** (depends on AM, IDM)
8. **UIs** (depend on AM, IDM)

Podman Compose `depends_on` handles this, but for manual starts:
```bash
podman start ping-mysql
sleep 30  # Wait for MySQL to be ready
podman start ping-ds-1
sleep 60  # Wait for DS to initialize
podman start ping-ds-2
sleep 60
podman start ping-ds-proxy
sleep 30
podman start ping-am
podman start ping-idm
sleep 60  # Wait for AM and IDM
podman start ping-ig
podman start ping-admin-ui
podman start ping-login-ui
```

#### Shutdown Order

**Graceful shutdown** (reverse of startup):
```bash
podman stop ping-admin-ui ping-login-ui
podman stop ping-ig
podman stop ping-idm ping-am
podman stop ping-ds-proxy
podman stop ping-ds-2 ping-ds-1
podman stop ping-mysql
```

#### Health Checks

The Containerfiles include health checks, but **validate manually**:

```bash
# DS
podman exec ping-ds-1 /opt/opendj/bin/status \
  --bindDN "cn=Directory Manager" --bindPassword changeme \
  --useSSL --trustAll

# AM
curl -f http://localhost:8082/am/isAlive.jsp

# IDM
curl -f -k -u openidm-admin:changeme \
  https://localhost:8446/openidm/info/ping

# IG
curl -f http://localhost:8084/ig/status

# MySQL
podman exec ping-mysql mysqladmin ping -h localhost -u root -pchangeme
```

#### Log Locations

**Container Logs**:
```bash
# View logs
podman logs ping-ds-1
podman logs -f ping-am  # Follow

# Export logs
podman logs ping-idm > idm.log 2>&1
```

**Application Logs** (inside containers):
- DS: `/opt/opendj/logs/`
- AM: `/usr/local/tomcat/logs/`, `/home/forgerock/logs/`
- IDM: `/opt/openidm/logs/`
- IG: `/var/ig/logs/`
- MySQL: `/var/log/mysql/`

**Accessing Application Logs**:
```bash
# Exec into container
podman exec -it ping-am bash
cd /home/forgerock/logs
tail -f catalina.out

# Or copy out
podman cp ping-am:/home/forgerock/logs/catalina.out ./
```

### 9. Troubleshooting Tips

#### Container Won't Start

**Check Logs First**:
```bash
podman logs <container-name>
```

**Common Issues**:
1. **Port already in use**:
   ```bash
   # Find what's using the port
   sudo ss -tulpn | grep :8080
   # Kill the process or change the port mapping
   ```

2. **Volume permission denied**:
   ```bash
   # Check volume ownership
   podman volume inspect ds-data-1
   # Fix permissions (exec as root in container)
   podman exec -u root ping-ds-1 chown -R forgerock:root /opt/opendj/data
   ```

3. **Out of memory**:
   ```bash
   # Check container stats
   podman stats
   # Increase limits in compose file
   ```

4. **SELinux denials**:
   ```bash
   # Check audit log
   sudo ausearch -m avc -ts recent
   # Temporarily set permissive
   sudo setenforce 0
   # Fix and re-enable
   ```

#### Replication Not Working

**Check Replication Status**:
```bash
podman exec ping-ds-1 /opt/opendj/bin/dsreplication status \
  --hostname ds-1.ping.local --port 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt
```

**Common Issues**:
1. **Replication port not accessible**:
   ```bash
   podman exec ping-ds-2 nc -zv ds-1.ping.local 8989
   ```

2. **Mismatched base DNs**:
   Ensure both DS instances use the same `BASE_DN` environment variable.

3. **Clock skew**:
   Replication requires synchronized clocks. Check host system time:
   ```bash
   timedatectl status
   ```

#### AM Can't Connect to DS

**Test LDAP Connectivity**:
```bash
podman exec ping-am ldapsearch -h ds-1.ping.local -p 1389 \
  -D "cn=Directory Manager" -w changeme \
  -b "dc=example,dc=com" "(objectClass=*)"
```

**Common Issues**:
1. **DNS resolution failure**:
   ```bash
   podman exec ping-am nslookup ds-1.ping.local
   podman exec ping-am ping -c 3 ds-1.ping.local
   ```

2. **Incorrect credentials**:
   Verify environment variables in `podman-compose.yml` match DS configuration.

3. **Base DN mismatch**:
   Ensure AM's user store configuration matches DS's `BASE_DN`.

#### IDM Can't Connect to MySQL

**Test MySQL Connectivity**:
```bash
podman exec ping-idm nc -zv ping-mysql 3306
```

**Check MySQL Logs**:
```bash
podman logs ping-mysql | grep -i error
```

**Common Issues**:
1. **MySQL not initialized**:
   ```bash
   podman exec ping-mysql mysql -u root -pchangeme -e "SHOW DATABASES;"
   # Should list 'openidm' database
   ```

2. **Connection refused**:
   Ensure MySQL health check passes before IDM starts:
   ```bash
   podman inspect ping-mysql | grep -i health
   ```

3. **Wrong password**:
   Verify `OPENIDM_REPO_PASSWORD` matches `MYSQL_PASSWORD` for the `openidm` user.

#### Performance Issues

**Container Resource Usage**:
```bash
podman stats --no-stream
```

**High CPU**:
- Check for excessive GC: Increase heap size
- Check for runaway threads: Review application logs
- Check for replication lag: May cause retry storms

**High Memory**:
- JVM heap too large: Reduce heap size
- Memory leak: Restart container, monitor
- Insufficient host memory: Add more RAM or reduce container count

**Slow Response Times**:
- Database performance: Tune MySQL, check slow query log
- Network latency: Check inter-container network performance
- Insufficient resources: Increase CPU allocation

## Future Enhancements

### Short Term

1. **Automated Certificate Generation**:
   Script to generate all required certificates on first run.

2. **Backup Scripts**:
   Automated backup and restore scripts for all volumes.

3. **Monitoring Integration**:
   Prometheus exporters for each component.

4. **Configuration Templates**:
   Jinja2 templates for environment-specific configurations.

### Medium Term

1. **Multi-Host Deployment**:
   Podman pods across multiple hosts with shared storage (NFS, Ceph).

2. **CI/CD Integration**:
   GitLab CI or Jenkins pipelines for automated testing and deployment.

3. **Secrets Management**:
   Integration with HashiCorp Vault or Red Hat's secrets management.

4. **Log Aggregation**:
   Fluentd/Fluentbit integration with Elasticsearch or Splunk.

### Long Term

1. **Kubernetes Migration Path**:
   Helm charts derived from this Podman setup.

2. **Operator Development**:
   Kubernetes Operator for lifecycle management.

3. **Service Mesh Integration**:
   Istio or Linkerd for advanced traffic management.

4. **Cloud Deployment**:
   Terraform modules for AWS, Azure, GCP deployments.

## Known Limitations

### Current Architecture

1. **Single Host**:
   All services run on one host. No true HA across hosts.

2. **No Auto-Scaling**:
   Manual resource allocation. Cannot scale based on load.

3. **Manual Failover**:
   If a service fails, requires manual intervention (unless using systemd restart).

4. **Limited Load Balancing**:
   DS-Proxy provides LB for AM config store only. No LB for AM, IDM, IG.

5. **Static Configuration**:
   Configuration changes require container rebuilds or restarts.

### Workarounds

**HA Workaround**:
- Deploy on VM with VM-level HA (vMotion, etc.)
- Use shared storage (iSCSI, NFS) for volumes
- Implement external load balancer (HAProxy on separate host)

**Scaling Workaround**:
- Pre-allocate generous resources
- Monitor and manually adjust as needed
- Plan for vertical scaling (larger host)

**Configuration Workaround**:
- Use volume mounts for configuration files (not baked into images)
- Implement configuration management (Ansible, Puppet)
- Use environment variables for runtime configuration

## Testing Checklist

Before deploying to production, validate the following:

### Functional Testing

- [ ] All containers start successfully
- [ ] DS replication is functional (test data sync)
- [ ] AM authentication works (login test)
- [ ] IDM API is accessible (create/read/update/delete user)
- [ ] IG token validation works (OAuth flow)
- [ ] Admin UI can manage AM and IDM
- [ ] Login UI can authenticate users
- [ ] MySQL data persists across IDM restarts
- [ ] AD connector can connect (if using)
- [ ] All health checks pass

### Non-Functional Testing

- [ ] Performance: < 500ms response time for login
- [ ] Load: Support expected concurrent users
- [ ] Backup: Successful backup and restore
- [ ] Disaster Recovery: Full recovery within RTO
- [ ] Security: Penetration testing completed
- [ ] Security: All default passwords changed
- [ ] Monitoring: Alerts trigger appropriately
- [ ] Documentation: Runbooks complete
- [ ] High Availability: Failover tested (if applicable)
- [ ] Compliance: Meets regulatory requirements

### Operational Testing

- [ ] Startup: Services start in correct order
- [ ] Shutdown: Graceful shutdown works
- [ ] Restart: Individual service restart doesn't impact others
- [ ] Logs: All logs accessible and aggregated
- [ ] Metrics: All metrics collected
- [ ] Upgrades: Upgrade procedure tested
- [ ] Rollback: Rollback procedure tested

## Useful Commands Reference

### Podman Compose

```bash
# Start all services
podman-compose up -d

# Stop all services
podman-compose down

# Restart a service
podman-compose restart idm

# View logs
podman-compose logs -f am

# Rebuild and restart
podman-compose up -d --build

# Scale a service (limited support)
podman-compose up -d --scale am=2
```

### Podman

```bash
# List containers
podman ps -a

# Inspect container
podman inspect ping-am

# Execute command
podman exec -it ping-am bash

# Copy files
podman cp ping-am:/path/to/file ./local-file
podman cp ./local-file ping-am:/path/to/file

# View resource usage
podman stats

# View container logs
podman logs -f ping-am

# Remove all stopped containers
podman container prune

# Remove all unused images
podman image prune -a

# Remove all unused volumes
podman volume prune
```

### DS Commands

```bash
# LDAP search
podman exec ping-ds-1 /opt/opendj/bin/ldapsearch \
  -h localhost -p 1389 -D "cn=Directory Manager" -w changeme \
  -b "dc=example,dc=com" "(uid=testuser)"

# LDAP add
podman exec ping-ds-1 /opt/opendj/bin/ldapadd \
  -h localhost -p 1389 -D "cn=Directory Manager" -w changeme \
  -f /path/to/file.ldif

# LDAP modify
podman exec ping-ds-1 /opt/opendj/bin/ldapmodify \
  -h localhost -p 1389 -D "cn=Directory Manager" -w changeme \
  -f /path/to/changes.ldif

# Replication status
podman exec ping-ds-1 /opt/opendj/bin/dsreplication status \
  --hostname localhost --port 4444 \
  --adminUID admin --adminPassword changeme \
  --trustAll --no-prompt

# Backup
podman exec ping-ds-1 /opt/opendj/bin/backup \
  --backupDirectory /opt/opendj/bak --backendID userRoot

# Restore
podman exec ping-ds-1 /opt/opendj/bin/restore \
  --backupDirectory /opt/opendj/bak --backendID userRoot
```

### AM Commands

```bash
# Check AM status
curl http://localhost:8082/am/isAlive.jsp

# Get server info
curl http://localhost:8082/am/json/serverinfo/*

# Authenticate (get token)
curl -X POST "http://localhost:8082/am/json/authenticate" \
  -H "Content-Type: application/json" \
  -H "X-OpenAM-Username: amadmin" \
  -H "X-OpenAM-Password: changeme"

# OAuth token request
curl -X POST "http://localhost:8082/am/oauth2/access_token" \
  -d "grant_type=password&username=demo&password=changeme&client_id=client&client_secret=secret&scope=openid"
```

### IDM Commands

```bash
# Ping IDM
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/info/ping"

# Get managed users
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/managed/user?_queryFilter=true"

# Create user
curl -k -u openidm-admin:changeme \
  -X POST "https://localhost:8446/openidm/managed/user?_action=create" \
  -H "Content-Type: application/json" \
  -d '{
    "userName": "testuser",
    "givenName": "Test",
    "sn": "User",
    "mail": "testuser@example.com",
    "password": "Password123"
  }'

# Run reconciliation
curl -k -u openidm-admin:changeme \
  -X POST "https://localhost:8446/openidm/recon?_action=recon&mapping=systemAdAccount_managedUser"

# Check connector status
curl -k -u openidm-admin:changeme \
  "https://localhost:8446/openidm/config/provisioner.openicf/ad" \
  | jq .

# Test connector
curl -k -u openidm-admin:changeme \
  -X POST "https://localhost:8446/openidm/system/ad?_action=test" \
  -H "Content-Type: application/json"
```

### MySQL Commands

```bash
# Connect to MySQL
podman exec -it ping-mysql mysql -u openidm -popenidm openidm

# Backup database
podman exec ping-mysql mysqldump -u openidm -popenidm openidm > idm-backup.sql

# Restore database
cat idm-backup.sql | podman exec -i ping-mysql mysql -u openidm -popenidm openidm

# Check database size
podman exec ping-mysql mysql -u openidm -popenidm -e "
  SELECT table_schema AS 'Database',
         ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.tables
  WHERE table_schema = 'openidm'
  GROUP BY table_schema;
"

# Check table row counts
podman exec ping-mysql mysql -u openidm -popenidm openidm -e "
  SELECT table_name, table_rows
  FROM information_schema.tables
  WHERE table_schema = 'openidm'
  ORDER BY table_rows DESC;
"
```

## References

### Official Documentation

- [Ping Identity Docs](https://docs.pingidentity.com/)
- [ForgeRock Docs Archive](https://backstage.forgerock.com/docs/)
- [ForgeOps GitHub](https://github.com/ForgeRock/forgeops)
- [Podman Documentation](https://docs.podman.io/)
- [Podman Compose GitHub](https://github.com/containers/podman-compose)

### Related Technologies

- [OpenLDAP Admin Guide](https://www.openldap.org/doc/admin24/)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OpenID Connect Spec](https://openid.net/specs/openid-connect-core-1_0.html)
- [SAML 2.0 Spec](http://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-tech-overview-2.0.html)

### Community

- [Ping Identity Community](https://community.pingidentity.com/)
- [ForgeRock Community (Archive)](https://forum.forgerock.com/)
- [Podman Users Mailing List](https://lists.podman.io/archives/)

## Contribution Guidelines

If you enhance this deployment, please document:

1. **What you changed and why**
2. **Any new dependencies or requirements**
3. **Testing performed**
4. **Impact on existing deployments**

Update the following:
- This NOTES.md file (add to relevant sections)
- README.md (if user-facing changes)
- ARCHITECTURE.md (if architectural changes)
- Bump version numbers

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-01-15 | Initial conversion from ForgeOps | Platform Team |

---

**Document Version**: 1.0.0
**Last Updated**: 2024-01-15
**Maintainer**: Platform Team

**For questions or support**: Open an issue in the repository or contact the platform team.
