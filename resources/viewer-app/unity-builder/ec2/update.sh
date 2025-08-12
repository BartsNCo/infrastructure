#!/bin/bash
set -e

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

# Get credentials
echo "Getting Unity credentials..."
get_unity_credentials
echo "✓ Unity credentials obtained"

# Update Unity project
echo "Setting up Unity project..."

# Remove any existing temporary directory
if [ -d unity-project-updated ]; then
    echo "Removing existing unity-project-updated directory"
    rm -rf unity-project-updated
fi

echo "Cloning Unity repository to temporary directory..."
if git clone --depth 1 -b dev "https://${GITHUB_TOKEN}@github.com/BartsNCo/Unity.git" unity-project-updated; then
    echo "✓ Unity repository cloned successfully"
    rm -rf unity-project-updated/.git
    echo "✓ Git directory removed"
else
    echo "✗ Failed to clone Unity repository"
    echo "Current directory contents:"
    ls -la
    exit 1
fi

# Create unity-project directory if it doesn't exist
if [ ! -d unity-project ]; then
    echo "Creating unity-project directory"
    mkdir -p unity-project
fi

# Copy updated files over existing project
echo "Copying updated files to unity-project..."
cp -rf unity-project-updated/* unity-project/
echo "✓ Files copied successfully"

# Clean up temporary directory
echo "Cleaning up temporary directory..."
rm -rf unity-project-updated
echo "✓ Temporary directory removed"

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
    done
    
    # Copy to Unity project
    echo "Copying images to Unity project..."
    cp -r /home/ubuntu/images/ToursAssets /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/
    echo "✓ Images copied to Unity project"
else
    echo "No panos to process (PANOS_JSON is empty or PANOS_COUNT is 0)"
fi

UNITY_EDITOR_PATH="/home/ubuntu/Unity/Hub/Editor/6000.0.55f1/Editor/Unity"

# Function to clean up Unity PID file
cleanup_unity_pid() {
    if [ -f /home/ubuntu/.unity_pid ]; then
        echo "Cleaning up Unity PID file..."
        rm -f /home/ubuntu/.unity_pid
    fi
}

# Function to kill existing Unity process
kill_existing_unity() {
    if [ -f /home/ubuntu/.unity_pid ]; then
        OLD_PID=$(cat /home/ubuntu/.unity_pid)
        echo "Found existing Unity PID file with PID: $OLD_PID"
        
        # Check if process is still running
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Killing existing Unity process..."
            kill -TERM "$OLD_PID"
            sleep 2
            
            # Force kill if still running
            if kill -0 "$OLD_PID" 2>/dev/null; then
                echo "Force killing Unity process..."
                kill -KILL "$OLD_PID"
            fi
        else
            echo "Process $OLD_PID is not running"
        fi
        
        # Remove the PID file
        rm -f /home/ubuntu/.unity_pid
        echo "Cleaned up old Unity PID file"
    fi
}

# Function to handle errors and shutdown
error_exit() {
    echo "Script encountered an error. Cleaning up..."
    cleanup_unity_pid
    
    # Shutdown if no other Unity processes are running
    if check_unity_processes; then
        echo "Error occurred and no Unity processes running, shutting down instance..."
        sudo shutdown -h now
    else
        echo "Error occurred but Unity processes are still running, keeping instance alive"
    fi
    exit 1
}

# Ensure cleanup on exit and error
trap cleanup_unity_pid EXIT
trap error_exit ERR

# Kill any existing Unity process before Android build
kill_existing_unity

# Build for Android
echo "Starting Unity build for Android..."
"$UNITY_EDITOR_PATH" \
	-batchmode \
	-quit \
	-nographics \
	-silent-crashes \
	-logFile /dev/stdout \
	-projectPath unity-project/BartsViewerBundlesBuilder \
	-buildTarget android &

# Save Unity PID
UNITY_PID=$!
echo $UNITY_PID > /home/ubuntu/.unity_pid
echo "Unity process started with PID: $UNITY_PID"

# Wait for Unity to complete
wait $UNITY_PID
ANDROID_EXIT_CODE=$?

# Clean up PID file
cleanup_unity_pid

if [ $ANDROID_EXIT_CODE -ne 0 ]; then
    echo "Android build failed with exit code: $ANDROID_EXIT_CODE"
    exit $ANDROID_EXIT_CODE
fi

# Kill any existing Unity process before WebGL build
kill_existing_unity

# Build for WebGL
echo "Starting Unity build for WebGL..."
"$UNITY_EDITOR_PATH" \
	-batchmode \
	-quit \
	-nographics \
	-silent-crashes \
	-logFile /dev/stdout \
	-projectPath unity-project/BartsViewerBundlesBuilder \
	-buildTarget webgl &

# Save Unity PID
UNITY_PID=$!
echo $UNITY_PID > /home/ubuntu/.unity_pid
echo "Unity process started with PID: $UNITY_PID"

# Wait for Unity to complete
wait $UNITY_PID
WEBGL_EXIT_CODE=$?

# Clean up PID file
cleanup_unity_pid

if [ $WEBGL_EXIT_CODE -ne 0 ]; then
    echo "WebGL build failed with exit code: $WEBGL_EXIT_CODE"
    exit $WEBGL_EXIT_CODE
fi

# Copy build output to S3
echo "Copying Unity build output to S3..."

# Copy the ServerData folder to S3 output bucket
if [ -d "/home/ubuntu/unity-project/BartsViewerBundlesBuilder/ServerData" ]; then
    aws s3 sync /home/ubuntu/unity-project/BartsViewerBundlesBuilder/ServerData/ "s3://${S3_OUTPUT_BUCKET}/assets/"
    echo "Unity build output copied to s3://${S3_OUTPUT_BUCKET}/assets/"
else
    echo "Error: ServerData directory not found at /home/ubuntu/unity-project/BartsViewerBundlesBuilder/ServerData"
    exit 1
fi

# Copy Unity addressables streaming assets to S3
echo "Copying Unity addressables streaming assets output to S3..."
if [ -d "/home/ubuntu/unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa" ]; then
    aws s3 sync /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa/ "s3://${S3_OUTPUT_BUCKET}/addressablesstreamingassets/" --delete
    echo "Unity addressables copied to s3://${S3_OUTPUT_BUCKET}/addressablesstreamingassets/"
else
    echo "Warning: Addressables directory not found at /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa"
fi

# Function to check for any running Unity processes (not just our PID file)
check_unity_processes() {
    # Check for any Unity processes running on the system
    if pgrep -f "Unity" > /dev/null; then
        echo "Unity processes are still running on the system, skipping shutdown"
        return 1
    else
        echo "No Unity processes found, safe to shutdown"
        return 0
    fi
}

# Shutdown instance if no Unity processes are running
if check_unity_processes; then
    echo "Shutting down instance..."
    sudo shutdown -h now
fi


