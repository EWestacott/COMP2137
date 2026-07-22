#!/bin/bash

echo "Starting System Configuration"

# Ensure script is run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: Must be run as root." >&2
    exit 1
fi

# Network Interface (Netplan)
echo "Configuring Network"
CURRENT_IP_CIDR=$(ip -o -4 addr show | grep "192.168.16" | awk '{print $4}' | head -n1)

if [ -n "$CURRENT_IP_CIDR" ] && [ "$CURRENT_IP_CIDR" != "192.168.16.21/24" ]; then
    for f in /etc/netplan/*.yaml; do
        if [ -f "$f" ] && grep -q "$CURRENT_IP_CIDR" "$f"; then
            echo "Updating $CURRENT_IP_CIDR to 192.168.16.21/24 in $f"
            sed -i "s|${CURRENT_IP_CIDR}|192.168.16.21/24|g" "$f"
            netplan apply
        fi
    done
else
    echo "Network is already 192.168.16.21/24 - skipping."
fi

# Update /etc/hosts
echo "Updating /etc/hosts"
HOST_NAME=$(hostname)

if grep -qxF "192.168.16.21 $HOST_NAME" /etc/hosts; then
    echo "/etc/hosts is already up to date."
else
    # Remove stale lines matching hostname that don't start with 127.
    sed -i "/[[:space:]]${HOST_NAME}\([[:space:]]\|$\)/{/^127\./!d}" /etc/hosts
    echo "192.168.16.21 $HOST_NAME" >> /etc/hosts
    echo "/etc/hosts updated with 192.168.16.21 $HOST_NAME."
fi

# Software Packages
echo "Checking Software Packages"
PACKAGES=("apache2" "squid")

for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "$pkg is already installed."
    else
        echo "Installing $pkg"
        apt-get update -qq && apt-get install -y "$pkg"
    fi
    systemctl enable --now "$pkg" &>/dev/null
done

# Users & SSH Keys
echo "Provisioning Users"
USERS=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
ADMIN_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for user in "${USERS[@]}"; do

    # Creat User and Group if Missing
    if ! id "$user" &>/dev/null; then
        useradd -m -U -s /bin/bash "$user"
        echo "Created user $user."
    fi

    # Adds dennis to sudo group AFTER making sure dennis exists
    if [ "$user" == "dennis" ]; then
        usermod -aG sudo dennis
    fi

    # Define paths
    ssh_dir="/home/$user/.ssh"
    auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"

    # Generate ED25519 Key
    if [ ! -f "$ssh_dir/id_ed25519" ]; then
        ssh-keygen -t ed25519 -N "" -f "$ssh_dir/id_ed25519" -q -C "$user"
    fi

    # Generate RSA Key
    if [ ! -f "$ssh_dir/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -N "" -f "$ssh_dir/id_rsa" -q -C "$user"
    fi

    # Create authorized_keys if missing
    touch "$auth_keys"

    # Add public keys to authorized_keys
    ed_pub=$(cat "$ssh_dir/id_ed25519.pub")
    rsa_pub=$(cat "$ssh_dir/id_rsa.pub")

    grep -qF "$ed_pub" "$auth_keys" || echo "$ed_pub" >> "$auth_keys"
    grep -qF "$rsa_pub" "$auth_keys" || echo "$rsa_pub" >> "$auth_keys"

    # Special rules for dennis
    if [ "$user" == "dennis" ]; then
        usermod -aG sudo dennis
        grep -qF "$ADMIN_KEY" "$auth_keys" || echo "$ADMIN_KEY" >> "$auth_keys"
    fi

    # Fix permissions
    chown -R "$user:$user" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys" "$ssh_dir/id_ed25519" "$ssh_dir/id_rsa"
    chmod 644 "$ssh_dir/id_ed25519.pub" "$ssh_dir/id_rsa.pub"
done

echo "Configuration Complete"
exit 0
