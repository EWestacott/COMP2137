#!/bin/bash

# Ignore termination and interrupt signals
trap '' INT HUP TERM

IS_VERBOSE=0
ERROR_COUNT=0

# Helper functions for logging and error tracking
out_verbose() {
    [ "$IS_VERBOSE" -eq 1 ] && echo "[INFO] $1"
}

sys_log() {
    logger -t "configure-host" "$1"
}

out_error() {
    echo "[ERROR] $1" >&2
    ((ERROR_COUNT++))
}

# Update active system hostname, /etc/hostname, and /etc/hosts
apply_hostname() {
    local target_name="$1"
    local active_name="$(hostname)"
    local static_name=""
    
    [ -f /etc/hostname ] && static_name="$(tr -d '[:space:]' < /etc/hostname)"

    # Update running system hostname
    if [ "$active_name" != "$target_name" ]; then
        if hostnamectl set-hostname "$target_name" 2>/dev/null || hostname "$target_name" 2>/dev/null; then
            out_verbose "Active hostname updated from '$active_name' to '$target_name'"
            sys_log "Active hostname updated from '$active_name' to '$target_name'"
        else
            out_error "Failed to set running hostname to '$target_name'"
        fi
    else
        out_verbose "Active hostname is already '$target_name'"
    fi

    # Update /etc/hostname file
    if [ "$static_name" != "$target_name" ]; then
        if echo "$target_name" > /etc/hostname; then
            out_verbose "/etc/hostname updated: '$static_name' -> '$target_name'"
            sys_log "/etc/hostname updated to '$target_name'"
        else
            out_error "Failed to update /etc/hostname file"
        fi
    else
        out_verbose "/etc/hostname already configured for '$target_name'"
    fi

    # Update matching host mappings in /etc/hosts (including -mgmt alias)
    if grep -q -w "$active_name" /etc/hosts && [ "$active_name" != "$target_name" ]; then
        if sed -i -E "s/([[:space:]])${active_name}(-mgmt)?([[:space:]]|\$)/\1${target_name}\2\3/g" /etc/hosts; then
            out_verbose "/etc/hosts updated mapping for '$target_name'"
            sys_log "/etc/hosts mapping modified: '$active_name' -> '$target_name'"
        else
            out_error "Failed to update /etc/hosts for hostname change"
        fi
    else
        out_verbose "/etc/hosts requires no changes for hostname '$target_name'"
    fi
}

# Update IP address in Netplan and /etc/hosts, then apply
apply_ip() {
    local target_ip="$1"
    local lan_dev="$(ip route show default 2>/dev/null | awk '/default/ {print $5}')"
    
    [ -z "$lan_dev" ] && lan_dev="$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n 1)"

    local current_ip="$(ip -4 addr show dev "$lan_dev" 2>/dev/null | awk '/inet / {print $2}' | cut -d'/' -f1)"

    if [ "$current_ip" = "$target_ip" ]; then
        out_verbose "Interface $lan_dev is already set to IP $target_ip"
        return 0
    fi

    # Modify Netplan configuration YAML files
    local netplan_modified=0
    for cfg in /etc/netplan/*.yaml; do
        if [ -f "$cfg" ] && grep -q "$current_ip" "$cfg"; then
            if sed -i "s,${current_ip},${target_ip},g" "$cfg"; then
                out_verbose "Replaced IP $current_ip with $target_ip in $cfg"
                sys_log "Netplan configuration $cfg updated to $target_ip"
                netplan_modified=1
            else
                out_error "Failed to modify netplan file $cfg"
            fi
        fi
    done

    # Update matching IP in /etc/hosts
    if [ -n "$current_ip" ] && grep -q "$current_ip" /etc/hosts; then
        if sed -i "s,${current_ip},${target_ip},g" /etc/hosts; then
            out_verbose "Updated /etc/hosts IP entry from $current_ip to $target_ip"
            sys_log "/etc/hosts updated IP: $current_ip -> $target_ip"
        else
            out_error "Failed to update IP in /etc/hosts"
        fi
    fi

    # Apply netplan changes
    if [ $netplan_modified -eq 1 ] || [ "$current_ip" != "$target_ip" ]; then
        if netplan apply 2>/dev/null; then
            out_verbose "Netplan applied successfully for $target_ip on $lan_dev"
        else
            out_error "Failed to execute 'netplan apply'"
        fi
    fi
}

# Manage host/IP mapping in /etc/hosts
apply_hostentry() {
    local entry_name="$1"
    local entry_ip="$2"

    if grep -q -E "^\s*${entry_ip}\s+.*?\b${entry_name}\b" /etc/hosts; then
        out_verbose "/etc/hosts entry '$entry_name' ($entry_ip) is already accurate"
    elif grep -q -w "$entry_name" /etc/hosts; then
        if sed -i -E "s/^[0-9.]+(\s+.*?\b${entry_name}\b)/${entry_ip}\1/" /etc/hosts; then
            out_verbose "/etc/hosts updated: mapped '$entry_name' to IP $entry_ip"
            sys_log "/etc/hosts updated mapping: $entry_name -> $entry_ip"
        else
            out_error "Failed to update IP for '$entry_name' in /etc/hosts"
        fi
    else
        if echo -e "${entry_ip}\t${entry_name}" >> /etc/hosts; then
            out_verbose "Added new entry to /etc/hosts: $entry_ip $entry_name"
            sys_log "Added /etc/hosts entry: $entry_ip $entry_name"
        else
            out_error "Failed to append '$entry_name' to /etc/hosts"
        fi
    fi
}

# Parse command line flags
while [ $# -gt 0 ]; do
    case "$1" in
        -v | -verbose | --verbose)
            IS_VERBOSE=1
            ;;
        -n | -name)
            shift
            apply_hostname "$1"
            ;;
        -ip)
            shift
            apply_ip "$1"
            ;;
        -hostentry)
            shift
            target_hname="$1"
            shift
            target_hip="$1"
            apply_hostentry "$target_hname" "$target_hip"
            ;;
        *)
            out_error "Unrecognized parameter: $1"
            ;;
    esac
    shift
done

exit $ERROR_COUNT
