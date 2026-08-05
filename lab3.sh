#!/bin/bash

VERBOSE_FLAG=""
TOTAL_FAILURES=0

# Parse arguments for verbose flag
while [ $# -gt 0 ]; do
    case "$1" in
        -v | -verbose | --verbose)
            VERBOSE_FLAG="-verbose"
            ;;
    esac
    shift
done

report_failure() {
    echo "LAB3 ERROR: $1" >&2
    ((TOTAL_FAILURES++))
}

# Copy script via SCP and execute remotely over SSH
run_remote_deployment() {
    local target_host="$1"
    shift
    local remote_params=("$@")

    if ! scp configure-host.sh "remoteadmin@${target_host}:/root/"; then
        report_failure "Unable to transfer script to $target_host via SCP"
        return 1
    fi

    if ! ssh "remoteadmin@${target_host}" -- /root/configure-host.sh $VERBOSE_FLAG "${remote_params[@]}"; then
        report_failure "Execution of configure-host.sh failed on remote system $target_host"
        return 1
    fi
}

# Orchestrate deployments on target servers
run_remote_deployment "server1-mgmt" -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
run_remote_deployment "server2-mgmt" -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3

# Update local VM host file
if ! ./configure-host.sh $VERBOSE_FLAG -hostentry loghost 192.168.16.3; then
    report_failure "Failed to set loghost entry on local host VM"
fi

if ! ./configure-host.sh $VERBOSE_FLAG -hostentry webhost 192.168.16.4; then
    report_failure "Failed to set webhost entry on local host VM"
fi

# Exit with error total
if [ "$TOTAL_FAILURES" -ne 0 ]; then
    echo "LAB3: Execution finished with $TOTAL_FAILURES error(s)." >&2
    exit "$TOTAL_FAILURES"
fi

exit 0
