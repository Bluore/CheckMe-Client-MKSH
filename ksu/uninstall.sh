#!/system/bin/sh
# Uninstall script for monitor_service

MODDIR=${0%/*}
PID_FILE="$MODDIR/monitor.pid"

# Stop monitor if running
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null
        echo "Stopped monitor.sh (pid $pid)"
    else
        echo "monitor.sh not running (stale pid $pid)"
    fi
    rm -f "$PID_FILE"
fi

# Remove any leftover logs (optional)
# rm -f "$MODDIR/monitor.log"