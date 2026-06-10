#!/bin/bash
echo "=== NETWORK CONFIGURATION REPORT ==="

# Interface names and model/NIC descriptions
echo "- Network Interfaces & Hardware Descriptions:"
# lshw requires sudo to see full hardware names
sudo lshw -class network -short | awk 'NR>2 {print $2, "\t", $3, $4, $5, $6}'

echo ""

# IP address(es) for each interface
echo "- IP Addresses per Interface:"
ip -br addr show | awk '{print $1, "->", $3}'

echo ""

# Default route gateway IP address
echo "- Default Gateway:"
ip route | grep default | awk '{print $3}'
