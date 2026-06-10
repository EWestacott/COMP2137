#!/bin/bash

echo "=== System Identification ==="

# Get the hostname
echo "Hostname:    $(hostname)"

# Get the internal IP address (filtering out the loopback 'lo' interface)
# Looks for the 'inet' line on the active network interface
IP_ADDR=$(ip -o -4 addr show up | grep -v '127.0.0.1' | awk '{print $4}' | cut -d/ -f1)
echo "IP Address:  $IP_ADDR"

# Get the default gateway IP address
GATEWAY=$(ip route | grep default | awk '{print $3}')
echo "Gateway IP:  $GATEWAY"

echo "============================="
