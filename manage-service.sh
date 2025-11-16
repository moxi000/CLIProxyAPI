#!/bin/bash

# CLI Proxy API Service Management Script
# Usage: ./manage-service.sh start|stop|restart|status

SERVICE_NAME="CLI Proxy API"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start-service.sh"
LOG_FILE="$SCRIPT_DIR/logs/service.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    if pgrep -f "go run ./cmd/server" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $SERVICE_NAME is running"
        echo "  PID: $(pgrep -f "go run ./cmd/server" | head -1)"
        local port_info=$(ss -tlnp 2>/dev/null | grep 8317 | head -1 | awk '{print $4}' | cut -d: -f2)
        [ ! -z "$port_info" ] && echo "  Port: $port_info"
    else
        echo -e "${RED}✗${NC} $SERVICE_NAME is not running"
    fi
}

start_service() {
    echo "Starting $SERVICE_NAME..."
    if pgrep -f "go run ./cmd/server" > /dev/null; then
        echo -e "${YELLOW}Warning:${NC} Service is already running"
        print_status
        return 1
    fi

    if $START_SCRIPT; then
        echo -e "${GREEN}✓${NC} $SERVICE_NAME started successfully"
        print_status
        return 0
    else
        echo -e "${RED}✗${NC} Failed to start $SERVICE_NAME"
        return 1
    fi
}

stop_service() {
    echo "Stopping $SERVICE_NAME..."
    if ! pgrep -f "go run ./cmd/server" > /dev/null; then
        echo -e "${YELLOW}Warning:${NC} Service is not running"
        return 0
    fi

    pkill -f "go run ./cmd/server"
    sleep 2

    if pgrep -f "go run ./cmd/server" > /dev/null; then
        echo -e "${RED}✗${NC} Failed to stop service gracefully, force killing..."
        pkill -9 -f "go run ./cmd/server"
        sleep 1
    fi

    if pgrep -f "go run ./cmd/server" > /dev/null; then
        echo -e "${RED}✗${NC} Could not stop service"
        return 1
    else
        echo -e "${GREEN}✓${NC} $SERVICE_NAME stopped successfully"
        return 0
    fi
}

restart_service() {
    echo "Restarting $SERVICE_NAME..."
    stop_service
    sleep 2
    start_service
}

show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "Last 20 lines of service log ($LOG_FILE):"
        echo "----------------------------------------"
        tail -20 "$LOG_FILE"
    else
        echo -e "${YELLOW}Log file not found: $LOG_FILE${NC}"
    fi
}

case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        print_status
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the service"
        echo "  stop    - Stop the service"
        echo "  restart - Restart the service"
        echo "  status  - Show service status"
        echo "  logs    - Show recent service logs"
        exit 1
        ;;
esac
