# Production Certificate Management for Ping Identity Platform

## Overview

This guide covers how to use **production certificates** from your Certificate Authority (CA) instead of self-signed certificates. It includes both Podman volume and bind mount approaches.

## Certificate Requirements

### What You Need

For a production deployment, you'll need the following certificate files:

#### 1. **For Directory Server (DS, DS-Proxy)**
- `ds-cert.pem` - Server certificate in PEM format
- `ds-key.pem` - Private key in PEM format
- `ca-chain.pem` - CA certificate chain in PEM format

#### 2. **For Java Services (AM, IDM, IG)**
- `keystore.jks` - Java KeyStore with server certificate and private key
- `truststore.jks` - Java TrustStore with CA certificates
- OR `keystore.p12` - PKCS12 format (can be converted to JKS)

#### 3. **Certificate Files Summary**
```
production-certs/
├── ds/
│   ├── server-cert.pem          # DS server certificate
│   ├── server-key.pem           # DS private key
│   └── ca-chain.pem             # CA chain
├── java/
│   ├── keystore.jks             # Java keystore (AM, IDM, IG)
│   ├── truststore.jks           # Java truststore
│   └── keystore-password.txt    # Password file (secure this!)
└── README.txt                   # Documentation of what's what
```

## Method 1: Using Podman Named Volume (Current Default)

This is the current configuration in `podman-compose.yml`.

### Step 1: Create the Volume

```bash
podman volume create shared-certs
```

### Step 2: Copy Your Certificates to the Volume

```bash
# Option A: Copy from a directory
podman run --rm \
  -v /path/to/your/production-certs:/source:ro \
  -v shared-certs:/dest \
  alpine sh -c 'cp -r /source/* /dest/ && chmod -R 755 /dest && chown -R 1000:0 /dest'

# Option B: Copy individual files
podman run --rm \
  -v shared-certs:/certs \
  alpine sh -c 'mkdir -p /certs/ds /certs/java'

# DS certificates
podman cp /path/to/ds-server-cert.pem $(podman create --rm -v shared-certs:/certs alpine):/certs/ds/server-cert.pem
podman cp /path/to/ds-server-key.pem $(podman create --rm -v shared-certs:/certs alpine):/certs/ds/server-key.pem
podman cp /path/to/ca-chain.pem $(podman create --rm -v shared-certs:/certs alpine):/certs/ds/ca-chain.pem

# Java keystores
podman cp /path/to/keystore.jks $(podman create --rm -v shared-certs:/certs alpine):/certs/java/keystore.jks
podman cp /path/to/truststore.jks $(podman create --rm -v shared-certs:/certs alpine):/certs/java/truststore.jks
```

### Step 3: Verify Files in Volume

```bash
# List files in the volume
podman run --rm -v shared-certs:/certs alpine ls -laR /certs

# Should show:
# /certs/ds/
# - server-cert.pem
# - server-key.pem
# - ca-chain.pem
# /certs/java/
# - keystore.jks
# - truststore.jks
```

### Step 4: Current Configuration (Already in podman-compose.yml)

The compose file already mounts the volume to all services:

```yaml
volumes:
  shared-certs:
    driver: local

services:
  ds-1:
    volumes:
      - shared-certs:/var/run/secrets/keys:ro
```

### Step 5: Configure Services to Use Certificates

You'll need to configure each service to use the production certificates. See [Service-Specific Configuration](#service-specific-configuration) below.

## Method 2: Using Bind Mount (Recommended for Production)

Bind mounts provide better control and make certificate rotation easier.

### Step 1: Create Certificate Directory on Host

```bash
# Create directory (outside the git repo for security)
sudo mkdir -p /opt/ping-certs/{ds,java}
sudo chmod 750 /opt/ping-certs
sudo chown $(id -u):$(id -g) /opt/ping-certs
```

### Step 2: Copy Your Certificates

```bash
# DS certificates
cp /path/to/your/ds-server-cert.pem /opt/ping-certs/ds/server-cert.pem
cp /path/to/your/ds-server-key.pem /opt/ping-certs/ds/server-key.pem
cp /path/to/your/ca-chain.pem /opt/ping-certs/ds/ca-chain.pem

# Java keystores
cp /path/to/your/keystore.jks /opt/ping-certs/java/keystore.jks
cp /path/to/your/truststore.jks /opt/ping-certs/java/truststore.jks

# Set permissions
chmod 644 /opt/ping-certs/ds/*.pem
chmod 600 /opt/ping-certs/ds/*-key.pem
chmod 644 /opt/ping-certs/java/*.jks
```

### Step 3: Configure SELinux (RHEL/CentOS)

```bash
# Set correct SELinux context for container access
sudo semanage fcontext -a -t container_file_t "/opt/ping-certs(/.*)?"
sudo restorecon -Rv /opt/ping-certs

# Verify
ls -lZ /opt/ping-certs
```

### Step 4: Update podman-compose.yml

Modify the compose file to use bind mount instead of named volume:

```yaml
# REMOVE or comment out the named volume
# volumes:
#   shared-certs:
#     driver: local

services:
  ds-1:
    volumes:
      - ds-data-1:/opt/opendj/data
      - /opt/ping-certs:/var/run/secrets/keys:ro,z  # Bind mount with SELinux label
    environment:
      # Point to specific cert files
      PEM_KEYS_DIRECTORY: "/var/run/secrets/keys/ds"
      PEM_TRUSTSTORE_DIRECTORY: "/var/run/secrets/keys/ds"

  ds-2:
    volumes:
      - ds-data-2:/opt/opendj/data
      - /opt/ping-certs:/var/run/secrets/keys:ro,z

  ds-proxy:
    volumes:
      - ds-proxy-data:/opt/opendj/data
      - /opt/ping-certs:/var/run/secrets/keys:ro,z

  am:
    volumes:
      - am-data:/opt/openam/data
      - /opt/ping-certs:/var/run/secrets/keys:ro,z
    environment:
      # Add Java keystore/truststore configuration
      JAVA_OPTS: >-
        -server
        -XX:+UseContainerSupport
        -XX:MaxRAMPercentage=75.0
        -Djavax.net.ssl.keyStore=/var/run/secrets/keys/java/keystore.jks
        -Djavax.net.ssl.keyStorePassword=changeit
        -Djavax.net.ssl.trustStore=/var/run/secrets/keys/java/truststore.jks
        -Djavax.net.ssl.trustStorePassword=changeit

  idm:
    volumes:
      - idm-data:/opt/openidm/data
      - /opt/ping-certs:/var/run/secrets/keys:ro,z
    environment:
      OPENIDM_KEYSTORE_PASSWORD: changeit
      OPENIDM_TRUSTSTORE_PASSWORD: changeit

  ig:
    volumes:
      - ig-data:/var/ig/data
      - /opt/ping-certs:/var/run/secrets/keys:ro,z
```

**Note**: The `:z` suffix tells Podman to relabel the content for sharing across containers (SELinux).

### Step 5: Verify Mount

```bash
# Start services
cd compose
podman-compose up -d

# Verify certificates are accessible in containers
podman exec ping-ds-1 ls -la /var/run/secrets/keys/ds/
podman exec ping-am ls -la /var/run/secrets/keys/java/
```

## Method 3: Hybrid Approach (Separate Mounts per Service)

For maximum security and isolation, mount only the necessary certificates to each service:

```yaml
services:
  ds-1:
    volumes:
      - ds-data-1:/opt/opendj/data
      - /opt/ping-certs/ds:/var/run/secrets/keys/ds:ro,z

  am:
    volumes:
      - am-data:/opt/openam/data
      - /opt/ping-certs/java:/var/run/secrets/keys/java:ro,z

  idm:
    volumes:
      - idm-data:/opt/openidm/data
      - /opt/ping-certs/java:/var/run/secrets/keys/java:ro,z
```

## Service-Specific Configuration

### Directory Server (DS, DS-Proxy)

DS expects PEM format certificates in the locations specified by environment variables.

#### Option A: Environment Variables (Already configured)

The Containerfile already sets:
```dockerfile
ENV PEM_KEYS_DIRECTORY="/var/run/secrets/keys/ds"
ENV PEM_TRUSTSTORE_DIRECTORY="/var/run/secrets/keys/ds"
```

#### Option B: Manual Configuration (if needed)

```bash
# Access DS container
podman exec -it ping-ds-1 bash

# Configure certificate paths
/opt/opendj/bin/dsconfig set-connection-handler-prop \
  --handler-name "LDAPS Connection Handler" \
  --set enabled:true \
  --set ssl-cert-nickname:server-cert \
  --hostname localhost --port 4444 \
  --bindDN "cn=Directory Manager" --bindPassword changeme \
  --trustAll --no-prompt

# Import certificate
/opt/opendj/bin/dsconfig set-key-manager-provider-prop \
  --provider-name "LDAPS Key Manager" \
  --set enabled:true \
  --hostname localhost --port 4444 \
  --bindDN "cn=Directory Manager" --bindPassword changeme \
  --trustAll --no-prompt
```

#### Expected File Structure in Container

```
/var/run/secrets/keys/ds/
├── server-cert.pem    # Certificate
├── server-key.pem     # Private key
└── ca-chain.pem       # CA chain
```

### Access Manager (AM)

AM uses Java KeyStore/TrustStore for SSL/TLS.

#### Configure via Environment Variables

Add to `podman-compose.yml`:

```yaml
am:
  environment:
    CATALINA_OPTS: >-
      -Djavax.net.ssl.keyStore=/var/run/secrets/keys/java/keystore.jks
      -Djavax.net.ssl.keyStorePassword=${KEYSTORE_PASSWORD}
      -Djavax.net.ssl.trustStore=/var/run/secrets/keys/java/truststore.jks
      -Djavax.net.ssl.trustStorePassword=${TRUSTSTORE_PASSWORD}
```

#### Expected File Structure

```
/var/run/secrets/keys/java/
├── keystore.jks       # Contains server cert + private key
└── truststore.jks     # Contains CA certificates
```

### Identity Manager (IDM)

IDM also uses Java keystores.

#### Configure in boot.properties

Create or modify `idm/config/boot.properties`:

```properties
# Keystore configuration
openidm.keystore.type=JCEKS
openidm.keystore.provider=SunJCE
openidm.keystore.location=/var/run/secrets/keys/java/keystore.jks
openidm.keystore.password=OBF:encrypted_password_here

# Truststore configuration
openidm.truststore.type=JKS
openidm.truststore.location=/var/run/secrets/keys/java/truststore.jks
openidm.truststore.password=OBF:encrypted_password_here
```

#### Or via Environment Variables

```yaml
idm:
  environment:
    OPENIDM_KEYSTORE_LOCATION: /var/run/secrets/keys/java/keystore.jks
    OPENIDM_KEYSTORE_PASSWORD: ${KEYSTORE_PASSWORD}
    OPENIDM_TRUSTSTORE_LOCATION: /var/run/secrets/keys/java/truststore.jks
    OPENIDM_TRUSTSTORE_PASSWORD: ${TRUSTSTORE_PASSWORD}
```

### Identity Gateway (IG)

IG configuration for SSL/TLS is typically done via `config.json`.

Create `ig/config/config.json`:

```json
{
  "handler": {
    "type": "Router",
    "name": "router",
    "baseURI": "https://ig.example.com"
  },
  "heap": [
    {
      "name": "ClientHandler",
      "type": "ClientHandler",
      "config": {
        "hostnameVerifier": "ALLOW_ALL",
        "keyManager": {
          "type": "KeyManager",
          "config": {
            "keystore": {
              "type": "KeyStore",
              "config": {
                "url": "file:///var/run/secrets/keys/java/keystore.jks",
                "password": "${KEYSTORE_PASSWORD}",
                "type": "JKS"
              }
            }
          }
        },
        "trustManager": {
          "type": "TrustManager",
          "config": {
            "keystore": {
              "type": "KeyStore",
              "config": {
                "url": "file:///var/run/secrets/keys/java/truststore.jks",
                "password": "${TRUSTSTORE_PASSWORD}",
                "type": "JKS"
              }
            }
          }
        }
      }
    }
  ]
}
```

## Certificate Format Conversion

If your CA provides certificates in different formats, here's how to convert them:

### PEM to JKS (for Java services)

```bash
# 1. Create PKCS12 from PEM
openssl pkcs12 -export \
  -in server-cert.pem \
  -inkey server-key.pem \
  -out keystore.p12 \
  -name server \
  -CAfile ca-chain.pem \
  -caname root \
  -passout pass:changeit

# 2. Convert PKCS12 to JKS
keytool -importkeystore \
  -srckeystore keystore.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass changeit \
  -destkeystore keystore.jks \
  -deststoretype JKS \
  -deststorepass changeit \
  -noprompt

# 3. Import CA chain to truststore
keytool -import \
  -trustcacerts \
  -file ca-chain.pem \
  -alias ca-root \
  -keystore truststore.jks \
  -storepass changeit \
  -noprompt
```

### PFX/P12 to PEM (for DS)

```bash
# Extract certificate
openssl pkcs12 -in certificate.pfx -clcerts -nokeys -out server-cert.pem

# Extract private key
openssl pkcs12 -in certificate.pfx -nocerts -nodes -out server-key.pem

# Extract CA chain
openssl pkcs12 -in certificate.pfx -cacerts -nokeys -out ca-chain.pem
```

### DER to PEM

```bash
# Convert certificate
openssl x509 -inform der -in certificate.der -out certificate.pem

# Convert private key
openssl rsa -inform der -in private-key.der -out private-key.pem
```

## Managing Keystore Passwords Securely

### Option 1: Podman Secrets (Recommended)

```bash
# Create secrets
echo "your-keystore-password" | podman secret create keystore-password -
echo "your-truststore-password" | podman secret create truststore-password -

# Update podman-compose.yml
services:
  am:
    secrets:
      - keystore-password
      - truststore-password
    environment:
      KEYSTORE_PASSWORD_FILE: /run/secrets/keystore-password
      TRUSTSTORE_PASSWORD_FILE: /run/secrets/truststore-password

secrets:
  keystore-password:
    external: true
  truststore-password:
    external: true
```

### Option 2: Environment File (Less Secure)

Create `.env` file in compose directory (add to .gitignore!):

```bash
KEYSTORE_PASSWORD=your-secure-password-here
TRUSTSTORE_PASSWORD=your-secure-password-here
```

Update `podman-compose.yml`:

```yaml
services:
  am:
    env_file:
      - .env
    environment:
      KEYSTORE_PASSWORD: ${KEYSTORE_PASSWORD}
      TRUSTSTORE_PASSWORD: ${TRUSTSTORE_PASSWORD}
```

### Option 3: External Secrets Manager

For enterprise deployments, integrate with HashiCorp Vault or similar:

```bash
# Example: Fetch from Vault
export KEYSTORE_PASSWORD=$(vault kv get -field=password secret/ping/keystore)
export TRUSTSTORE_PASSWORD=$(vault kv get -field=password secret/ping/truststore)

# Use in compose
podman-compose up -d
```

## Certificate Rotation Procedure

### For Bind Mounts (Zero Downtime)

```bash
# 1. Copy new certificates to host directory
cp /path/to/new/server-cert.pem /opt/ping-certs/ds/server-cert.pem.new
cp /path/to/new/server-key.pem /opt/ping-certs/ds/server-key.pem.new
cp /path/to/new/keystore.jks /opt/ping-certs/java/keystore.jks.new

# 2. Verify new certificates
openssl x509 -in /opt/ping-certs/ds/server-cert.pem.new -text -noout
keytool -list -keystore /opt/ping-certs/java/keystore.jks.new -storepass changeit

# 3. Atomic swap (minimize downtime)
mv /opt/ping-certs/ds/server-cert.pem /opt/ping-certs/ds/server-cert.pem.old
mv /opt/ping-certs/ds/server-cert.pem.new /opt/ping-certs/ds/server-cert.pem

mv /opt/ping-certs/ds/server-key.pem /opt/ping-certs/ds/server-key.pem.old
mv /opt/ping-certs/ds/server-key.pem.new /opt/ping-certs/ds/server-key.pem

mv /opt/ping-certs/java/keystore.jks /opt/ping-certs/java/keystore.jks.old
mv /opt/ping-certs/java/keystore.jks.new /opt/ping-certs/java/keystore.jks

# 4. Reload services
cd compose
podman-compose restart ds-1 ds-2 ds-proxy am idm ig

# 5. Verify
./scripts/health-check.sh

# 6. Clean up old certificates after verification
rm /opt/ping-certs/ds/*.old
rm /opt/ping-certs/java/*.old
```

### For Named Volumes

```bash
# 1. Stop services
cd compose
podman-compose down

# 2. Update certificates in volume
podman run --rm \
  -v /path/to/new/certs:/source:ro \
  -v shared-certs:/dest \
  alpine sh -c 'rm -rf /dest/* && cp -r /source/* /dest/'

# 3. Restart services
podman-compose up -d
```

## Verification

### Test SSL/TLS Connections

```bash
# Test DS LDAPS
openssl s_client -connect localhost:1636 -showcerts

# Test AM HTTPS
curl -v https://localhost:8445/am/isAlive.jsp

# Test IDM HTTPS
curl -v -k https://localhost:8446/openidm/info/ping

# Verify certificate details
openssl s_client -connect localhost:1636 -showcerts 2>/dev/null | openssl x509 -text -noout
```

### Check Certificate Expiration

```bash
# DS certificates
podman exec ping-ds-1 openssl x509 -in /var/run/secrets/keys/ds/server-cert.pem -noout -dates

# Java keystore
podman exec ping-am keytool -list -v -keystore /var/run/secrets/keys/java/keystore.jks -storepass changeit | grep -A 2 "Valid from"
```

## Monitoring Certificate Expiration

### Create Monitoring Script

Create `scripts/check-cert-expiration.sh`:

```bash
#!/bin/bash
# Check certificate expiration

WARN_DAYS=30
CRIT_DAYS=7

# Check DS certificate
DS_EXPIRY=$(podman exec ping-ds-1 openssl x509 -in /var/run/secrets/keys/ds/server-cert.pem -noout -enddate | cut -d= -f2)
DS_EXPIRY_EPOCH=$(date -d "$DS_EXPIRY" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( ($DS_EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

if [ $DAYS_UNTIL_EXPIRY -lt $CRIT_DAYS ]; then
    echo "CRITICAL: DS certificate expires in $DAYS_UNTIL_EXPIRY days!"
elif [ $DAYS_UNTIL_EXPIRY -lt $WARN_DAYS ]; then
    echo "WARNING: DS certificate expires in $DAYS_UNTIL_EXPIRY days"
else
    echo "OK: DS certificate expires in $DAYS_UNTIL_EXPIRY days"
fi
```

### Add to Cron

```bash
# Check daily at 8 AM
0 8 * * * /path/to/podman-ping/scripts/check-cert-expiration.sh | mail -s "Ping Certificate Expiry Check" admin@example.com
```

## Troubleshooting

### Certificate Not Found

```bash
# Check if volume/bind mount is accessible
podman exec ping-ds-1 ls -la /var/run/secrets/keys/

# Check SELinux denials
sudo ausearch -m avc -ts recent | grep ping
```

### Permission Denied

```bash
# Fix ownership in volume
podman run --rm -v shared-certs:/certs alpine chown -R 1000:0 /certs

# Or for bind mount
sudo chown -R 1000:0 /opt/ping-certs
```

### Java KeyStore Errors

```bash
# Verify keystore is valid
keytool -list -keystore /opt/ping-certs/java/keystore.jks -storepass changeit

# Check if password is correct
echo "changeit" | keytool -list -keystore /opt/ping-certs/java/keystore.jks
```

### Certificate Chain Issues

```bash
# Verify certificate chain
openssl verify -CAfile /opt/ping-certs/ds/ca-chain.pem /opt/ping-certs/ds/server-cert.pem
```

## Production Checklist

- [ ] Obtained certificates from trusted CA (not self-signed)
- [ ] Verified certificate chain is complete
- [ ] Converted certificates to required formats (PEM for DS, JKS for Java)
- [ ] Stored certificates securely outside git repository
- [ ] Set correct file permissions (644 for certs, 600 for keys)
- [ ] Configured SELinux contexts (RHEL/CentOS)
- [ ] Used Podman secrets or secure vault for passwords
- [ ] Tested all SSL/TLS connections
- [ ] Verified certificate expiration dates (at least 90 days)
- [ ] Set up certificate expiration monitoring
- [ ] Documented certificate rotation procedure
- [ ] Tested certificate rotation in staging environment
- [ ] Configured automated certificate renewal (if using Let's Encrypt/ACME)

## Additional Resources

- [Ping Identity SSL/TLS Configuration](https://docs.pingidentity.com/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Java Keytool Guide](https://docs.oracle.com/en/java/javase/11/tools/keytool.html)
- [Podman Secrets Management](https://docs.podman.io/en/latest/markdown/podman-secret.1.html)

---

**Document Version**: 1.0.0
**Last Updated**: 2024-01-15
**For**: Production deployments only
