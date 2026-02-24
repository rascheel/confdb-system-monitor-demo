#!/bin/bash -e

# Get acct ID
ACCOUNT_ID=$(snapcraft whoami | grep 'id:' | awk '{print $2}')
if [[ -z "$ACCOUNT_ID" ]]; then
    echo "Error: Could not retrieve Account ID. Are you logged in to snapcraft?"
    exit 1
fi
echo "Using Account ID: $ACCOUNT_ID"

# Set fault config
FAULT_CONFIG='[{
	"name": "high-cpu-usage-alert",
	"severity": 1,
	"confdb-hook-poll": "data.utilization",
	"trigger-threshold": 25,
	"trigger-threshold-cnt": 5,
	"trigger-comp": ">",
	"hysteresis-threshold": 15,
	"poll-rate-ms": 1000
}]'

echo "Initializing default faults configuration via view..."
sudo snap set $ACCOUNT_ID/faults-manager/faults-config faults="$FAULT_CONFIG"

echo "Fault config is:"
sudo snap get fiILE6C7rDPCGOSIFvUVxUaulCFX11sQ/faults-manager/faults-config faults
