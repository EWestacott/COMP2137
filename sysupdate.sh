#!/bin/bash

echo "=== Starting System Update ==="

# Update the package lists
sudo apt update -y

# Upgrade all installed packages to their latest versions
sudo apt upgrade -y

# Remove obsolete packages and clean up cache
sudo apt autoremove -y
sudo apt clean

echo "=== System Update Complete ==="
