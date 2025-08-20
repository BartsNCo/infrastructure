#!/bin/bash
set -x

# Control file to prevent concurrent executions
CONTROL_FILE="/home/ubuntu/unity_builder_update.lock"

# Check if control file exists
if [ -f "$CONTROL_FILE" ]; then
    # Get file creation time (modification time in seconds since epoch)
    FILE_TIME=$(stat -c %Y "$CONTROL_FILE" 2>/dev/null || stat -f %m "$CONTROL_FILE" 2>/dev/null)
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - FILE_TIME))
    
    # If file is less than 2 minutes old (120 seconds), exit
    if [ $TIME_DIFF -lt 120 ]; then
        echo "Update already running (lock file created ${TIME_DIFF} seconds ago). Exiting."
        exit 0
    else
        # File is older than 2 minutes, remove it
        echo "Removing stale lock file (${TIME_DIFF} seconds old)"
        rm -f "$CONTROL_FILE"
    fi
fi

# Create new control file
touch "$CONTROL_FILE"
echo "Created lock file at $(date)"
 
# Ensure AWS CLI is in PATH
export PATH="/usr/local/bin:$PATH"
 
# Source environment variables
# shellcheck disable=SC1091
source /home/ubuntu/.unity_builder_env
 
echo "Sourced unity builder environment variables"
 
# Function to get Unity credentials from AWS Secrets Manager
get_unity_credentials() {
    echo "Fetching Unity credentials from Secrets Manager..."
    UNITY_SECRET=$(aws secretsmanager get-secret-value --secret-id "$UNITY_BUILDER_SECRET_ARN" --query SecretString --output text)
    GITHUB_TOKEN=$(echo "$UNITY_SECRET" | jq -r .GITHUB_TOKEN)
    UNITY_USERNAME=$(echo "$UNITY_SECRET" | jq -r .UNITY_USERNAME)
    UNITY_PASSWORD=$(echo "$UNITY_SECRET" | jq -r .UNITY_PASSWORD)
    export GITHUB_TOKEN
    export UNITY_USERNAME
    export UNITY_PASSWORD
}

# Get credentials
echo "Getting Unity credentials..."
get_unity_credentials

IAC_DIR=/home/ubuntu/infrastructure
UPDATE_SCRIPT=/home/ubuntu/update-inner.sh

if [ -d "$IAC_DIR" ]; then
    git -C "$IAC_DIR" pull
else
    git clone --depth 1 -b main "https://${GITHUB_TOKEN}@github.com/BartsNCo/infrastructure.git" "${IAC_DIR}"
fi

cp -f "${IAC_DIR}/resources/viewer-app/unity-builder/ec2/update-inner.sh" "$UPDATE_SCRIPT"

chmod +x "$UPDATE_SCRIPT"

bash "$UPDATE_SCRIPT"

# Remove the control file at the end
rm -f "$CONTROL_FILE"
echo "Removed lock file"
