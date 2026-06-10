#!/bin/bash
echo "=== HARDWARE SUMMARY REPORT ==="

# Operating system name with version
echo "- OS Name & Version:"
hostnamectl | grep -E "Operating System|Kernel" | sed 's/^ *//'

# CPU name with model number
echo "- CPU Model:"
lscpu | grep "Model name:" | sed 's/Model name: *//'

# Amount of RAM installed
echo "- Installed RAM:"
free -h | awk '/^Mem:/ {print $2}'
