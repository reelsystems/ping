#!/bin/bash
# Ping Identity Installation Verification Script
# Verifies that all required software is properly extracted

set -e

INSTALL_DIR="../install"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=========================================="
echo "Ping Identity Installation Verification"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track errors
ERRORS=0

# Function to check if file/directory exists
check_exists() {
    local path=$1
    local description=$2

    if [ -e "$path" ]; then
        echo -e "${GREEN}✓${NC} Found: $description"
        echo "  Path: $path"
        if [ -f "$path" ]; then
            ls -lh "$path" | awk '{print "  Size: " $5}'
        fi
        return 0
    else
        echo -e "${RED}✗${NC} Missing: $description"
        echo "  Expected path: $path"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "Checking PingDS installation..."
echo "--------------------------------"
check_exists "$INSTALL_DIR/opendj" "PingDS directory"
check_exists "$INSTALL_DIR/opendj/bin/setup" "PingDS setup script"
check_exists "$INSTALL_DIR/opendj/bin/start-ds" "PingDS start-ds script"
check_exists "$INSTALL_DIR/opendj/lib" "PingDS lib directory"
echo ""

echo "Checking PingIDM installation..."
echo "---------------------------------"
check_exists "$INSTALL_DIR/openidm" "PingIDM directory"
check_exists "$INSTALL_DIR/openidm/startup.sh" "PingIDM startup script"
check_exists "$INSTALL_DIR/openidm/bin" "PingIDM bin directory"
check_exists "$INSTALL_DIR/openidm/conf" "PingIDM conf directory"
check_exists "$INSTALL_DIR/openidm/connectors" "PingIDM connectors directory"
echo ""

echo "Checking PingAM installation..."
echo "--------------------------------"
check_exists "$INSTALL_DIR/AM-7.5.2.war" "PingAM WAR file"
echo ""

echo "Checking file permissions..."
echo "----------------------------"
if [ -x "$INSTALL_DIR/opendj/bin/setup" ]; then
    echo -e "${GREEN}✓${NC} PingDS setup script is executable"
else
    echo -e "${YELLOW}⚠${NC} PingDS setup script is not executable"
    echo "  Fix with: chmod +x $INSTALL_DIR/opendj/bin/setup"
fi

if [ -x "$INSTALL_DIR/openidm/startup.sh" ]; then
    echo -e "${GREEN}✓${NC} PingIDM startup script is executable"
else
    echo -e "${YELLOW}⚠${NC} PingIDM startup script is not executable"
    echo "  Fix with: chmod +x $INSTALL_DIR/openidm/startup.sh"
fi
echo ""

echo "Checking directory permissions..."
echo "----------------------------------"
if [ -r "$INSTALL_DIR/opendj" ] && [ -x "$INSTALL_DIR/opendj" ]; then
    echo -e "${GREEN}✓${NC} PingDS directory is readable and executable"
else
    echo -e "${RED}✗${NC} PingDS directory permissions issue"
    echo "  Fix with: chmod -R 755 $INSTALL_DIR/opendj"
    ERRORS=$((ERRORS + 1))
fi

if [ -r "$INSTALL_DIR/openidm" ] && [ -x "$INSTALL_DIR/openidm" ]; then
    echo -e "${GREEN}✓${NC} PingIDM directory is readable and executable"
else
    echo -e "${RED}✗${NC} PingIDM directory permissions issue"
    echo "  Fix with: chmod -R 755 $INSTALL_DIR/openidm"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Installation verification PASSED${NC}"
    echo ""
    echo "All required files are present and accessible."
    echo "You are ready to proceed with deployment."
    echo ""
    echo "Next steps:"
    echo "1. Review .env files in each service directory"
    echo "2. Customize passwords and configuration"
    echo "3. Create Docker network: docker network create ping-network"
    echo "4. Follow INSTALLATION-GUIDE.md for deployment"
    exit 0
else
    echo -e "${RED}✗ Installation verification FAILED${NC}"
    echo ""
    echo "Found $ERRORS error(s). Please fix the issues above before proceeding."
    echo ""
    echo "Common fixes:"
    echo "1. Ensure you've downloaded software from ForgeRock Backstage"
    echo "2. Extract DS-7.5.2.zip to shared/install/opendj/"
    echo "3. Extract IDM-7.5.2.zip to shared/install/openidm/"
    echo "4. Copy AM-7.5.2.war to shared/install/"
    echo ""
    echo "See shared/install/README.md for detailed instructions."
    exit 1
fi
