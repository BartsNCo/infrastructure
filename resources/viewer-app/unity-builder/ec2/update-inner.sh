#!/bin/bash
#set -e

# Check if Unity process is running - quit immediately if found
if pgrep -f "Unity" > /dev/null; then
    exit 0
fi

# Ensure AWS CLI is in PATH
export PATH="/usr/local/bin:$PATH"

UNITY_BUILDER_LOGS="${HOME}/logs-unity-builder"
CURRENT_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$UNITY_BUILDER_LOGS"
exec > "${UNITY_BUILDER_LOGS}/${CURRENT_TIMESTAMP}_logfile.txt" 2>&1

echo "================================================"
echo "Unity Builder Script Started at $(date)"
echo "================================================"
echo "Environment Variables:"
env | grep -E "(S3_|MONGODB_|UNITY_|AWS_|PANOS_)" | sort
echo "================================================"

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

# Function to check and remove Unity lock file
check_unity_lockfile() {
    local project_path="${HOME}/unity-project"
    local lockfile1="${project_path}/UnityLockfile"
    local lockfile2="${project_path}/BartsViewerBundlesBuilder/UnityLockfile"
    
    for lockfile in "$lockfile1" "$lockfile2"; do
        if [ -f "$lockfile" ]; then
            echo "Unity lockfile detected at $lockfile"
            echo "Waiting for Unity to release the lock (max 2 minutes)..."
            
            local wait_time=0
            local max_wait=120 # 2 minutes
            
            while [ -f "$lockfile" ] && [ $wait_time -lt $max_wait ]; do
                sleep 5
                wait_time=$((wait_time + 5))
                echo "Waiting... ${wait_time}s/${max_wait}s"
            done
            
            if [ -f "$lockfile" ]; then
                echo "Unity lockfile still exists after 2 minutes. Force removing..."
                rm -f "$lockfile"
                echo "✓ Unity lockfile removed"
            else
                echo "✓ Unity lockfile released naturally"
            fi
        fi
    done
}

# Get credentials
echo "Getting Unity credentials..."
get_unity_credentials
echo "✓ Unity credentials obtained"

# Check for Unity lockfile at the beginning
check_unity_lockfile

clean_unity_project() {
    if [ -d unity-project-updated ]; then
        echo "Updateting Unity repository to temporary directory..."
        git -C unity-project-updated pull
    else
        echo "Cloning Unity repository to temporary directory..."
        git clone --depth 1 -b dev "https://${GITHUB_TOKEN}@github.com/BartsNCo/Unity.git" unity-project-updated
    fi

    if [ ! -d unity-project ]; then
        echo "Creating unity-project directory"
        mkdir -p unity-project
    else
        rm -rf /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets
    fi
    # Copy updated files over existing project
    echo "Copying updated files to unity-project..."
    cp -rf unity-project-updated/* unity-project/
    echo "✓ Files copied successfully"
}
echo "Setting up Unity project..."
clean_unity_project

# Load panos from file
PANOS_FILE="/home/ubuntu/panos_data.json"
if [ -f "$PANOS_FILE" ]; then
    echo "Loading panos data from $PANOS_FILE"
    PANOS_JSON=$(jq -c '.panos' "$PANOS_FILE")
    PANOS_COUNT=$(jq -r '.count' "$PANOS_FILE")
    export PANOS_JSON
    export PANOS_COUNT
fi

# Process panos from environment variable
if [ -n "${PANOS_JSON}" ] && [ "${PANOS_COUNT:-0}" -gt 0 ]; then
    echo "Processing ${PANOS_COUNT} panos from environment variable..."
    
    # Create images directory structure
    mkdir -p /home/ubuntu/images/ToursAssets
    
    # Parse each pano and download its image
    echo "${PANOS_JSON}" | jq -c '.[]' | while read -r pano; do
        TOUR_ID=$(echo "$pano" | jq -r '.tourId')
        PANO_ID=$(echo "$pano" | jq -r '.panoId')
        UNITY_URL=$(echo "$pano" | jq -r '.unityUrl')
        AUDIO_KEY=$(echo "$pano" | jq -r '.audioKey // empty')
        THUMBNAIL_KEY=$(echo "$pano" | jq -r '.thumbnailKey // empty')
        
        # Create tour directory
        TOUR_DIR="/home/ubuntu/images/ToursAssets/${TOUR_ID}/panos"
        mkdir -p "$TOUR_DIR"
        
        # Download image from S3
        IMAGE_NAME="${PANO_ID}.jpg"
        echo "Downloading ${UNITY_URL} to ${TOUR_DIR}/${IMAGE_NAME}"
        
        if aws s3 cp "s3://${S3_INPUT_BUCKET}/${UNITY_URL}" "${TOUR_DIR}/${IMAGE_NAME}"; then
            echo "  ✓ Successfully downloaded ${IMAGE_NAME}"
        else
            echo "  ✗ Failed to download ${IMAGE_NAME}"
        fi
        
        # Download audio if available
        if [ -n "$AUDIO_KEY" ]; then
            AUDIO_FILE="${TOUR_DIR}/${AUDIO_KEY}"
            echo "Downloading audio ${AUDIO_KEY} to ${AUDIO_FILE}"
            if aws s3 cp "s3://${S3_INPUT_BUCKET}/${AUDIO_KEY}" "${AUDIO_FILE}"; then
                echo "  ✓ Successfully downloaded audio file"
            else
                echo "  ✗ Failed to download audio file"
            fi
        fi
        
        # Download thumbnail if available
        if [ -n "$THUMBNAIL_KEY" ]; then
            THUMBNAIL_FILE="${TOUR_DIR}/${THUMBNAIL_KEY}"
            echo "Downloading thumbnail ${THUMBNAIL_KEY} to ${THUMBNAIL_FILE}"
            if aws s3 cp "s3://${S3_INPUT_BUCKET}/${THUMBNAIL_KEY}" "${THUMBNAIL_FILE}"; then
                echo "  ✓ Successfully downloaded thumbnail file"
            else
                echo "  ✗ Failed to download thumbnail file"
            fi
        fi
    done
    
    # Copy to Unity project
    echo "Copying images to Unity project..."
    cp -r /home/ubuntu/images/ToursAssets /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/
    echo "✓ Images copied to Unity project"
else
    echo "No panos to process (PANOS_JSON is empty or PANOS_COUNT is 0)"
fi

UNITY_EDITOR_PATH="/home/ubuntu/Unity/Hub/Editor/6000.0.55f1/Editor/Unity"

# Build for Android
echo "Starting Unity build for Android..."
"$UNITY_EDITOR_PATH" \
	-batchmode \
	-quit \
	-nographics \
	-silent-crashes \
	-logFile "${UNITY_BUILDER_LOGS}/${CURRENT_TIMESTAMP}_android_build.txt" \
	-projectPath unity-project/BartsViewerBundlesBuilder \
	-buildTarget android

echo "Android build completed"

# Check for Unity lockfile after Android build
check_unity_lockfile

rm -rf /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets
cp -r /home/ubuntu/images/ToursAssets /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/
# Build for WebGL
echo "Starting Unity build for WebGL..."
"$UNITY_EDITOR_PATH" \
	-batchmode \
	-quit \
	-nographics \
	-silent-crashes \
	-logFile "${UNITY_BUILDER_LOGS}/${CURRENT_TIMESTAMP}_webgl_build.txt" \
	-projectPath unity-project/BartsViewerBundlesBuilder \
	-buildTarget webgl

echo "WebGL build completed"

# Check for Unity lockfile after WebGL build
check_unity_lockfile

rm -rf /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets
cp -r /home/ubuntu/images/ToursAssets /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/
# Build for Windows
echo "Starting Unity build for Win64..."
"$UNITY_EDITOR_PATH" \
	-batchmode \
	-quit \
	-nographics \
	-silent-crashes \
	-logFile "${UNITY_BUILDER_LOGS}/${CURRENT_TIMESTAMP}_win64_build.txt" \
	-projectPath unity-project/BartsViewerBundlesBuilder \
	-buildTarget win64

echo "Win64 build completed"

# Check for Unity lockfile after Win64 build
check_unity_lockfile

echo "Copying Unity build output to S3..."
# Copy the ServerData folder to S3 output bucket
if [ -d "/home/ubuntu/unity-project/BartsViewerBundlesBuilder/ServerData" ]; then
    aws s3 sync --force --delete /home/ubuntu/unity-project/BartsViewerBundlesBuilder/ServerData/ "s3://${S3_OUTPUT_BUCKET}/assets/"
    echo "Unity build output copied to s3://${S3_OUTPUT_BUCKET}/assets/"
else
    echo "Error: ServerData directory not found at /home/ubuntu/unity-project/BartsViewerBundlesBuilder/ServerData"
fi

# Copy Unity addressables streaming assets to S3
echo "Copying Unity addressables streaming assets output to S3..."
if [ -d "/home/ubuntu/unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa" ]; then
    aws s3 sync --force /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa/ "s3://${S3_OUTPUT_BUCKET}/addressablesstreamingassets/" --delete
    echo "Unity addressables copied to s3://${S3_OUTPUT_BUCKET}/addressablesstreamingassets/"
else
    echo "Warning: Addressables directory not found at /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa"
fi
aws s3 sync "$UNITY_BUILDER_LOGS" "s3://${S3_OUTPUT_BUCKET}/build-logs/"
# Shutdown instance after successful completion
echo "All tasks completed successfully. Shutting down instance..."
sudo shutdown -h now


