# ForgeRock Health Check Script
# Verifies all services are running and healthy

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ForgeRock Identity Platform Health Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$healthScore = 0
$maxScore = 0

# Check 1: Docker is running
Write-Host "[1/8] Checking Docker..." -ForegroundColor Yellow
$maxScore += 10
try {
    $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
    if ($dockerVersion) {
        Write-Host "  [✓] Docker is running (version: $dockerVersion)" -ForegroundColor Green
        $healthScore += 10
    } else {
        Write-Host "  [✗] Docker is not responding" -ForegroundColor Red
    }
} catch {
    Write-Host "  [✗] Docker check failed: $_" -ForegroundColor Red
}

# Check 2: Container status
Write-Host "`n[2/8] Checking container status..." -ForegroundColor Yellow
$services = @("pingds.devnetwork.dev", "pingam.devnetwork.dev", "pingidm.devnetwork.dev", "pinggateway.devnetwork.dev")
$maxScore += 40  # 10 points per service

foreach ($service in $services) {
    $status = docker inspect --format='{{.State.Status}}' $service 2>$null
    if ($status -eq "running") {
        Write-Host "  [✓] $service is running" -ForegroundColor Green
        $healthScore += 10
    } else {
        Write-Host "  [✗] $service is NOT running (Status: $status)" -ForegroundColor Red
    }
}

# Check 3: Health status
Write-Host "`n[3/8] Checking service health..." -ForegroundColor Yellow
$maxScore += 40  # 10 points per service

foreach ($service in $services) {
    $health = docker inspect --format='{{.State.Health.Status}}' $service 2>$null
    if ($health -eq "healthy") {
        Write-Host "  [✓] $service is healthy" -ForegroundColor Green
        $healthScore += 10
    } elseif ($health -eq "starting") {
        Write-Host "  [!] $service is starting..." -ForegroundColor Yellow
        $healthScore += 5
    } elseif ($null -eq $health -or $health -eq "") {
        Write-Host "  [!] $service has no health check configured" -ForegroundColor Yellow
        $healthScore += 5
    } else {
        Write-Host "  [✗] $service is unhealthy (Status: $health)" -ForegroundColor Red
    }
}

# Check 4: HTTP endpoints
Write-Host "`n[4/8] Checking HTTP endpoints..." -ForegroundColor Yellow
$endpoints = @{
    "PingDS" = "http://localhost:8080"
    "PingAM" = "http://localhost:8081/am/isAlive.jsp"
    "PingIDM" = "http://localhost:8082/openidm/info/ping"
    "PingGateway" = "http://localhost:8083/health"
}
$maxScore += 40  # 10 points per endpoint

foreach ($name in $endpoints.Keys) {
    $url = $endpoints[$name]
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  [✓] $name endpoint accessible" -ForegroundColor Green
            $healthScore += 10
        } else {
            Write-Host "  [!] $name returned status: $($response.StatusCode)" -ForegroundColor Yellow
            $healthScore += 5
        }
    } catch {
        Write-Host "  [✗] $name endpoint not accessible" -ForegroundColor Red
    }
}

# Check 5: Resource usage
Write-Host "`n[5/8] Checking resource usage..." -ForegroundColor Yellow
$maxScore += 10
try {
    $stats = docker stats --no-stream --format "{{.Container}};{{.CPUPerc}};{{.MemUsage}}" 2>$null |
        Select-String "devnetwork.dev"

    if ($stats) {
        Write-Host "  Service              CPU      Memory" -ForegroundColor Gray
        Write-Host "  -------------------- -------- --------------" -ForegroundColor Gray

        foreach ($line in $stats) {
            $parts = $line.ToString().Split(';')
            $container = $parts[0].Replace('.devnetwork.dev', '').PadRight(20)
            $cpu = $parts[1].PadRight(8)
            $mem = $parts[2]
            Write-Host "  $container $cpu $mem" -ForegroundColor White
        }
        Write-Host "  [✓] Resource usage retrieved" -ForegroundColor Green
        $healthScore += 10
    } else {
        Write-Host "  [!] Could not retrieve resource usage" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [✗] Resource check failed: $_" -ForegroundColor Red
}

# Check 6: Disk space
Write-Host "`n[6/8] Checking disk space..." -ForegroundColor Yellow
$maxScore += 10
try {
    $dataPath = "$env:USERPROFILE\Documents\PingData"
    if (Test-Path $dataPath) {
        $drive = (Get-Item $dataPath).PSDrive.Name
        $driveInfo = Get-PSDrive $drive
        $freeGB = [math]::Round($driveInfo.Free / 1GB, 2)
        $usedGB = [math]::Round($driveInfo.Used / 1GB, 2)
        $totalGB = [math]::Round(($driveInfo.Free + $driveInfo.Used) / 1GB, 2)
        $freePercent = [math]::Round(($freeGB / $totalGB) * 100, 1)

        Write-Host "  Drive $drive : $freeGB GB free / $totalGB GB total ($freePercent% free)" -ForegroundColor White

        if ($freePercent -gt 20) {
            Write-Host "  [✓] Sufficient disk space" -ForegroundColor Green
            $healthScore += 10
        } elseif ($freePercent -gt 10) {
            Write-Host "  [!] Warning: Low disk space" -ForegroundColor Yellow
            $healthScore += 5
        } else {
            Write-Host "  [✗] Critical: Very low disk space" -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] Data path not found: $dataPath" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [✗] Disk space check failed: $_" -ForegroundColor Red
}

# Check 7: Network connectivity
Write-Host "`n[7/8] Checking network connectivity..." -ForegroundColor Yellow
$maxScore += 10

# Check internal Docker network
try {
    $network = docker network inspect forgerock-network 2>$null | ConvertFrom-Json
    if ($network) {
        $containers = $network.Containers.Count
        Write-Host "  [✓] ForgeRock network active ($containers containers)" -ForegroundColor Green
        $healthScore += 5
    } else {
        Write-Host "  [✗] ForgeRock network not found" -ForegroundColor Red
    }
} catch {
    Write-Host "  [✗] Network check failed: $_" -ForegroundColor Red
}

# Check AD connectivity
$adHosts = @("192.168.1.2", "192.168.1.3")
$adSuccess = 0
foreach ($adHost in $adHosts) {
    if (Test-Connection -ComputerName $adHost -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Host "  [✓] AD DC $adHost is reachable" -ForegroundColor Green
        $adSuccess++
    } else {
        Write-Host "  [✗] AD DC $adHost is NOT reachable" -ForegroundColor Red
    }
}

if ($adSuccess -eq $adHosts.Count) {
    $healthScore += 5
} elseif ($adSuccess -gt 0) {
    $healthScore += 3
}

# Check 8: Recent errors in logs
Write-Host "`n[8/8] Checking recent logs for errors..." -ForegroundColor Yellow
$maxScore += 10

try {
    $errors = docker-compose logs --tail=100 2>$null | Select-String -Pattern "ERROR|SEVERE|FATAL|Exception" -AllMatches

    if ($errors.Count -eq 0) {
        Write-Host "  [✓] No recent errors in logs" -ForegroundColor Green
        $healthScore += 10
    } elseif ($errors.Count -lt 5) {
        Write-Host "  [!] Warning: $($errors.Count) error(s) found in recent logs" -ForegroundColor Yellow
        $healthScore += 5
        Write-Host "    Run 'docker-compose logs' for details" -ForegroundColor Gray
    } else {
        Write-Host "  [✗] Critical: $($errors.Count) error(s) found in recent logs" -ForegroundColor Red
        Write-Host "    Run 'docker-compose logs' for details" -ForegroundColor Gray
    }
} catch {
    Write-Host "  [!] Could not check logs" -ForegroundColor Yellow
}

# Calculate overall health
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Health Score: $healthScore / $maxScore" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$healthPercent = [math]::Round(($healthScore / $maxScore) * 100, 1)

if ($healthPercent -ge 90) {
    Write-Host " Status: EXCELLENT ($healthPercent%)" -ForegroundColor Green
    Write-Host " All systems operational" -ForegroundColor Green
    $exitCode = 0
} elseif ($healthPercent -ge 75) {
    Write-Host " Status: GOOD ($healthPercent%)" -ForegroundColor Green
    Write-Host " Minor issues detected" -ForegroundColor Yellow
    $exitCode = 0
} elseif ($healthPercent -ge 50) {
    Write-Host " Status: DEGRADED ($healthPercent%)" -ForegroundColor Yellow
    Write-Host " Several issues require attention" -ForegroundColor Yellow
    $exitCode = 1
} else {
    Write-Host " Status: CRITICAL ($healthPercent%)" -ForegroundColor Red
    Write-Host " Immediate action required" -ForegroundColor Red
    $exitCode = 2
}

Write-Host ""

exit $exitCode
