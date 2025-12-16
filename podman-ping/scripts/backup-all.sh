#!/bin/bash
# Backup script for Ping Identity Platform
# Backs up all Podman volumes to a timestamped directory

set -e

BACKUP_BASE_DIR="${BACKUP_DIR:-/backup/ping}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$TIMESTAMP"
COMPOSE_DIR="./compose"

echo "=========================================="
echo "Ping Identity Platform Backup"
echo "=========================================="
echo ""
echo "Backup directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# List of volumes to backup
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

echo "Step 1: Stopping services (optional, comment out for online backup)..."
# Uncomment the following line for consistent backup (requires downtime)
# cd "$COMPOSE_DIR" && podman-compose down && cd ..

echo ""
echo "Step 2: Backing up volumes..."
for vol in "${VOLUMES[@]}"; do
    echo "  - Backing up volume: $vol"
    if podman volume exists "$vol" 2>/dev/null; then
        podman run --rm \
            -v "$vol":/data:ro \
            -v "$BACKUP_DIR":/backup \
            alpine tar czf "/backup/${vol}.tar.gz" -C / data
        echo "    ✓ Backup complete: ${vol}.tar.gz"
    else
        echo "    ⚠ Volume not found, skipping: $vol"
    fi
done

echo ""
echo "Step 3: Backing up configurations..."
mkdir -p "$BACKUP_DIR/configs"
if [ -d "./configs" ]; then
    cp -r ./configs/* "$BACKUP_DIR/configs/"
    echo "  ✓ Configs backed up"
else
    echo "  ⚠ No configs directory found"
fi

echo ""
echo "Step 4: Backing up compose files..."
mkdir -p "$BACKUP_DIR/compose"
if [ -d "$COMPOSE_DIR" ]; then
    cp -r "$COMPOSE_DIR"/* "$BACKUP_DIR/compose/"
    echo "  ✓ Compose files backed up"
else
    echo "  ⚠ No compose directory found"
fi

echo ""
echo "Step 5: Backing up Containerfiles..."
mkdir -p "$BACKUP_DIR/containerfiles"
for component in am ds ds-proxy idm ig admin-ui login-ui; do
    if [ -f "./${component}/Containerfile" ]; then
        mkdir -p "$BACKUP_DIR/containerfiles/$component"
        cp "./${component}/Containerfile" "$BACKUP_DIR/containerfiles/$component/"
    fi
done
echo "  ✓ Containerfiles backed up"

echo ""
echo "Step 6: Creating backup manifest..."
cat > "$BACKUP_DIR/MANIFEST.txt" <<EOF
Ping Identity Platform Backup
==============================
Backup Date: $(date)
Backup Directory: $BACKUP_DIR
Hostname: $(hostname)
Podman Version: $(podman --version)

Volumes Backed Up:
EOF

for vol in "${VOLUMES[@]}"; do
    if [ -f "$BACKUP_DIR/${vol}.tar.gz" ]; then
        SIZE=$(du -h "$BACKUP_DIR/${vol}.tar.gz" | cut -f1)
        echo "  - $vol ($SIZE)" >> "$BACKUP_DIR/MANIFEST.txt"
    fi
done

cat >> "$BACKUP_DIR/MANIFEST.txt" <<EOF

Container Status at Backup Time:
EOF
podman ps -a --format "  - {{.Names}}: {{.Status}}" >> "$BACKUP_DIR/MANIFEST.txt"

echo "  ✓ Manifest created"

echo ""
echo "Step 7: Calculating checksums..."
cd "$BACKUP_DIR"
find . -type f -name "*.tar.gz" -exec sha256sum {} \; > checksums.txt
cd - > /dev/null
echo "  ✓ Checksums calculated"

echo ""
echo "Step 8: Restarting services (if stopped)..."
# Uncomment if you stopped services earlier
# cd "$COMPOSE_DIR" && podman-compose up -d && cd ..

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo ""
echo "Backup location: $BACKUP_DIR"
echo "Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "To restore this backup, run:"
echo "  ./scripts/restore-backup.sh $TIMESTAMP"
echo ""
echo "To create a compressed archive for offsite storage:"
echo "  tar czf ping-backup-$TIMESTAMP.tar.gz -C $BACKUP_BASE_DIR $TIMESTAMP"
echo ""

# Cleanup old backups (keep last 7 days)
echo "Step 9: Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
echo "  ✓ Old backups cleaned up"

echo ""
echo "Backup completed successfully!"
