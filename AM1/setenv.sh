#!/bin/bash
# Tomcat Environment Configuration for PingAM
# This file is sourced by Tomcat's catalina.sh

# Set JVM options
export CATALINA_OPTS="${CATALINA_OPTS}"

# Set AM home directory
export AM_HOME="/opt/am"

# Ensure AM home directory exists
mkdir -p "$AM_HOME"

# Log startup information
echo "========================================"
echo "PingAM Tomcat Environment Configuration"
echo "========================================"
echo "AM_HOME: $AM_HOME"
echo "CATALINA_OPTS: $CATALINA_OPTS"
echo "JAVA_HOME: $JAVA_HOME"
echo "========================================"
