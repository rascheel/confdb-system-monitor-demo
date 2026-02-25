#!/bin/bash -e

# Get acct ID
ACCOUNT_ID=$(snapcraft whoami | grep 'id:' | awk '{print $2}')
if [[ -z "$ACCOUNT_ID" ]]; then
    echo "Error: Could not retrieve Account ID. Are you logged in to snapcraft?"
    exit 1
fi
echo "Using Account ID: $ACCOUNT_ID"

# Set fault config
FAULT_CONFIG='[
	{
		"name": "CPU_HIGH_UTIL",
		"severity": 1,
		"confdb-hook-poll": "data.cpu-utilization-percent",
		"trigger-threshold": 90,
		"trigger-threshold-cnt": 5,
		"trigger-comp": ">",
		"hysteresis-threshold": 75,
		"poll-rate-ms": 5000
	},
	{
		"name": "RAM_EXHAUSTION",
		"severity": 2,
		"confdb-hook-poll": "data.ram-utilization-percent",
		"trigger-threshold": 80,
		"trigger-threshold-cnt": 3,
		"trigger-comp": ">=",
		"hysteresis-threshold": 65,
		"poll-rate-ms": 5000
	},
	{
		"name": "RFS_LOW_SPACE",
		"severity": 2,
		"confdb-hook-poll": "data.rfs-partition-free-percent",
		"trigger-threshold": 10,
		"trigger-threshold-cnt": 1,
		"trigger-comp": "<",
		"hysteresis-threshold": 15,
		"poll-rate-ms": 60000
	}
]'

echo "Initializing default faults configuration via view..."
sudo snap set $ACCOUNT_ID/faults-manager/faults-config faults="$FAULT_CONFIG"

echo "Fault config is:"
sudo snap get $ACCOUNT_ID/faults-manager/faults-config faults
