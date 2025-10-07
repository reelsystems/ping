# ForgeRock Restore Script
# Restores ForgeRock services from backup

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile,

    [switch]$StopServices = $true,
    [switch]$SkipVolumes = $false,
    [switch]$SkipConfig = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ForgeRock Identity Platform - Restore" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify backup file exists
if (!(Test-Path $BackupFile)) {
    Write-Host "[✗] Error: Backup file not found: $BackupFile" -ForegroundColor Red
    exit 1
}

Write-Host "[✓] Backup file found: $BackupFile" -ForegroundColor Green
$backupSize = (Get-Item $BackupFile).Length / 1MB
Write-Host "    Size: $([math]::Round($backupSize, 2)) MB" -ForegroundColor Gray
Write-Host ""

# Confirm restore operation
Write-Host "[!] WARNING: This will overwrite existing configuration and data!" -ForegroundColor Red
$confirmation = Read-Host "Are you sure you want to continue? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "[!] Restore cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Stop services
if ($StopServices) {
    Write-Host "[1/5] Stopping ForgeRock services..." -ForegroundColor Yellow
    try {
        docker-compose down 2>&1 | Out-Null
        Write-Host "  [✓] Services stopped" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Warning: Error stopping services: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[1/5] Skipping service shutdown (as requested)" -ForegroundColor Gray
}

# Extract backup
Write-Host "`n[2/5] Extracting backup..." -ForegroundColor Yellow
$extractPath = "$env:TEMP\forgerock-restore-$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    Expand-Archive -Path $BackupFile -DestinationPath $extractPath -Force
    Write-Host "  [✓] Backup extracted to: $extractPath" -ForegroundColor Green
} catch {
    Write-Host "  [✗] Failed to extract backup: $_" -ForegroundColor Red
    exit 1
}

# Verify backup manifest
$manifestPath = "$extractPath\manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    Write-Host "  [✓] Backup manifest found" -ForegroundColor Green
    Write-Host "    Timestamp: $($manifest.timestamp)" -ForegroundColor Gray
    Write-Host "    Services: $($manifest.services_backed_up.Count)" -ForegroundColor Gray
} else {
    Write-Host "  [!] Warning: No manifest found in backup" -ForegroundColor Yellow
}

# Restore configuration files
if (!$SkipConfig) {
    Write-Host "`n[3/5] Restoring configuration files..." -ForegroundColor Yellow

    try {
        # Backup current config (just in case)
        if (Test-Path ".\config") {
            $configBackup = ".\config-backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item -Path ".\config" -Destination $configBackup -Recurse
            Write-Host "  [✓] Current config backed up to: $configBackup" -ForegroundColor Green
        }

        # Restore config
        if (Test-Path "$extractPath\config") {
            Copy-Item -Path "$extractPath\config" -Destination ".\config" -Recurse -Force
            Write-Host "  [✓] Configuration files restored" -ForegroundColor Green
        }

        # Restore docker-compose.yml
        if (Test-Path "$extractPath\docker-compose.yml") {
            Copy-Item -Path "$extractPath\docker-compose.yml" -Destination ".\" -Force
            Write-Host "  [✓] docker-compose.yml restored" -ForegroundColor Green
        }

        # Restore .env (with caution)
        if (Test-Path "$extractPath\.env") {
            if (Test-Path ".\.env") {
                Copy-Item -Path ".\.env" -Destination ".\.env.current-backup"
                Write-Host "  [✓] Current .env backed up" -ForegroundColor Green
            }
            Copy-Item -Path "$extractPath\.env" -Destination ".\.env" -Force
            Write-Host "  [✓] .env restored" -ForegroundColor Green
            Write-Host "    [!] Review .env for password changes!" -ForegroundColor Yellow
        }

        # Restore certificates
        if (Test-Path "$extractPath\certs") {
            Copy-Item -Path "$extractPath\certs" -Destination ".\certs" -Recurse -Force
            Write-Host "  [✓] Certificates restored" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [✗] Configuration restore failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`n[3/5] Skipping configuration restore (as requested)" -ForegroundColor Gray
}

# Restore data volumes
if (!$SkipVolumes) {
    Write-Host "`n[4/5] Restoring container data volumes..." -ForegroundColor Yellow

    # Start containers briefly to create volumes
    Write-Host "  Starting containers to initialize volumes..." -ForegroundColor Gray
    docker-compose up -d --no-start 2>&1 | Out-Null

    $services = @("pingds", "pingam", "pingidm", "pinggateway")
    $timestamp = if ($manifest) { $manifest.timestamp } else { "*" }

    foreach ($service in $services) {
        $containerName = "$service.devnetwork.dev"
        $tarPattern = "$service-data-$timestamp.tar.gz"
        $tarFile = Get-ChildItem -Path $extractPath -Filter $tarPattern | Select-Object -First 1

        if ($tarFile) {
            Write-Host "  Restoring $service data..." -ForegroundColor Gray

            try {
                # Restore using busybox container
                docker run --rm `
                    --volumes-from $containerName `
                    -v "${extractPath}:/backup" `
                    busybox `
                    tar xzf "/backup/$($tarFile.Name)" -C / 2>&1 | Out-Null

                Write-Host "  [✓] $service data restored" -ForegroundColor Green
            } catch {
                Write-Host "  [✗] $service restore failed: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  [!] No backup found for $service" -ForegroundColor Yellow
        }
    }

    # Restore LDIF data
    $ldifFile = Get-ChildItem -Path $extractPath -Filter "userRoot-*.ldif" | Select-Object -First 1
    if ($ldifFile) {
        Write-Host "`n  Restoring directory data (LDIF)..." -ForegroundColor Gray

        # Start PingDS temporarily
        docker-compose up -d pingds 2>&1 | Out-Null
        Write-Host "  Waiting for PingDS to start..." -ForegroundColor Gray
        Start-Sleep -Seconds 60

        try {
            # Copy LDIF to container
            docker cp $ldifFile.FullName "pingds.devnetwork.dev:/tmp/restore.ldif"

            # Import LDIF
            docker exec pingds.devnetwork.dev /opt/opendj/bin/import-ldif `
                --hostname localhost `
                --port 4444 `
                --bindDN "cn=Directory Manager" `
                --bindPassword "password" `
                --backendID userRoot `
                --ldifFile /tmp/restore.ldif `
                --replaceExisting `
                --trustAll 2>&1 | Out-Null

            Write-Host "  [✓] Directory data imported" -ForegroundColor Green

            # Cleanup
            docker exec pingds.devnetwork.dev rm /tmp/restore.ldif
        } catch {
            Write-Host "  [✗] LDIF import failed: $_" -ForegroundColor Red
        }

        # Stop PingDS
        docker-compose stop pingds 2>&1 | Out-Null
    }
} else {
    Write-Host "`n[4/5] Skipping volume restore (as requested)" -ForegroundColor Gray
}

# Start services
Write-Host "`n[5/5] Starting ForgeRock services..." -ForegroundColor Yellow
try {
    docker-compose up -d 2>&1 | Out-Null
    Write-Host "  [✓] Services started" -ForegroundColor Green
    Write-Host "  [!] Services may take 10-15 minutes to fully initialize" -ForegroundColor Yellow
} catch {
    Write-Host "  [✗] Failed to start services: $_" -ForegroundColor Red
}

# Cleanup extraction directory
Write-Host "`nCleaning up temporary files..." -ForegroundColor Yellow
try {
    Remove-Item -Path $extractPath -Recurse -Force
    Write-Host "  [✓] Temporary files removed" -ForegroundColor Green
} catch {
    Write-Host "  [!] Warning: Could not remove temp directory: $extractPath" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Restore Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Wait for services to fully start (10-15 minutes)" -ForegroundColor White
Write-Host "2. Check service health: docker-compose ps" -ForegroundColor White
Write-Host "3. Review logs: docker-compose logs -f" -ForegroundColor White
Write-Host "4. Verify .env passwords are correct" -ForegroundColor White
Write-Host "5. Test authentication and access" -ForegroundColor White
Write-Host ""
