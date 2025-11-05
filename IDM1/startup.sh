#!/bin/bash
# PingIDM Startup Script for IDM1
# This script configures and starts PingIDM

set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting PingIDM configuration..."

# Install curl if not present (needed for healthcheck)
if ! command -v curl &> /dev/null; then
    log "Installing curl..."
    apt-get update -qq && apt-get install -y -qq curl
fi

# Configure boot.properties if not already configured
BOOT_PROPS="/opt/openidm/conf/boot.properties"
if [ ! -f "${BOOT_PROPS}.original" ]; then
    log "Backing up original boot.properties..."
    cp "$BOOT_PROPS" "${BOOT_PROPS}.original"
fi

log "Configuring boot.properties..."
cat > "$BOOT_PROPS" << EOF
# Boot Properties for ${INSTANCE_ID}
# Generated: $(date)

openidm.host=${OPENIDM_HOST}
openidm.port.http=8080
openidm.port.https=8443
openidm.port.mutualauth=8444

# Keystore configuration
openidm.keystore.type=JCEKS
openidm.truststore.type=JKS
openidm.keystore.provider=SunJCE
openidm.truststore.provider=SUN
openidm.keystore.location=security/keystore.jceks
openidm.truststore.location=security/truststore
openidm.keystore.password=changeit
openidm.truststore.password=changeit

# Cluster configuration
openidm.cluster.enabled=${CLUSTER_ENABLED}
openidm.instance.type=clustered-first
EOF

# Configure cluster.json if clustering is enabled
if [ "${CLUSTER_ENABLED}" = "true" ]; then
    log "Configuring cluster.json..."
    cat > /opt/openidm/conf/cluster.json << EOF
{
  "instanceId": "${INSTANCE_ID}",
  "enabled": ${CLUSTER_ENABLED}
}
EOF
fi

# Configure repository connection (repo.ds.json)
log "Configuring DS repository connection..."
cat > /opt/openidm/conf/repo.ds.json << EOF
{
  "dbType": "DS",
  "useDataSource": "default",
  "connectionTimeout": 30000,
  "ldapConnectionFactories": [
    {
      "primaryLdapServers": [
        {
          "hostname": "${REPO_PRIMARY_HOST}",
          "port": ${REPO_PRIMARY_PORT}
        }
      ],
      "secondaryLdapServers": [
        {
          "hostname": "${REPO_SECONDARY_HOST}",
          "port": ${REPO_SECONDARY_PORT}
        }
      ]
    }
  ],
  "security": {
    "trustManager": "jvm"
  },
  "authentication": {
    "simple": {
      "bindDn": "${REPO_BIND_DN}",
      "bindPassword": "${REPO_BIND_PASSWORD}"
    }
  }
}
EOF

log "IDM configuration complete. Starting OpenIDM..."

# Start OpenIDM
exec /opt/openidm/startup.sh
