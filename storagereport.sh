#!/bin/bash
echo "=== STORAGE SUMMARY REPORT ==="

# Installed disk models with their sizes
echo "- Installed Disks & Sizes:"
# lsblk filters for 'disk' types and prints name, model, and size
lsblk -d -o NAME,MODEL,SIZE | grep -v "MODEL"

echo ""

# Size and utilization of space for ext4 filesystems
echo "- ext4 Filesystem Utilization:"
# df -t ext4 filters natively for the ext4 filesystem type
df -h -t ext4
