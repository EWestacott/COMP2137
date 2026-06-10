#!/bin/bash

echo "=== System Status ==="

# Display CPU Activity / Load Average
# uptime shows load averages for the past 1, 5, and 15 minutes.
echo "CPU Load Average (1, 5, 15 min):"
uptime | awk -F'load average:' '{print $2}'
echo ""

# Display Free Memory
# The -h flag makes it human-readable
echo "Memory Usage:"
free -h | grep -E "(total|Mem:)"
echo ""

# Display Free Disk Space
# Filters for main storage drives
echo "Disk Space Usage:"
df -h | grep -E "(Filesystem|/dev/)"

echo "====================="
