#!/bin/bash
# Health check script for Ping Identity Platform
# Verifies all services are running and healthy

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Ping Identity Platform Health Check"
echo "=========================================="
echo ""

OVERALL_STATUS="healthy"

# Function to check container health
check_container() {
    local container_name=$1
    local service_name=$2

    echo -n "Checking $service_name..."

    if ! podman ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e " ${RED}✗ NOT RUNNING${NC}"
        OVERALL_STATUS="unhealthy"
        return 1
    fi

    local status=$(podman inspect "$container_name" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")

    if [ "$status" = "healthy" ]; then
        echo -e " ${GREEN}✓ HEALTHY${NC}"
        return 0
    elif [ "$status" = "no-healthcheck" ]; then
        # If no healthcheck defined, check if container is running
        local running=$(podman inspect "$container_name" --format='{{.State.Running}}' 2>/dev/null || echo "false")
        if [ "$running" = "true" ]; then
            echo -e " ${YELLOW}⚠ RUNNING (no health check)${NC}"
            return 0
        else
            echo -e " ${RED}✗ NOT RUNNING${NC}"
            OVERALL_STATUS="unhealthy"
            return 1
        fi
    else
        echo -e " ${RED}✗ UNHEALTHY (status: $status)${NC}"
        OVERALL_STATUS="unhealthy"
        return 1
    fi
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local url=$1
    local service_name=$2
    local expected_code=${3:-200}

    echo -n "Checking $service_name HTTP endpoint..."

    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$response" = "$expected_code" ]; then
        echo -e " ${GREEN}✓ OK (HTTP $response)${NC}"
        return 0
    else
        echo -e " ${RED}✗ FAILED (HTTP $response)${NC}"
        OVERALL_STATUS="unhealthy"
        return 1
    fi
}

# Function to check HTTPS endpoint (with -k for self-signed certs)
check_https_endpoint() {
    local url=$1
    local service_name=$2
    local auth=$3

    echo -n "Checking $service_name HTTPS endpoint..."

    local response
    if [ -n "$auth" ]; then
        response=$(curl -k -s -o /dev/null -w "%{http_code}" -u "$auth" "$url" 2>/dev/null || echo "000")
    else
        response=$(curl -k -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    fi

    if [ "$response" = "200" ]; then
        echo -e " ${GREEN}✓ OK (HTTP $response)${NC}"
        return 0
    else
        echo -e " ${RED}✗ FAILED (HTTP $response)${NC}"
        OVERALL_STATUS="unhealthy"
        return 1
    fi
}

# Check containers
echo "=== Container Status ==="
echo ""
check_container "ping-mysql" "MySQL Database"
check_container "ping-ds-1" "Directory Server 1"
check_container "ping-ds-2" "Directory Server 2"
check_container "ping-ds-proxy" "DS Proxy"
check_container "ping-am" "Access Manager"
check_container "ping-idm" "Identity Manager"
check_container "ping-ig" "Identity Gateway"
check_container "ping-admin-ui" "Admin UI"
check_container "ping-login-ui" "Login UI"

echo ""
echo "=== HTTP/HTTPS Endpoints ==="
echo ""

# Check AM
check_http_endpoint "http://localhost:8082/am/isAlive.jsp" "AM"

# Check IDM
check_https_endpoint "https://localhost:8446/openidm/info/ping" "IDM" "openidm-admin:changeme"

# Check IG
check_http_endpoint "http://localhost:8084/ig/status" "IG" "200"

# Check Admin UI
check_http_endpoint "http://localhost:8085/" "Admin UI" "200"

# Check Login UI
check_http_endpoint "http://localhost:8086/" "Login UI" "200"

echo ""
echo "=== DS Replication Status ==="
echo ""

# Check DS replication
echo -n "Checking DS replication..."
if podman exec ping-ds-1 /opt/opendj/bin/dsreplication status \
    --hostname ds-1.ping.local --port 4444 \
    --adminUID admin --adminPassword changeme \
    --trustAll --no-prompt >/dev/null 2>&1; then
    echo -e " ${GREEN}✓ REPLICATION OK${NC}"
else
    echo -e " ${YELLOW}⚠ REPLICATION CHECK FAILED (may be initializing)${NC}"
fi

echo ""
echo "=== Database Connectivity ==="
echo ""

# Check MySQL from IDM perspective
echo -n "Checking IDM → MySQL connectivity..."
if podman exec ping-idm nc -zv ping-mysql 3306 >/dev/null 2>&1; then
    echo -e " ${GREEN}✓ CONNECTED${NC}"
else
    echo -e " ${RED}✗ CONNECTION FAILED${NC}"
    OVERALL_STATUS="unhealthy"
fi

# Check DS from AM perspective
echo -n "Checking AM → DS connectivity..."
if podman exec ping-am nc -zv ds-1.ping.local 1389 >/dev/null 2>&1; then
    echo -e " ${GREEN}✓ CONNECTED${NC}"
else
    echo -e " ${RED}✗ CONNECTION FAILED${NC}"
    OVERALL_STATUS="unhealthy"
fi

echo ""
echo "=== Network Status ==="
echo ""

# Check DNS resolution
echo -n "Checking internal DNS resolution..."
if podman exec ping-am nslookup ds-1.ping.local >/dev/null 2>&1; then
    echo -e " ${GREEN}✓ DNS OK${NC}"
else
    echo -e " ${RED}✗ DNS FAILED${NC}"
    OVERALL_STATUS="unhealthy"
fi

echo ""
echo "=== Volume Status ==="
echo ""

VOLUMES=("ds-data-1" "ds-data-2" "am-data" "idm-data" "ig-data" "mysql-data")

for vol in "${VOLUMES[@]}"; do
    echo -n "Checking volume: $vol..."
    if podman volume exists "$vol" 2>/dev/null; then
        local size=$(podman volume inspect "$vol" --format '{{.Mountpoint}}' | xargs du -sh 2>/dev/null | cut -f1)
        echo -e " ${GREEN}✓ EXISTS${NC} (size: $size)"
    else
        echo -e " ${RED}✗ NOT FOUND${NC}"
        OVERALL_STATUS="unhealthy"
    fi
done

echo ""
echo "=========================================="
if [ "$OVERALL_STATUS" = "healthy" ]; then
    echo -e "${GREEN}Overall Status: HEALTHY${NC}"
    echo "=========================================="
    exit 0
else
    echo -e "${RED}Overall Status: UNHEALTHY${NC}"
    echo "=========================================="
    echo ""
    echo "Some services are not healthy. Check logs with:"
    echo "  podman-compose logs <service-name>"
    echo ""
    echo "For detailed container inspection:"
    echo "  podman inspect <container-name>"
    exit 1
fi
