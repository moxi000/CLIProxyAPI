#!/bin/bash

# CLI Proxy API Service Startup Script
# This script starts the service in background using nohup

cd /home/yanwujin/CLIProxyAPI

# Set environment variables
export PATH=/snap/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

# Create logs directory if not exists
mkdir -p logs

# Kill any existing process on port 8317
pkill -f "go run ./cmd/server" || true
sleep 2

# Start the service in background
echo "Starting CLI Proxy API service at $(date)" >> logs/service.log

# For systemd, just start the service and exit
if [ "$1" = "--systemd" ]; then
    # Start in background and exit immediately
    nohup /snap/bin/go run ./cmd/server --config config.yaml >> logs/service.log 2>&1 &
    exit 0
else
    # For manual start, wait and check
    nohup /snap/bin/go run ./cmd/server --config config.yaml >> logs/service.log 2>&1 &
    
    # Wait a moment and check if process is still running
    sleep 3
    if pgrep -f "go run ./cmd/server" > /dev/null; then
        echo "Service started successfully (PID: $(pgrep -f "go run ./cmd/server"))" >> logs/service.log
        echo "Service started successfully"
    else
        echo "Service failed to start" >&2
        exit 1
    fi
fi
