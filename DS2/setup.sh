#!/bin/bash
# PingDS Setup Script for DS1
# This script initializes PingDS on first run and starts the server

set -e

INITIALIZED_FLAG="/opt/opendj/db/.initialized"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Check if already initialized
if [ -f "$INITIALIZED_FLAG" ]; then
    log "DS1 already initialized. Starting server..."
    /opt/opendj/bin/start-ds --nodetach
    exit 0
fi

log "First time setup detected. Initializing DS1..."

# Run setup
log "Running setup command..."
/opt/opendj/setup \
    --serverId "${SERVER_ID}" \
    --deploymentId "${DEPLOYMENT_ID}" \
    --deploymentIdPassword "${DEPLOYMENT_ID_PASSWORD}" \
    --rootUserDn "${ROOT_USER_DN}" \
    --rootUserPassword "${ROOT_USER_PASSWORD}" \
    --monitorUserPassword "${MONITOR_USER_PASSWORD}" \
    --hostname "${HOSTNAME}" \
    --ldapPort ${LDAP_PORT} \
    --ldapsPort ${LDAPS_PORT} \
    --httpsPort ${HTTPS_PORT} \
    --adminConnectorPort ${ADMIN_PORT} \
    --replicationPort ${REPLICATION_PORT} \
    --profile "${SETUP_PROFILE}" \
    --set "${SETUP_PROFILE}/baseDn:${BASE_DN}" \
    --acceptLicense \
    --no-prompt

# Create initialized flag
touch "$INITIALIZED_FLAG"
log "DS1 setup complete. Initialized flag created."

# Start DS in foreground
log "Starting DS1 server..."
/opt/opendj/bin/start-ds --nodetach
