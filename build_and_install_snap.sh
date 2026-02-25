#!/bin/bash
set -e

SNAPCRAFT_YAML_TEMPLATE="snap/snapcraft.yaml.template"
SNAPCRAFT_YAML="snap/snapcraft.yaml"

# Plug names
CONFDB_STATS_PLUG="system-stats"
CONFDB_FAULTS_MGR_PLUG="faults-manager"

SNAP_NAME=$1
if [[ "$SNAP_NAME" != "system-monitor" && "$SNAP_NAME" != "fault-monitor" ]]; then
    echo "Usage: $0 [custodian-monitor|fault-monitor]"
    exit 1
fi

# snap directory
pushd $SNAP_NAME > /dev/null

# Put account ID into snapcraft.yaml
ACCOUNT_ID=$(snapcraft whoami | grep 'id:' | awk '{print $2}')
if [[ -z "$ACCOUNT_ID" ]]; then
    echo "Error: Could not retrieve Account ID. Are you logged in to snapcraft?"
    exit 1
fi
echo "Using Account ID: $ACCOUNT_ID"

# Overwrite snapcraft.yaml with the template
cp -f "$SNAPCRAFT_YAML_TEMPLATE" $SNAPCRAFT_YAML
sed -i "s/<YOUR_ACCOUNT_ID>/$ACCOUNT_ID/g" $SNAPCRAFT_YAML

# Build
snapcraft pack

# Install
sudo snap remove $SNAP_NAME || true
sudo snap install $SNAP_NAME*.snap --dangerous

# Connect interfaces
if [[ "$SNAP_NAME" == "system-monitor" ]]; then
	sudo snap connect $SNAP_NAME:$CONFDB_STATS_PLUG
	sudo snap connect $SNAP_NAME:system-observe
	sudo snap connect $SNAP_NAME:mount-observe
	# Try this now
	echo "Try this now: 'sudo snap get $ACCOUNT_ID/system-stats/monitor data'"
fi
if [[ "$SNAP_NAME" == "fault-monitor" ]]; then
	sudo snap connect $SNAP_NAME:$CONFDB_STATS_PLUG
	sudo snap connect $SNAP_NAME:$CONFDB_FAULTS_MGR_PLUG
fi

# Clean-up
rm $SNAPCRAFT_YAML
rm *.snap
popd > /dev/null
