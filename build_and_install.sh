#!/bin/bash
set -e

SNAPCRAFT_YAML_TEMPLATE="snap/snapcraft.yaml.template"
SNAPCRAFT_YAML="snap/snapcraft.yaml"
SNAP_FILE="cpu-monitor_0.1_amd64.snap"

# snap directory
pushd custodian-monitor-snap > /dev/null

# Put account ID into snapcraft.yaml
ACCOUNT_ID=$(snapcraft whoami | grep 'id:' | awk '{print $2}')
if [[ -z "$ACCOUNT_ID" ]]; then
    echo "Error: Could not retrieve Account ID. Are you logged in to snapcraft?"
    exit 1
fi
echo "Using Account ID: $ACCOUNT_ID"

# Overwrite snapcraft.yaml with the template
cp "$SNAPCRAFT_YAML_TEMPLATE" $SNAPCRAFT_YAML
sed -i "s/<YOUR_ACCOUNT_ID>/$ACCOUNT_ID/g" $SNAPCRAFT_YAML

# Build
snapcraft pack

# Install
sudo snap remove cpu-monitor || true
sudo snap install $SNAP_FILE --dangerous
sudo snap connect cpu-monitor:stats-db

# Clean-up
rm $SNAPCRAFT_YAML
rm $SNAP_FILE
popd > /dev/null

# Try this now
echo "Try this now: 'sudo snap get $ACCOUNT_ID/cpu-stats/monitor data'"
