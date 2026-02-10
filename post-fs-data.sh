#!/system/bin/sh
# Set permissions for module files

MODDIR=${0%/*}

# Ensure scripts are executable
chmod 0755 "$MODDIR/service.sh"
chmod 0755 "$MODDIR/monitor.sh"

# Ensure config file is readable
chmod 0644 "$MODDIR/.config.txt"