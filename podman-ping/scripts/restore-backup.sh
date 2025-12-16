#!/bin/bash
# Restore script for Ping Identity Platform
# Restores all Podman volumes from a backup

set -e

BACKUP_BASE_DIR="${BACKUP_DIR:-/backup/ping}"
COMPOSE_DIR="./compose"

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-timestamp>"
    echo ""
    echo "Available backups:"
    ls -1 "$BACKUP_BASE_DIR" 2>/dev/null | grep -E '^[0-9]{8}-[0-9]{6}$' || echo "  No backups found"
    exit 1
fi

TIMESTAMP="$1"
RESTORE_DIR="$BACKUP_BASE_DIR/$TIMESTAMP"

if [ ! -d "$RESTORE_DIR" ]; then
    echo "Error: Backup directory not found: $RESTORE_DIR"
    exit 1
fi

echo "=========================================="
echo "Ping Identity Platform Restore"
echo "=========================================="
echo ""
echo "Restore from: $RESTORE_DIR"
echo "Backup timestamp: $TIMESTAMP"
echo ""
echo "WARNING: This will OVERWRITE all existing data!"
echo "Make sure you have a current backup before proceeding."
echo ""
read -p "Continue with restore? (yes/NO): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 1
fi

# List of volumes to restore
VOLUMES=(
    "ds-data-1"
    "ds-data-2"
    "ds-proxy-data"
    "am-data"
    "idm-data"
    "ig-data"
    "mysql-data"
    "shared-certs"
)

echo ""
echo "Step 1: Stopping all services..."
cd "$COMPOSE_DIR"
podman-compose down
cd ..
echo "  ✓ Services stopped"

echo ""
echo "Step 2: Verifying backup integrity..."
if [ -f "$RESTORE_DIR/checksums.txt" ]; then
    cd "$RESTORE_DIR"
    if sha256sum -c checksums.txt >/dev/null 2>&1; then
        echo "  ✓ Checksums verified"
    else
        echo "  ✗ Checksum verification failed!"
        read -p "Continue anyway? (yes/NO): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
    cd - > /dev/null
else
    echo "  ⚠ No checksums file found, skipping verification"
fi

echo ""
echo "Step 3: Removing existing volumes..."
for vol in "${VOLUMES[@]}"; do
    if podman volume exists "$vol" 2>/dev/null; then
        echo "  - Removing volume: $vol"
        podman volume rm "$vol" -f
    fi
done
echo "  ✓ Existing volumes removed"

echo ""
echo "Step 4: Creating new volumes..."
for vol in "${VOLUMES[@]}"; do
    echo "  - Creating volume: $vol"
    podman volume create "$vol"
done
echo "  ✓ New volumes created"

echo ""
echo "Step 5: Restoring volume data..."
for vol in "${VOLUMES[@]}"; do
    if [ -f "$RESTORE_DIR/${vol}.tar.gz" ]; then
        echo "  - Restoring volume: $vol"
        podman run --rm \
            -v "$vol":/data \
            -v "$RESTORE_DIR":/backup:ro \
            alpine tar xzf "/backup/${vol}.tar.gz" -C /
        echo "    ✓ Restored: $vol"
    else
        echo "    ⚠ Backup file not found, skipping: ${vol}.tar.gz"
    fi
done

echo ""
echo "Step 6: Restoring configurations (optional)..."
if [ -d "$RESTORE_DIR/configs" ]; then
    read -p "Restore configuration files? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp -r "$RESTORE_DIR/configs/"* ./configs/
        echo "  ✓ Configs restored"
    else
        echo "  - Skipped"
    fi
else
    echo "  ⚠ No configs in backup"
fi

echo ""
echo "Step 7: Restoring compose files (optional)..."
if [ -d "$RESTORE_DIR/compose" ]; then
    read -p "Restore compose files? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp -r "$RESTORE_DIR/compose/"* "$COMPOSE_DIR/"
        echo "  ✓ Compose files restored"
    else
        echo "  - Skipped"
    fi
else
    echo "  ⚠ No compose files in backup"
fi

echo ""
echo "Step 8: Starting services..."
cd "$COMPOSE_DIR"
podman-compose up -d
cd ..
echo "  ✓ Services starting"

echo ""
echo "=========================================="
echo "Restore Complete!"
echo "=========================================="
echo ""
echo "Services are starting. It may take several minutes for"
echo "all services to become healthy."
echo ""
echo "Monitor status with:"
echo "  podman-compose ps"
echo "  podman-compose logs -f"
echo ""
echo "Verify health:"
echo "  ./scripts/health-check.sh"
echo ""

echo "Waiting 30 seconds for services to initialize..."
sleep 30

echo ""
echo "Current status:"
cd "$COMPOSE_DIR"
podman-compose ps
cd ..
