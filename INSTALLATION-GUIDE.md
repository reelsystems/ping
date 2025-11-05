# Ping Identity Platform - Installation Guide

**Version**: 7.5.2 Docker Deployment
**Environment**: Demo/Development
**Date**: 2025-11-04

---

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [Phase 0: Prerequisites Verification](#phase-0-prerequisites-verification)
3. [Phase 1: Infrastructure Setup](#phase-1-infrastructure-setup)
4. [Phase 2: PingDS Deployment](#phase-2-pingds-deployment)
5. [Phase 3: PingIDM Deployment](#phase-3-pingidm-deployment)
6. [Phase 4: PingAM Deployment](#phase-4-pingam-deployment)
7. [Phase 5: Integration & Validation](#phase-5-integration--validation)
8. [Phase 6: Data Migration Setup](#phase-6-data-migration-setup)
9. [Post-Installation](#post-installation)
10. [Troubleshooting](#troubleshooting)

---

## Before You Begin

### What You'll Build

By the end of this guide, you will have deployed:
- 4 PingDS instances in multi-master replication
- 2 PingIDM instances in active-active cluster
- 2 PingAM instances in site-based configuration
- Complete integration between all components
- Data synchronization from external systems

### Estimated Time

- **First-time installation**: 4-6 hours
- **Experienced operator**: 2-3 hours

### Required Access

- Root/sudo access on Linux host
- Access to Ping Identity Backstage for downloads
- Connection details for MS SQL databases (if configuring connectors)
- Connection details for Active Directory (if configuring connectors)

### Documentation References

Keep these documents handy:
- [checklist.md](checklist.md) - Track requirements and progress
- [architecture.md](architecture.md) - Reference architecture diagrams
- [WORKFLOW.md](WORKFLOW.md) - Track deployment progress
- [CONSIDERATIONS.md](CONSIDERATIONS.md) - Best practices and troubleshooting

---

## Phase 0: Prerequisites Verification

### Step 0.1: System Requirements Check

Execute the following commands to verify your system:

```bash
# Check OS version
cat /etc/os-release

# Check available disk space (need at least 100 GB)
df -h /home/thepackle/repos/ping

# Check available memory (need at least 16 GB)
free -h

# Check CPU cores (need at least 8 cores)
nproc

# Check if we're in the correct directory
pwd
# Expected output: /home/thepackle/repos/ping
```

### Step 0.2: Verify Java Installation

```bash
# Check Java version (need Java 11.0.6+ or Java 17.0.3+)
java -version

# Check JAVA_HOME is set
echo $JAVA_HOME

# If Java is not installed or wrong version, install:
# Ubuntu/Debian:
sudo apt update
sudo apt install openjdk-17-jdk -y

# RHEL/CentOS:
sudo yum install java-17-openjdk-devel -y

# Set JAVA_HOME (add to ~/.bashrc for persistence)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

### Step 0.3: Verify Docker Installation

```bash
# Check Docker version (need 20.10.0+)
docker --version

# Check Docker Compose version (need v2.0.0+)
docker compose version

# If Docker is not installed:
# Ubuntu/Debian:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker works
docker run hello-world

# Start Docker service if not running
sudo systemctl start docker
sudo systemctl enable docker
```

### Step 0.4: Download Ping Identity Software

1. **Register/Sign In**:
   - Go to https://backstage.forgerock.com
   - Create account or sign in with existing credentials

2. **Download PingDS 7.5.2**:
   - Navigate to Downloads > Directory Services
   - Download: `DS-7.5.2.zip`
   - Verify SHA256 checksum (if provided)
   - Save to: `/home/thepackle/repos/ping/shared/downloads/`

3. **Download PingIDM 7.5.2**:
   - Navigate to Downloads > Identity Management
   - Download: `IDM-7.5.2.zip`
   - Save to: `/home/thepackle/repos/ping/shared/downloads/`

4. **Download PingAM 7.5.2**:
   - Navigate to Downloads > Access Management
   - Download: `AM-7.5.2.zip`
   - Save to: `/home/thepackle/repos/ping/shared/downloads/`

```bash
# Create downloads directory
mkdir -p shared/downloads

# Verify downloads (adjust paths as needed)
ls -lh shared/downloads/
# Should see: DS-7.5.2.zip, IDM-7.5.2.zip, AM-7.5.2.zip

# Extract distributions
cd shared/downloads/
unzip DS-7.5.2.zip
unzip IDM-7.5.2.zip
unzip AM-7.5.2.zip
cd ../..
```

### Step 0.5: Verify Network Ports Available

```bash
# Check if required ports are available
netstat -tuln | grep -E ':(1636|1637|1638|1639|4444|4445|4446|4447|8080|8081|8082|8083|8090|8091|8100|8101|8443|8444|8445|8446|8453|8454)'

# If any ports are in use, either:
# 1. Stop the conflicting service
# 2. Modify port assignments in this guide
```

---

## Phase 1: Infrastructure Setup

### Step 1.1: Verify Directory Structure

The directory structure should already exist (created in initial setup):

```bash
# Verify structure
tree -L 2 -d

# Expected output shows DS1-DS4, IDM1-IDM2, AM1-AM2, shared directories
```

### Step 1.2: Create Docker Network

```bash
# Create custom bridge network for Ping services
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  ping-network

# Verify network created
docker network ls | grep ping-network

# Inspect network
docker network inspect ping-network
```

### Step 1.3: Configure DNS/Hosts Resolution

```bash
# Edit /etc/hosts to add container hostname resolution
sudo bash -c 'cat >> /etc/hosts << EOF

# Ping Identity Platform - Container Hostnames
172.20.0.11  ds1-container ds1
172.20.0.12  ds2-container ds2
172.20.0.13  ds3-container ds3
172.20.0.14  ds4-container ds4
172.20.0.21  idm1-container idm1
172.20.0.22  idm2-container idm2
172.20.0.31  am1-container am1
172.20.0.32  am2-container am2
EOF'

# Verify entries added
tail -10 /etc/hosts
```

### Step 1.4: Generate Self-Signed Certificates (Demo)

```bash
# Navigate to certs directory
cd shared/certs

# Generate CA certificate
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -out ca-cert.pem \
  -subj "/C=US/ST=State/L=City/O=Demo/OU=IAM/CN=Demo CA"

# Generate server certificate for DS1
openssl genrsa -out ds1-key.pem 2048
openssl req -new -key ds1-key.pem -out ds1-csr.pem \
  -subj "/C=US/ST=State/L=City/O=Demo/OU=IAM/CN=ds1-container"
openssl x509 -req -in ds1-csr.pem -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out ds1-cert.pem -days 365

# Repeat for DS2-DS4, IDM1-IDM2, AM1-AM2 (example for DS2)
openssl genrsa -out ds2-key.pem 2048
openssl req -new -key ds2-key.pem -out ds2-csr.pem \
  -subj "/C=US/ST=State/L=City/O=Demo/OU=IAM/CN=ds2-container"
openssl x509 -req -in ds2-csr.pem -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out ds2-cert.pem -days 365

# Continue for remaining instances...
# (For brevity, DS will generate its own certs; these are optional)

# Secure certificate files
chmod 600 *-key.pem
chmod 644 *-cert.pem

# Return to project root
cd ../..
```

---

## Phase 2: PingDS Deployment

### Overview

We'll deploy DS instances in this order:
1. DS1 (Primary) - Standalone setup
2. DS2 (Fallback) - Standalone setup, then enable replication
3. DS3 and DS4 (Replicas) - Join replication topology

### Step 2.1: Create DS1 Dockerfile

```bash
# Create Dockerfile for DS1
cat > DS1/Dockerfile << 'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y openjdk-17-jre-headless curl unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Copy DS distribution
COPY --from=source /opendj /opt/opendj

# Set working directory
WORKDIR /opt/opendj

# Expose ports
EXPOSE 1636 4444 8080 8443 8989

# Start command (will be overridden by docker-compose)
CMD ["/opt/opendj/bin/start-ds", "--nodetach"]
EOF
```

**Note**: This Dockerfile assumes DS is extracted. For a real deployment, you would:
1. Build a base image with extracted DS
2. Or use official Ping Identity Docker images (if available)
3. Or extract DS in the Dockerfile from a mounted volume

### Step 2.2: Simpler Approach - Use Volume Mounts

Instead of building custom Docker images, we'll use a base Java image and mount the DS distribution:

```bash
# Create docker-compose.yml for DS1
cat > DS1/docker-compose.yml << 'EOF'
version: '3.8'

services:
  ds1:
    image: openjdk:17-slim
    container_name: ds1-container
    hostname: ds1-container
    networks:
      ping-network:
        ipv4_address: 172.20.0.11
    ports:
      - "1636:1636"
      - "4444:4444"
      - "8080:8080"
      - "8443:8443"
      - "8989:8989"
    volumes:
      - ../shared/downloads/opendj:/opt/opendj
      - ./data:/opt/opendj/db
      - ./logs:/opt/opendj/logs
      - ./config:/opt/opendj/config
    environment:
      - JAVA_HOME=/usr/local/openjdk-17
    working_dir: /opt/opendj
    command: |
      sh -c "
      if [ ! -f /opt/opendj/.initialized ]; then
        echo 'Setting up DS1 for first time...'
        /opt/opendj/setup \
          --serverId ds1 \
          --deploymentId demo-deployment \
          --deploymentIdPassword password \
          --rootUserDn 'cn=Directory Manager' \
          --rootUserPassword password \
          --monitorUserPassword password \
          --hostname ds1-container \
          --ldapPort 1389 \
          --ldapsPort 1636 \
          --httpsPort 8443 \
          --adminConnectorPort 4444 \
          --replicationPort 8989 \
          --profile ds-evaluation \
          --set ds-evaluation/baseDn:dc=example,dc=com \
          --acceptLicense
        touch /opt/opendj/.initialized
      fi
      /opt/opendj/bin/start-ds --nodetach
      "
    restart: unless-stopped

networks:
  ping-network:
    external: true
EOF
```

**Important Note**: The above uses a simplified approach. In production, you should:
- Use official Ping Identity Docker images (e.g., `pingidentity/pingdirectory`)
- Or build proper Docker images with DS baked in
- Manage secrets securely (not in command line)

### Step 2.3: Alternative - Using Official Ping Identity Images

Ping Identity provides official Docker images. Here's the recommended approach:

```bash
# Create docker-compose.yml for DS1 using official image
cat > DS1/docker-compose.yml << 'EOF'
version: '3.8'

services:
  ds1:
    image: pingidentity/pingdirectory:7.5.2
    container_name: ds1-container
    hostname: ds1-container
    networks:
      ping-network:
        ipv4_address: 172.20.0.11
    ports:
      - "1636:1636"
      - "4444:4444"
      - "8080:8080"
      - "8443:8443"
      - "8989:8989"
    environment:
      - SERVER_PROFILE_PATH=profiles/ds-evaluation
      - ROOT_USER_DN=cn=Directory Manager
      - ROOT_USER_PASSWORD=password
      - LDAP_PORT=1389
      - LDAPS_PORT=1636
      - HTTPS_PORT=8443
      - ADMIN_CONNECTOR_PORT=4444
      - REPLICATION_PORT=8989
      - BASE_DN=dc=example,dc=com
    volumes:
      - ./data:/opt/out
      - ./logs:/opt/out/instance/logs
    restart: unless-stopped

networks:
  ping-network:
    external: true
EOF
```

### Step 2.4: Start DS1

```bash
# Navigate to DS1 directory
cd DS1

# Pull the image (if using official image)
docker compose pull

# Start DS1 container
docker compose up -d

# Monitor startup logs
docker logs -f ds1-container

# Wait for startup message (may take 2-5 minutes)
# Look for: "The Directory Server has started successfully"

# Press Ctrl+C to exit log view
```

### Step 2.5: Verify DS1 Installation

```bash
# Check container is running
docker ps | grep ds1

# Check DS1 status
docker exec ds1-container /opt/out/instance/bin/status \
  --bindDN "cn=Directory Manager" \
  --bindPassword password

# Perform LDAP search test
docker exec ds1-container /opt/out/instance/bin/ldapsearch \
  --hostname localhost \
  --port 1636 \
  --bindDN "cn=Directory Manager" \
  --bindPassword password \
  --baseDN "dc=example,dc=com" \
  --searchScope base \
  "(objectClass=*)" \
  --useSSL \
  --trustAll

# Access admin console
echo "Access DS1 admin console at: https://localhost:8443"
echo "Login: cn=Directory Manager / password"
```

### Step 2.6: Deploy DS2

```bash
# Return to project root
cd ..

# Copy DS1 configuration for DS2 (with modifications)
cp DS1/docker-compose.yml DS2/docker-compose.yml

# Edit DS2/docker-compose.yml:
# 1. Change container_name to ds2-container
# 2. Change hostname to ds2-container
# 3. Change IP to 172.20.0.12
# 4. Change ports to 1637, 4445, 8081, 8444, 8990
# 5. Update volumes to point to ./data, ./logs

# Use sed to make changes automatically
sed -i 's/ds1-container/ds2-container/g' DS2/docker-compose.yml
sed -i 's/172.20.0.11/172.20.0.12/g' DS2/docker-compose.yml
sed -i 's/"1636:1636"/"1637:1636"/g' DS2/docker-compose.yml
sed -i 's/"4444:4444"/"4445:4444"/g' DS2/docker-compose.yml
sed -i 's/"8080:8080"/"8081:8080"/g' DS2/docker-compose.yml
sed -i 's/"8443:8443"/"8444:8443"/g' DS2/docker-compose.yml
sed -i 's/"8989:8989"/"8990:8989"/g' DS2/docker-compose.yml

# Start DS2
cd DS2
docker compose up -d

# Monitor logs
docker logs -f ds2-container

# Wait for startup, then exit with Ctrl+C
cd ..
```

### Step 2.7: Configure Replication Between DS1 and DS2

```bash
# Enable replication from DS1 to DS2
docker exec ds1-container /opt/out/instance/bin/dsreplication enable \
  --host1 ds1-container --port1 4444 \
  --bindDN1 "cn=Directory Manager" --bindPassword1 password \
  --replicationPort1 8989 \
  --host2 ds2-container --port2 4444 \
  --bindDN2 "cn=Directory Manager" --bindPassword2 password \
  --replicationPort2 8989 \
  --adminUID admin --adminPassword password \
  --baseDN "dc=example,dc=com" \
  --trustAll --no-prompt

# Initialize replication (DS1 -> DS2)
docker exec ds1-container /opt/out/instance/bin/dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds1-container --portSource 4444 \
  --hostDestination ds2-container --portDestination 4444 \
  --adminUID admin --adminPassword password \
  --trustAll --no-prompt

# Check replication status
docker exec ds1-container /opt/out/instance/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt

# Should show both DS1 and DS2 connected with replication lag info
```

### Step 2.8: Test Replication

```bash
# Create a test entry on DS1
docker exec ds1-container /opt/out/instance/bin/ldapmodify \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --useSSL --trustAll << EOF
dn: uid=testuser,dc=example,dc=com
changetype: add
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: testuser
cn: Test User
sn: User
mail: testuser@example.com
userPassword: password123
EOF

# Verify entry exists on DS2 (replication)
docker exec ds2-container /opt/out/instance/bin/ldapsearch \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --baseDN "dc=example,dc=com" \
  --searchScope sub \
  "(uid=testuser)" \
  --useSSL --trustAll

# Should return the test user entry
```

### Step 2.9: Deploy DS3 and DS4 (Optional Replicas)

```bash
# Copy configuration for DS3
cp DS1/docker-compose.yml DS3/docker-compose.yml
sed -i 's/ds1-container/ds3-container/g' DS3/docker-compose.yml
sed -i 's/172.20.0.11/172.20.0.13/g' DS3/docker-compose.yml
sed -i 's/"1636:1636"/"1638:1636"/g' DS3/docker-compose.yml
sed -i 's/"4444:4444"/"4446:4444"/g' DS3/docker-compose.yml
sed -i 's/"8080:8080"/"8082:8080"/g' DS3/docker-compose.yml
sed -i 's/"8443:8443"/"8445:8443"/g' DS3/docker-compose.yml
sed -i 's/"8989:8989"/"8991:8989"/g' DS3/docker-compose.yml

# Start DS3
cd DS3
docker compose up -d
docker logs -f ds3-container
# Wait for startup, Ctrl+C to exit
cd ..

# Add DS3 to replication topology
docker exec ds1-container /opt/out/instance/bin/dsreplication enable \
  --host1 ds1-container --port1 4444 \
  --bindDN1 "cn=Directory Manager" --bindPassword1 password \
  --replicationPort1 8989 \
  --host2 ds3-container --port2 4444 \
  --bindDN2 "cn=Directory Manager" --bindPassword2 password \
  --replicationPort2 8989 \
  --adminUID admin --adminPassword password \
  --baseDN "dc=example,dc=com" \
  --trustAll --no-prompt

# Initialize DS3 from DS1
docker exec ds1-container /opt/out/instance/bin/dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds1-container --portSource 4444 \
  --hostDestination ds3-container --portDestination 4444 \
  --adminUID admin --adminPassword password \
  --trustAll --no-prompt

# Repeat for DS4 (adjust names, IPs, ports)
# DS4: container=ds4-container, IP=172.20.0.14, ports=1639,4447,8083,8446,8992
```

### Step 2.10: Verify Complete DS Topology

```bash
# Check replication status (should show all 4 servers)
docker exec ds1-container /opt/out/instance/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt

# Verify test user on all instances
for ds in ds1 ds2 ds3 ds4; do
  echo "Checking $ds..."
  docker exec ${ds}-container /opt/out/instance/bin/ldapsearch \
    --hostname localhost --port 1636 \
    --bindDN "cn=Directory Manager" --bindPassword password \
    --baseDN "dc=example,dc=com" \
    --searchScope sub "(uid=testuser)" cn \
    --useSSL --trustAll
done
```

### Step 2.11: Configure DS for PingAM (Optional - Do Before AM Deployment)

If you plan to deploy PingAM, configure DS with AM-specific schema:

```bash
# This step will be covered in Phase 4 before AM deployment
# For now, note that DS1 will need additional setup profiles:
# - am-identity-store
# - am-config-store
# - am-cts
```

---

## Phase 3: PingIDM Deployment

### Overview

We'll deploy IDM instances in this order:
1. IDM1 (Primary) - Connected to DS1 as primary repository
2. IDM2 (Fallback) - Connected to DS2 as primary, join cluster with IDM1

### Step 3.1: Prepare IDM Configuration

```bash
# Extract IDM distribution to shared location (if not already done)
# Assuming extracted to: shared/downloads/openidm

# Copy base configuration to IDM1
cd IDM1
cp -r ../shared/downloads/openidm/* ./

# IDM directories should now have:
# - conf/ (configuration)
# - bin/ (binaries)
# - connectors/ (connector JARs)
# - etc.
```

### Step 3.2: Configure IDM1 Repository (DS Connection)

```bash
# Edit conf/boot.properties
cat > conf/boot.properties << 'EOF'
# Boot Properties for IDM1
openidm.host=idm1-container
openidm.port.http=8080
openidm.port.https=8443
openidm.port.mutualauth=8444
openidm.keystore.password=changeit
openidm.truststore.password=changeit
EOF

# Create DS repository configuration
cat > conf/repo.ds.json << 'EOF'
{
  "dbType": "DS",
  "useDataSource": "default",
  "connectionTimeout": 30000,
  "ldapConnectionFactories": [
    {
      "primaryLdapServers": [
        {
          "hostname": "ds1-container",
          "port": 1636
        }
      ],
      "secondaryLdapServers": [
        {
          "hostname": "ds2-container",
          "port": 1636
        }
      ]
    }
  ],
  "security": {
    "trustManager": "jvm"
  },
  "authentication": {
    "simple": {
      "bindDn": "cn=Directory Manager",
      "bindPassword": "password"
    }
  }
}
EOF

# Configure clustering
cat > conf/cluster.json << 'EOF'
{
  "instanceId": "idm1",
  "enabled": true
}
EOF
```

### Step 3.3: Create IDM1 Docker Compose

```bash
# Create docker-compose.yml for IDM1
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  idm1:
    image: pingidentity/pingidentitymanager:7.5.2
    container_name: idm1-container
    hostname: idm1-container
    networks:
      ping-network:
        ipv4_address: 172.20.0.21
    ports:
      - "8090:8080"
      - "8453:8443"
    environment:
      - OPENIDM_HOST=idm1-container
      - OPENIDM_OPTS=-Xms2g -Xmx4g
    volumes:
      - ./conf:/opt/openidm/conf
      - ./connectors:/opt/openidm/connectors
      - ./script:/opt/openidm/script
      - ./logs:/opt/openidm/logs
    restart: unless-stopped
    depends_on:
      - ds1

networks:
  ping-network:
    external: true
EOF
```

**Note**: If official Ping images don't exist or you're using extracted distribution:

```bash
# Alternative: Use Java base image with volume mount
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  idm1:
    image: openjdk:17-slim
    container_name: idm1-container
    hostname: idm1-container
    networks:
      ping-network:
        ipv4_address: 172.20.0.21
    ports:
      - "8090:8080"
      - "8453:8443"
    volumes:
      - .:/opt/openidm
    working_dir: /opt/openidm
    environment:
      - JAVA_OPTS=-Xms2g -Xmx4g
    command: ./startup.sh
    restart: unless-stopped

networks:
  ping-network:
    external: true
EOF
```

### Step 3.4: Start IDM1

```bash
# Ensure we're in IDM1 directory
cd /home/thepackle/repos/ping/IDM1

# Start IDM1
docker compose up -d

# Monitor startup logs
docker logs -f idm1-container

# Wait for: "OpenIDM ready" message (may take 2-3 minutes)
# Press Ctrl+C to exit
```

### Step 3.5: Verify IDM1 Installation

```bash
# Check container status
docker ps | grep idm1

# Test IDM API
curl -k -u admin:admin https://localhost:8453/openidm/info/ping
# Expected: {"status": "UP"}

# Access admin console
echo "IDM1 Admin Console: https://localhost:8453/admin"
echo "Login: admin / admin"

# Open in browser and verify:
# - Dashboard loads
# - Repository connection shows green/healthy
# - No error messages
```

### Step 3.6: Deploy IDM2

```bash
# Return to project root
cd /home/thepackle/repos/ping

# Copy IDM1 configuration to IDM2
cp -r IDM1/* IDM2/

# Update IDM2 configuration
cd IDM2

# Update boot.properties
sed -i 's/idm1-container/idm2-container/g' conf/boot.properties

# Update cluster.json
sed -i 's/"instanceId": "idm1"/"instanceId": "idm2"/g' conf/cluster.json

# Update repo.ds.json to prefer DS2
# Swap primary and secondary servers
cat > conf/repo.ds.json << 'EOF'
{
  "dbType": "DS",
  "useDataSource": "default",
  "connectionTimeout": 30000,
  "ldapConnectionFactories": [
    {
      "primaryLdapServers": [
        {
          "hostname": "ds2-container",
          "port": 1636
        }
      ],
      "secondaryLdapServers": [
        {
          "hostname": "ds1-container",
          "port": 1636
        }
      ]
    }
  ],
  "security": {
    "trustManager": "jvm"
  },
  "authentication": {
    "simple": {
      "bindDn": "cn=Directory Manager",
      "bindPassword": "password"
    }
  }
}
EOF

# Update docker-compose.yml
sed -i 's/idm1-container/idm2-container/g' docker-compose.yml
sed -i 's/172.20.0.21/172.20.0.22/g' docker-compose.yml
sed -i 's/"8090:8080"/"8091:8080"/g' docker-compose.yml
sed -i 's/"8453:8443"/"8454:8443"/g' docker-compose.yml
sed -i 's/ds1/ds2/g' docker-compose.yml

# Start IDM2
docker compose up -d

# Monitor logs
docker logs -f idm2-container
# Wait for "OpenIDM ready"
```

### Step 3.7: Verify IDM Clustering

```bash
# Check IDM2 API
curl -k -u admin:admin https://localhost:8454/openidm/info/ping

# Check cluster status from IDM1
curl -k -u admin:admin https://localhost:8453/openidm/cluster

# Expected: JSON showing both idm1 and idm2 instances

# Verify in admin console:
# - Access https://localhost:8453/admin
# - Navigate to Configure > System Preferences
# - Should show cluster with 2 nodes
```

### Step 3.8: Configure External System Connectors (Optional)

**Note**: This step requires connection details for your MS SQL databases and Active Directory. If you don't have these yet, you can skip and return to this later.

**MS SQL Connector Setup**:

```bash
# Download Microsoft JDBC driver (if not already available)
cd /home/thepackle/repos/ping/shared/downloads
wget https://download.microsoft.com/download/d/b/8/db8e8f9e-4136-4f94-9c47-f6ab7b5e8e4d/sqljdbc_12.2.0.0_enu.tar.gz
tar -xzf sqljdbc_12.2.0.0_enu.tar.gz
cp sqljdbc_12.2/enu/jars/mssql-jdbc-12.2.0.jre11.jar ../../IDM1/connectors/
cp sqljdbc_12.2/enu/jars/mssql-jdbc-12.2.0.jre11.jar ../../IDM2/connectors/

# Create provisioner configuration for SQL DB 1
cat > /home/thepackle/repos/ping/IDM1/conf/provisioner.openicf-mssql1.json << 'EOF'
{
  "name": "mssql1",
  "connectorRef": {
    "connectorHostRef": "#LOCAL",
    "connectorName": "org.identityconnectors.databasetable.DatabaseTableConnector",
    "bundleName": "org.forgerock.openicf.connectors.databasetable-connector",
    "bundleVersion": "[1.4.0.0,2.0.0.0)"
  },
  "configurationProperties": {
    "quoting": "",
    "host": "YOUR_SQL_SERVER_HOST",
    "port": "1433",
    "user": "YOUR_SQL_USER",
    "password": "YOUR_SQL_PASSWORD",
    "database": "YOUR_DATABASE_NAME",
    "table": "Users",
    "keyColumn": "UserID",
    "passwordColumn": null,
    "jdbcDriver": "com.microsoft.sqlserver.jdbc.SQLServerDriver",
    "jdbcUrlTemplate": "jdbc:sqlserver://%h:%p;databaseName=%d",
    "enableEmptyString": false,
    "rethrowAllSQLExceptions": true,
    "nativeTimestamps": true,
    "allNative": false
  },
  "poolConfigOption": {
    "maxObjects": 10,
    "maxIdle": 10,
    "maxWait": 150000,
    "minEvictableIdleTimeMillis": 120000,
    "minIdle": 1
  },
  "operationTimeout": {
    "CREATE": -1,
    "UPDATE": -1,
    "DELETE": -1,
    "TEST": -1,
    "SCRIPT_ON_CONNECTOR": -1,
    "SCRIPT_ON_RESOURCE": -1,
    "GET": -1,
    "RESOLVEUSERNAME": -1,
    "AUTHENTICATE": -1,
    "SEARCH": -1,
    "VALIDATE": -1,
    "SYNC": -1,
    "SCHEMA": -1
  }
}
EOF

# Copy to IDM2
cp /home/thepackle/repos/ping/IDM1/conf/provisioner.openicf-mssql1.json \
   /home/thepackle/repos/ping/IDM2/conf/

# Restart IDM instances to load new connector
docker restart idm1-container idm2-container

# Test connector
curl -k -u admin:admin "https://localhost:8453/openidm/system/mssql1?_action=test"
# Expected: {"ok": true} if connection successful
```

---

## Phase 4: PingAM Deployment

### Overview

Before deploying AM, we need to configure DS with AM-specific schema.

### Step 4.1: Prepare DS for AM (Setup Profiles)

```bash
# Run AM setup profiles on DS1
# This adds schema and base entries for AM config, identity, and CTS stores

# Identity Store Setup
docker exec ds1-container /opt/out/instance/setup \
  --serverId ds1-am \
  --deploymentId demo-am-deployment \
  --deploymentIdPassword password \
  --rootUserDN "cn=Directory Manager" \
  --rootUserPassword password \
  --hostname ds1-container \
  --ldapPort 1389 \
  --ldapsPort 1636 \
  --httpsPort 8443 \
  --adminConnectorPort 4444 \
  --replicationPort 8989 \
  --profile am-identity-store \
  --set am-identity-store/amIdentityStoreAdminPassword:password \
  --acceptLicense

# Config Store Setup
docker exec ds1-container /opt/out/instance/setup \
  --serverId ds1-am-config \
  --deploymentId demo-am-deployment \
  --deploymentIdPassword password \
  --rootUserDN "cn=Directory Manager" \
  --rootUserPassword password \
  --hostname ds1-container \
  --ldapPort 1389 \
  --ldapsPort 1636 \
  --httpsPort 8443 \
  --adminConnectorPort 4444 \
  --replicationPort 8989 \
  --profile am-config-store \
  --set am-config-store/amConfigStoreAdminPassword:password \
  --acceptLicense

# CTS Store Setup
docker exec ds1-container /opt/out/instance/setup \
  --serverId ds1-am-cts \
  --deploymentId demo-am-deployment \
  --deploymentIdPassword password \
  --rootUserDN "cn=Directory Manager" \
  --rootUserPassword password \
  --hostname ds1-container \
  --ldapPort 1389 \
  --ldapsPort 1636 \
  --httpsPort 8443 \
  --adminConnectorPort 4444 \
  --replicationPort 8989 \
  --profile am-cts \
  --acceptLicense

# Verify AM base entries created
docker exec ds1-container /opt/out/instance/bin/ldapsearch \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --baseDN "ou=am-config,dc=example,dc=com" \
  --searchScope base "(objectClass=*)" \
  --useSSL --trustAll

# Should return the ou=am-config base entry
```

**Note**: The above commands assume PingDS supports multiple setup profile invocations. Check PingDS 7.5 documentation for the exact approach. You may need to run these during initial setup or use `dsconfig` commands to add schema post-installation.

### Step 4.2: Create AM1 Docker Compose

```bash
cd /home/thepackle/repos/ping/AM1

# Create docker-compose.yml for AM1
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  am1:
    image: pingidentity/pingaccess:7.5.2
    container_name: am1-container
    hostname: am1-container
    networks:
      ping-network:
        ipv4_address: 172.20.0.31
    ports:
      - "8100:8080"
    environment:
      - AM_HOME=/opt/am
      - CATALINA_OPTS=-Xms4g -Xmx4g
    volumes:
      - ./config:/opt/am/config
      - ./logs:/opt/am/logs
    restart: unless-stopped

networks:
  ping-network:
    external: true
EOF
```

**Note**: Adjust image name based on available Ping AM Docker images. You may need to use:
- `pingidentity/pingaccess` (if available)
- Or deploy WAR file in Tomcat container
- Or use extracted AM distribution

**Alternative: Deploy AM WAR in Tomcat**:

```bash
# If using Tomcat approach
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  am1:
    image: tomcat:9-jdk17
    container_name: am1-container
    hostname: am1-container
    networks:
      ping-network:
        ipv4_address: 172.20.0.31
    ports:
      - "8100:8080"
    environment:
      - CATALINA_OPTS=-Xms4g -Xmx4g -server
    volumes:
      - ../shared/downloads/AM-7.5.2.war:/usr/local/tomcat/webapps/am.war
      - ./logs:/usr/local/tomcat/logs
    restart: unless-stopped

networks:
  ping-network:
    external: true
EOF
```

### Step 4.3: Start AM1 and Run Configuration Wizard

```bash
# Start AM1
docker compose up -d

# Monitor logs
docker logs -f am1-container

# Wait for Tomcat startup, then access AM configurator
echo "Access AM configuration wizard at: http://localhost:8100/am"

# Open browser to http://localhost:8100/am
# Follow on-screen configuration wizard
```

**AM Configuration Wizard Steps**:

1. **Accept License Agreement**: Check box and click Proceed

2. **Select Configuration Type**: Choose "Create New Configuration"

3. **General Configuration**:
   - Server URL: `http://localhost:8100/am`
   - Cookie Domain: `.example.com` (or `localhost` for testing)
   - Platform Locale: `en_US`
   - Configuration Directory: `/opt/am/config` (default)

4. **Configuration Store**:
   - Store Type: `External Directory Server`
   - Server Name: `ds1-container`
   - Port: `1636`
   - Root Suffix: `ou=am-config,dc=example,dc=com`
   - Login ID: `cn=Directory Manager`
   - Password: `password`
   - SSL/TLS: `Enabled` (check box)

5. **User Data Store**:
   - Same configuration as config store but:
   - Root Suffix: `ou=identities,dc=example,dc=com`
   - Login ID: `uid=amldapuser,ou=identities,dc=example,dc=com`
   - Password: `password`

6. **Site Configuration**:
   - Enable Site Configuration: `Yes`
   - Site Name: `ping-site`
   - Load Balancer URL: `http://localhost:8100/am` (or future LB URL)

7. **Default Policy Agent**:
   - Agent Password: `password123`
   - Confirm Password: `password123`

8. **Administrator Account** (amadmin):
   - Password: `password`
   - Confirm Password: `password`

9. **Click "Create Configuration"**

10. Wait for configuration completion (may take 2-3 minutes)

11. **Proceed to Login**: Click link and login as `amadmin/password`

### Step 4.4: Configure CTS in AM1

After logging into AM console:

1. Navigate to: **Configure > Global Services > Core Token Service**
2. Click **Secondary Configuration Instance** tab
3. **Add** new CTS store configuration:
   - Store Type: `External Directory Server`
   - Server Name: `ds1-container`
   - Port: `1636`
   - Root Suffix: `ou=tokens,dc=example,dc=com`
   - Login ID: `cn=Directory Manager`
   - Password: `password`
   - SSL/TLS: `Enabled`
   - Max Connections: `10`
4. **Save Changes**

### Step 4.5: Deploy AM2

```bash
cd /home/thepackle/repos/ping/AM2

# Copy AM1 docker-compose and modify
cp ../AM1/docker-compose.yml .

sed -i 's/am1-container/am2-container/g' docker-compose.yml
sed -i 's/172.20.0.31/172.20.0.32/g' docker-compose.yml
sed -i 's/"8100:8080"/"8101:8080"/g' docker-compose.yml

# Start AM2
docker compose up -d

# Access AM2 configurator
echo "Access AM2 configuration wizard at: http://localhost:8101/am"
```

**AM2 Configuration Wizard**:

1. **Accept License Agreement**
2. **Select Configuration Type**: Choose "Add to Existing Deployment"
3. **General Configuration**:
   - Server URL: `http://localhost:8101/am`
   - Cookie Domain: `.example.com` (MUST match AM1)
4. **Configuration Store** (point to same DS, which has replicated config):
   - Server Name: `ds2-container` (or ds1-container)
   - Port: `1636`
   - Root Suffix: `ou=am-config,dc=example,dc=com`
   - Login ID: `cn=Directory Manager`
   - Password: `password`
   - SSL/TLS: `Enabled`
5. **Site Configuration**:
   - Select Existing Site: `ping-site`
   - Load Balancer URL: `http://localhost:8100/am` (same as AM1)
6. **Administrator Authentication**:
   - amadmin Password: `password` (same as AM1)
7. **Click "Add to Deployment"**
8. Wait for completion and proceed to login

### Step 4.6: Verify AM Clustering

```bash
# Login to AM1 console: http://localhost:8100/am/console
# Navigate to: Deployment > Servers
# Should see both AM1 and AM2 listed

# Navigate to: Deployment > Sites > ping-site
# Should show both servers assigned to site

# Test session replication:
# 1. Login to AM1 user interface (not console)
# 2. Note session cookie
# 3. Access AM2 with same session cookie
# 4. Should still be logged in (session replicated via CTS)
```

---

## Phase 5: Integration & Validation

### Step 5.1: Create Test Users in DS

```bash
# Create organizational units
docker exec ds1-container /opt/out/instance/bin/ldapmodify \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --useSSL --trustAll << EOF
dn: ou=people,dc=example,dc=com
changetype: add
objectClass: organizationalUnit
objectClass: top
ou: people

dn: ou=groups,dc=example,dc=com
changetype: add
objectClass: organizationalUnit
objectClass: top
ou: groups
EOF

# Create test users
docker exec ds1-container /opt/out/instance/bin/ldapmodify \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --useSSL --trustAll << EOF
dn: uid=jdoe,ou=people,dc=example,dc=com
changetype: add
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: jdoe
cn: John Doe
sn: Doe
givenName: John
mail: jdoe@example.com
telephoneNumber: +1-555-1234
userPassword: Password123

dn: uid=jsmith,ou=people,dc=example,dc=com
changetype: add
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: jsmith
cn: Jane Smith
sn: Smith
givenName: Jane
mail: jsmith@example.com
telephoneNumber: +1-555-5678
userPassword: Password456
EOF
```

### Step 5.2: Configure AM Authentication to DS

**Note**: If you configured the user data store correctly during AM setup, this should already be working.

Verify/Configure:
1. Login to AM1 console: http://localhost:8100/am/console as amadmin
2. Navigate to: **Realms** (top realm)
3. Click **Authentication > Modules**
4. Should see **DataStore** module already configured
5. Click **DataStore** to view settings
6. Verify LDAP Server settings point to DS1/DS2

### Step 5.3: Test End-to-End Authentication

```bash
# Access AM user login page
echo "Open browser to: http://localhost:8100/am/XUI/?realm=/"

# Login as test user:
# Username: jdoe
# Password: Password123

# Should successfully authenticate and see user dashboard

# Verify in AM console:
# Navigate to: Sessions
# Should see active session for jdoe
```

### Step 5.4: Test IDM to DS Data Flow

```bash
# Create a managed user via IDM API
curl -k -X POST "https://localhost:8453/openidm/managed/user?_action=create" \
  -H "Content-Type: application/json" \
  -H "X-OpenIDM-Username: admin" \
  -H "X-OpenIDM-Password: admin" \
  -d '{
    "userName": "bwilliams",
    "givenName": "Bob",
    "sn": "Williams",
    "mail": "bwilliams@example.com",
    "telephoneNumber": "+1-555-9999",
    "password": "Password789"
  }'

# Verify user created in DS
docker exec ds1-container /opt/out/instance/bin/ldapsearch \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --baseDN "dc=example,dc=com" \
  --searchScope sub "(uid=bwilliams)" \
  --useSSL --trustAll

# Should return the user entry

# Test authentication in AM as bwilliams
# Open: http://localhost:8100/am/XUI/?realm=/
# Login: bwilliams / Password789
# Should successfully authenticate
```

### Step 5.5: Verify High Availability

**Test DS Failover**:
```bash
# Stop DS1
docker stop ds1-container

# Verify DS2 is still serving
docker exec ds2-container /opt/out/instance/bin/ldapsearch \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --baseDN "dc=example,dc=com" \
  --searchScope base "(objectClass=*)" \
  --useSSL --trustAll

# Verify AM authentication still works (via DS2)
# Login to AM: http://localhost:8100/am/XUI/?realm=/
# Should still be able to authenticate

# Restart DS1
docker start ds1-container

# Verify replication catches up
docker exec ds1-container /opt/out/instance/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname ds1-container --port 4444 \
  --trustAll --no-prompt
```

**Test IDM Failover**:
```bash
# Stop IDM1
docker stop idm1-container

# Verify IDM2 accessible
curl -k -u admin:admin https://localhost:8454/openidm/info/ping

# Restart IDM1
docker start idm1-container

# Verify cluster reformed
curl -k -u admin:admin https://localhost:8453/openidm/cluster
```

**Test AM Failover**:
```bash
# Login to AM1 and note session

# Stop AM1
docker stop am1-container

# Access AM2 with same session (requires load balancer or manual cookie transfer in real scenario)
# In this demo, create new session on AM2: http://localhost:8101/am/XUI/?realm=/
# Login should work, proving AM2 operational

# Restart AM1
docker start am1-container
```

---

## Phase 6: Data Migration Setup

### Step 6.1: Configure SQL Server Connector (If applicable)

See Step 3.8 above for detailed SQL connector configuration.

**Summary**:
1. Add JDBC driver JAR to IDM connectors directory
2. Create provisioner.openicf-mssql1.json with connection details
3. Restart IDM
4. Test connector: `curl -k -u admin:admin "https://localhost:8453/openidm/system/mssql1?_action=test"`

### Step 6.2: Configure Active Directory Connector (If applicable)

```bash
# Create AD connector configuration
cat > /home/thepackle/repos/ping/IDM1/conf/provisioner.openicf-ad.json << 'EOF'
{
  "name": "ad",
  "connectorRef": {
    "connectorHostRef": "#LOCAL",
    "connectorName": "org.identityconnectors.ldap.LdapConnector",
    "bundleName": "org.forgerock.openicf.connectors.ldap-connector",
    "bundleVersion": "[1.5.0.0,2.0.0.0)"
  },
  "configurationProperties": {
    "host": "YOUR_AD_SERVER",
    "port": 636,
    "ssl": true,
    "principal": "CN=IDM Service,OU=Service Accounts,DC=corp,DC=example,DC=com",
    "credentials": "YOUR_AD_PASSWORD",
    "baseContexts": [
      "OU=Users,DC=corp,DC=example,DC=com"
    ],
    "baseContextsToSynchronize": [
      "OU=Users,DC=corp,DC=example,DC=com"
    ],
    "accountSearchFilter": "(&(objectClass=user)(objectCategory=person))",
    "accountSynchronizationFilter": "(&(objectClass=user)(objectCategory=person))",
    "readSchema": true,
    "usePagedResultControl": true,
    "blockSize": 100,
    "useBlocks": true
  },
  "poolConfigOption": {
    "maxObjects": 10,
    "maxIdle": 10,
    "maxWait": 150000,
    "minEvictableIdleTimeMillis": 120000,
    "minIdle": 1
  }
}
EOF

# Copy to IDM2
cp /home/thepackle/repos/ping/IDM1/conf/provisioner.openicf-ad.json \
   /home/thepackle/repos/ping/IDM2/conf/

# Restart IDM
docker restart idm1-container idm2-container

# Test AD connector
curl -k -u admin:admin "https://localhost:8453/openidm/system/ad?_action=test"
```

### Step 6.3: Create Synchronization Mappings

This is complex and depends on your data schema. General approach:

```bash
# Create mapping from AD to managed users
# Edit: IDM1/conf/sync.json

# Basic mapping structure:
{
  "mappings": [
    {
      "name": "systemAdAccount_managedUser",
      "source": "system/ad/account",
      "target": "managed/user",
      "properties": [
        {"source": "sAMAccountName", "target": "userName"},
        {"source": "givenName", "target": "givenName"},
        {"source": "sn", "target": "sn"},
        {"source": "mail", "target": "mail"}
      ],
      "policies": [
        {"situation": "ABSENT", "action": "CREATE"},
        {"situation": "FOUND", "action": "UPDATE"}
      ]
    }
  ]
}

# After creating mappings:
# - Test via IDM admin console: Configure > Mappings
# - Click "Reconcile Now" to perform initial sync
# - Monitor logs for errors
```

---

## Post-Installation

### Step 1: Change Default Passwords

```bash
# Change DS Directory Manager password
docker exec ds1-container /opt/out/instance/bin/dsconfig set-root-dn-prop \
  --user-name "Directory Manager" \
  --set password:NewSecurePassword123 \
  --hostname localhost --port 4444 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --trustAll --no-prompt

# Change IDM admin password via API
curl -k -X PATCH "https://localhost:8453/openidm/managed/user/admin" \
  -H "Content-Type: application/json" \
  -H "X-OpenIDM-Username: admin" \
  -H "X-OpenIDM-Password: admin" \
  -d '{
    "password": "NewSecurePassword456"
  }'

# Change AM amadmin password via console:
# - Login to http://localhost:8100/am/console
# - Navigate to: Realms > Top Level Realm > Subjects
# - Click "amadmin"
# - Change password
```

### Step 2: Configure Backup Scripts

```bash
# Create backup script
cat > /home/thepackle/repos/ping/shared/scripts/backup-ds.sh << 'EOF'
#!/bin/bash
# PingDS Backup Script

BACKUP_DIR="/home/thepackle/repos/ping/shared/backups"
DATE=$(date +%Y%m%d-%H%M%S)

# Backup DS1
docker exec ds1-container /opt/out/instance/bin/backup \
  --backupDirectory /opt/out/instance/bak \
  --backendID userRoot

docker cp ds1-container:/opt/out/instance/bak $BACKUP_DIR/ds1-$DATE

echo "Backup completed: $BACKUP_DIR/ds1-$DATE"
EOF

chmod +x /home/thepackle/repos/ping/shared/scripts/backup-ds.sh

# Test backup
./shared/scripts/backup-ds.sh
```

### Step 3: Set Up Monitoring

```bash
# Create monitoring script
cat > /home/thepackle/repos/ping/shared/scripts/health-check.sh << 'EOF'
#!/bin/bash
# Health Check Script

echo "=== Ping Identity Platform Health Check ==="
echo "Date: $(date)"
echo

echo "=== Docker Containers ==="
docker ps --filter "name=ds" --filter "name=idm" --filter "name=am" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

echo "=== PingDS Replication Status ==="
docker exec ds1-container /opt/out/instance/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname localhost --port 4444 \
  --trustAll --no-prompt --script-friendly 2>/dev/null || echo "Error checking replication"
echo

echo "=== PingIDM Health ==="
curl -s -k -u admin:admin https://localhost:8453/openidm/info/ping 2>/dev/null || echo "IDM1 not responding"
curl -s -k -u admin:admin https://localhost:8454/openidm/info/ping 2>/dev/null || echo "IDM2 not responding"
echo

echo "=== PingAM Health ==="
curl -s http://localhost:8100/am/isAlive.jsp 2>/dev/null | grep -q "true" && echo "AM1: OK" || echo "AM1: NOT OK"
curl -s http://localhost:8101/am/isAlive.jsp 2>/dev/null | grep -q "true" && echo "AM2: OK" || echo "AM2: NOT OK"
echo

echo "=== Health Check Complete ==="
EOF

chmod +x /home/thepackle/repos/ping/shared/scripts/health-check.sh

# Run health check
./shared/scripts/health-check.sh
```

### Step 4: Document Configuration

```bash
# Update WORKFLOW.md with actual configuration used
# Document any deviations from this guide
# Record all IP addresses, ports, passwords (in secure location)
```

---

## Troubleshooting

### Common Issues

**1. Container Won't Start**
```bash
# Check logs
docker logs <container-name>

# Common issues:
# - Port already in use: Change port mapping
# - Volume mount error: Check directory permissions
# - Out of memory: Increase Docker resources
```

**2. DS Replication Not Working**
```bash
# Check network connectivity
docker exec ds1-container ping ds2-container

# Check replication status
docker exec ds1-container /opt/out/instance/bin/dsreplication status \
  --adminUID admin --adminPassword password \
  --hostname localhost --port 4444 \
  --trustAll --no-prompt

# Check DS logs
docker exec ds1-container tail -f /opt/out/instance/logs/errors

# Reinitialize replication if needed
docker exec ds1-container /opt/out/instance/bin/dsreplication initialize \
  --baseDN "dc=example,dc=com" \
  --hostSource ds1-container --portSource 4444 \
  --hostDestination ds2-container --portDestination 4444 \
  --adminUID admin --adminPassword password \
  --trustAll --no-prompt
```

**3. IDM Can't Connect to DS**
```bash
# Verify DS is accessible from IDM container
docker exec idm1-container ping ds1-container

# Check DS port
docker exec idm1-container telnet ds1-container 1636

# Verify DS credentials in repo.ds.json
# Check IDM logs
docker logs idm1-container | grep -i "repository"
```

**4. AM Authentication Fails**
```bash
# Verify user exists in DS
docker exec ds1-container /opt/out/instance/bin/ldapsearch \
  --hostname localhost --port 1636 \
  --bindDN "cn=Directory Manager" --bindPassword password \
  --baseDN "dc=example,dc=com" \
  --searchScope sub "(uid=testuser)" \
  --useSSL --trustAll

# Check AM authentication module configuration
# Login to AM console and verify LDAP settings

# Check AM logs
docker logs am1-container | grep -i "authentication"
```

### Getting Help

- Official Documentation: https://docs.pingidentity.com
- Community Forum: https://support.pingidentity.com/s/
- Review [CONSIDERATIONS.md](CONSIDERATIONS.md) for additional troubleshooting

---

## Next Steps

After completing installation:

1. **Configure Applications**: Integrate your applications with PingAM for SSO
2. **Set Up Workflows**: Create IDM workflows for user onboarding/offboarding
3. **Production Planning**: Review [CONSIDERATIONS.md](CONSIDERATIONS.md) for production guidance
4. **Testing**: Perform thorough testing of all components
5. **Documentation**: Document your specific configuration and customizations

---

**Congratulations!** You have successfully deployed the Ping Identity platform.

For ongoing operations and maintenance, refer to:
- [WORKFLOW.md](WORKFLOW.md) - Track operational tasks
- [checklist.md](checklist.md) - Post-deployment checklist
- [CONSIDERATIONS.md](CONSIDERATIONS.md) - Best practices and operational guidance

---

*End of Installation Guide*
