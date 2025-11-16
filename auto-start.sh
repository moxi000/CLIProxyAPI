#!/bin/bash

# CLI Proxy API Auto-start Script
# This script should be added to system startup

SERVICE_DIR="/home/yanwujin/CLIProxyAPI"
LOG_FILE="$SERVICE_DIR/logs/auto-start.log"

# Check if service is already running
if pgrep -f "go run ./cmd/server" >/dev/null 2>&1; then
    echo "$(date): Service already running" >> "$LOG_FILE"
    exit 0
fi

# Start the service
echo "$(date): Starting CLI Proxy API service..." >> "$LOG_FILE"
cd "$SERVICE_DIR"
if ./start-service.sh >> "$LOG_FILE" 2>&1; then
    echo "$(date): Service started successfully" >> "$LOG_FILE"
else
    echo "$(date): Failed to start service" >> "$LOG_FILE"
fi

