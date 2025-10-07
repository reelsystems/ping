# ForgeRock Backup Script
# Backs up all ForgeRock services data and configuration
# Schedule this script to run daily

param(
    [string]$BackupPath = "$env:USERPROFILE\Documents\PingBackups",
    [int]$RetentionDays = 30,
    [switch]$CompressBackup = $true
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "$BackupPath\backup-$timestamp"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ForgeRock Identity Platform - Backup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host "Backup Location: $backupDir" -ForegroundColor Gray
Write-Host ""

# Create backup directory
try {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Write-Host "[✓] Backup directory created" -ForegroundColor Green
} catch {
    Write-Host "[✗] Failed to create backup directory: $_" -ForegroundColor Red
    exit 1
}

# Backup 1: Configuration files
Write-Host "`n[1/6] Backing up configuration files..." -ForegroundColor Yellow
try {
    Copy-Item -Path ".\config" -Destination "$backupDir\config" -Recurse -ErrorAction Stop
    Copy-Item -Path ".\docker-compose.yml" -Destination "$backupDir\" -ErrorAction Stop
    Copy-Item -Path ".\.env" -Destination "$backupDir\" -ErrorAction Stop

    if (Test-Path ".\certs") {
        Copy-Item -Path ".\certs" -Destination "$backupDir\certs" -Recurse -ErrorAction Stop
    }

    Write-Host "  [✓] Configuration files backed up" -ForegroundColor Green
} catch {
    Write-Host "  [✗] Configuration backup failed: $_" -ForegroundColor Red
}

# Backup 2: Check services are running
Write-Host "`n[2/6] Checking service status..." -ForegroundColor Yellow
$services = @("pingds.devnetwork.dev", "pingam.devnetwork.dev", "pingidm.devnetwork.dev", "pinggateway.devnetwork.dev")
$runningServices = @()

foreach ($service in $services) {
    $status = docker inspect --format='{{.State.Status}}' $service 2>$null
    if ($status -eq "running") {
        Write-Host "  [✓] $service is running" -ForegroundColor Green
        $runningServices += $service
    } else {
        Write-Host "  [!] $service is not running - skipping data backup" -ForegroundColor Yellow
    }
}

# Backup 3: PingDS LDIF export
Write-Host "`n[3/6] Exporting directory data (LDIF)..." -ForegroundColor Yellow
if ($runningServices -contains "pingds.devnetwork.dev") {
    try {
        # Create export directory
        docker exec pingds.devnetwork.dev mkdir -p /opt/opendj/ldif-backup 2>$null

        # Export userRoot backend
        docker exec pingds.devnetwork.dev /opt/opendj/bin/export-ldif `
            --hostname localhost `
            --port 4444 `
            --bindDN "cn=Directory Manager" `
            --bindPassword "password" `
            --backendID userRoot `
            --ldifFile "/opt/opendj/ldif-backup/userRoot-$timestamp.ldif" `
            --trustAll 2>&1 | Out-Null

        # Copy LDIF from container
        docker cp "pingds.devnetwork.dev:/opt/opendj/ldif-backup/userRoot-$timestamp.ldif" "$backupDir\" 2>&1 | Out-Null

        if (Test-Path "$backupDir\userRoot-$timestamp.ldif") {
            $size = (Get-Item "$backupDir\userRoot-$timestamp.ldif").Length / 1MB
            Write-Host "  [✓] Directory data exported ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
        } else {
            Write-Host "  [!] LDIF export may have failed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [✗] Directory export failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  [!] PingDS not running - skipping LDIF export" -ForegroundColor Yellow
}

# Backup 4: Container data volumes
Write-Host "`n[4/6] Backing up container data volumes..." -ForegroundColor Yellow
$serviceMap = @{
    "pingds" = "pingds.devnetwork.dev"
    "pingam" = "pingam.devnetwork.dev"
    "pingidm" = "pingidm.devnetwork.dev"
    "pinggateway" = "pinggateway.devnetwork.dev"
}

foreach ($serviceName in $serviceMap.Keys) {
    $containerName = $serviceMap[$serviceName]

    if ($runningServices -contains $containerName) {
        Write-Host "  Backing up $serviceName data..." -ForegroundColor Gray

        try {
            # Create tar backup of container volumes
            docker run --rm `
                --volumes-from $containerName `
                -v "${backupDir}:/backup" `
                busybox `
                tar czf "/backup/$serviceName-data-$timestamp.tar.gz" /opt 2>&1 | Out-Null

            if (Test-Path "$backupDir\$serviceName-data-$timestamp.tar.gz") {
                $size = (Get-Item "$backupDir\$serviceName-data-$timestamp.tar.gz").Length / 1MB
                Write-Host "  [✓] $serviceName data backed up ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [✗] $serviceName backup failed: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] $serviceName not running - skipping" -ForegroundColor Yellow
    }
}

# Backup 5: Create backup manifest
Write-Host "`n[5/6] Creating backup manifest..." -ForegroundColor Yellow
$manifest = @{
    "timestamp" = $timestamp
    "backup_path" = $backupDir
    "services_backed_up" = $runningServices
    "files" = @(Get-ChildItem -Path $backupDir -Recurse -File | Select-Object Name, Length, LastWriteTime)
    "docker_version" = (docker version --format "{{.Server.Version}}" 2>$null)
    "docker_compose_version" = (docker-compose version --short 2>$null)
} | ConvertTo-Json -Depth 5

$manifest | Out-File -FilePath "$backupDir\manifest.json" -Encoding UTF8
Write-Host "  [✓] Manifest created" -ForegroundColor Green

# Backup 6: Compress backup (optional)
if ($CompressBackup) {
    Write-Host "`n[6/6] Compressing backup..." -ForegroundColor Yellow
    try {
        $zipFile = "$BackupPath\backup-$timestamp.zip"
        Compress-Archive -Path "$backupDir\*" -DestinationPath $zipFile -CompressionLevel Optimal -Force

        $originalSize = (Get-ChildItem -Path $backupDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        $compressedSize = (Get-Item $zipFile).Length / 1MB
        $ratio = [math]::Round(($compressedSize / $originalSize) * 100, 1)

        Write-Host "  [✓] Backup compressed" -ForegroundColor Green
        Write-Host "    Original size: $([math]::Round($originalSize, 2)) MB" -ForegroundColor Gray
        Write-Host "    Compressed size: $([math]::Round($compressedSize, 2)) MB ($ratio%)" -ForegroundColor Gray

        # Remove uncompressed backup
        Remove-Item -Path $backupDir -Recurse -Force
        Write-Host "  [✓] Uncompressed backup removed" -ForegroundColor Green

        $finalBackup = $zipFile
    } catch {
        Write-Host "  [✗] Compression failed: $_" -ForegroundColor Red
        $finalBackup = $backupDir
    }
} else {
    $finalBackup = $backupDir
}

# Cleanup old backups
Write-Host "`nCleaning up old backups (retention: $RetentionDays days)..." -ForegroundColor Yellow
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)

$oldBackups = Get-ChildItem -Path $BackupPath -Filter "backup-*" |
    Where-Object { $_.LastWriteTime -lt $cutoffDate }

if ($oldBackups.Count -gt 0) {
    Write-Host "  Found $($oldBackups.Count) old backup(s) to remove" -ForegroundColor Gray
    foreach ($oldBackup in $oldBackups) {
        try {
            Remove-Item -Path $oldBackup.FullName -Recurse -Force
            Write-Host "  [✓] Removed: $($oldBackup.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  [✗] Failed to remove $($oldBackup.Name): $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  [✓] No old backups to clean up" -ForegroundColor Green
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Backup Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Backup Location: $finalBackup" -ForegroundColor Green
Write-Host "Services backed up: $($runningServices.Count)/$($services.Count)" -ForegroundColor White

if (Test-Path $finalBackup) {
    if ($CompressBackup) {
        $backupSize = (Get-Item $finalBackup).Length / 1MB
    } else {
        $backupSize = (Get-ChildItem -Path $finalBackup -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    }
    Write-Host "Total size: $([math]::Round($backupSize, 2)) MB" -ForegroundColor White
}

Write-Host "`n[!] Important: Test restore procedures regularly" -ForegroundColor Yellow
Write-Host ""
