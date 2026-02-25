#!/bin/bash

# --- Configuration ---
TMP_FILE="confdb-schema/tmp-schema.yaml"
KEY_NAME="my-laptop-model-key" # Change this to your actual snapcraft key name

SCHEMA_FILE=$1
if [[ "$SCHEMA_FILE" != "system-stats-schema" && "$SCHEMA_FILE" != "fault-mgr-schema" ]]; then
    echo "Usage: $0 [system-stats-schema|fault-mgr-schema]"
    exit 1
fi

YAML_TEMPLATE="confdb-schema/$SCHEMA_FILE.yaml"
JSON_INPUT="confdb-schema/$SCHEMA_FILE.json"
ASSERT_OUTPUT="confdb-schema/$SCHEMA_FILE.assert"

# --- Prerequisite Checks ---
if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' is not installed. Please run: sudo snap install yq"
    exit 1
fi

if [[ -z $(snapcraft keys | grep "$KEY_NAME") ]]; then
    echo "Error: Snapcraft key '$KEY_NAME' not found."
    echo "Create one with: snapcraft create-key $KEY_NAME"
    exit 1
fi

# --- Execution ---

echo "--- Preparing Assertion Data ---"

# 1. Get your Account ID from snapcraft
ACCOUNT_ID=$(snapcraft whoami | grep 'id:' | awk '{print $2}')
if [[ -z "$ACCOUNT_ID" ]]; then
    echo "Error: Could not retrieve Account ID. Are you logged in to snapcraft?"
    exit 1
fi
echo "Using Account ID: $ACCOUNT_ID"

# 2. Generate a valid RFC3339 timestamp (required by snapd)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 3. Create a temporary copy of the template to avoid overwriting the original
cp "$YAML_TEMPLATE" $TMP_FILE

# 4. Replace placeholders using sed
# Using @ as a delimiter in case IDs contain slashes (unlikely but safe)
sed -i "s/<YOUR_ACCOUNT_ID>/$ACCOUNT_ID/g" $TMP_FILE
sed -i "s/<TIMESTAMP>/$TIMESTAMP/g" $TMP_FILE

# 5. Convert YAML to JSON via yq
yq eval '.' -o=json $TMP_FILE > "$JSON_INPUT"
rm $TMP_FILE

echo "--- Signing Assertion ---"

# 6. Sign the JSON to create the .assert file
# The 'body' key in the JSON becomes the assertion body automatically
snap sign -k "$KEY_NAME" "$JSON_INPUT" > "$ASSERT_OUTPUT"

if [[ $? -eq 0 ]]; then
    echo "Assertion signed successfully: $ASSERT_OUTPUT"
else
    echo "Error: snap sign failed."
    exit 1
fi

echo "--- Acknowledging Assertion ---"

# 7. Feed the signed assertion to snapd
sudo snap ack "$ASSERT_OUTPUT"

if [[ $? -eq 0 ]]; then
    echo "Success! Snapd now knows the '$YAML_TEMPLATE' schema."
    echo "Check with: snap known confdb-schema"
else
    echo "Error: snap ack failed."
    exit 1
fi
