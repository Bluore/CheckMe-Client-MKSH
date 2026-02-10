#!/system/bin/sh
# KernelSU service script for monitor_service
# This script runs at boot and starts monitor.sh in the background.

MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/.config.txt"
LOG_FILE="$MODDIR/monitor.log"
PID_FILE="$MODDIR/monitor.pid"

# Function to start monitor
start_monitor() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "monitor.sh is already running (pid $pid)"
            return 0
        else
            # Stale PID file
            rm -f "$PID_FILE"
        fi
    fi

    # Change to module directory
    cd "$MODDIR"

    # Start monitor.sh in background
    /system/bin/sh ./monitor.sh >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    echo "monitor.sh started with pid $!"
}

# Function to stop monitor
stop_monitor() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null
            echo "monitor.sh stopped (pid $pid)"
        else
            echo "monitor.sh not running (stale pid $pid)"
        fi
        rm -f "$PID_FILE"
    else
        echo "monitor.sh not running (no pid file)"
    fi
}

case "$1" in
    "start")
        start_monitor
        ;;
    "stop")
        stop_monitor
        ;;
    *)
        # Default: start on boot
        start_monitor
        ;;
esac