#!/bin/bash
set -e

echo "================================================"
echo "Unity Builder Container Started"
echo "================================================"
echo "Unity Version: $(unity-editor -version 2>/dev/null || echo 'Unable to get version')"
echo "Current directory: $(pwd)"
echo "Start time: $(date)"
echo ""

echo "Environment Variables:"
echo "  AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
echo "  S3_BUCKET: ${S3_BUCKET}"
echo "  PANOS_COUNT: ${PANOS_COUNT}"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+[REDACTED]}"
echo "  UNITY_USERNAME: ${UNITY_USERNAME:+[SET]}"
echo "  UNITY_PASSWORD: ${UNITY_PASSWORD:+[SET]}"
echo ""

# Clone Unity repository if not already cloned
if [ ! -d "/unity-project/BartsViewerBundlesBuilder" ]; then
    echo "Cloning Unity repository..."
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "ERROR: GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    # Clone using token authentication
    git clone --depth 1 -b dev "https://${GITHUB_TOKEN}@github.com/BartsNCo/Unity.git" /unity-project
    
    # Remove .git directory to save space
    rm -rf /unity-project/.git
    
    echo "✓ Repository cloned successfully"
else
    echo "Unity project already exists, skipping clone"
fi
echo ""

# Handle Unity licensing
UNITY_EDITOR_PATH="/opt/unity/editors/6000.0.55f1/Editor/Unity"

# Check for Unity license file in common locations
echo "Checking for Unity license file..."
UNITY_LICENSE_PATHS=(
    "/root/.local/share/unity3d/Unity/Unity_lic.ulf"
    "/home/unity/.local/share/unity3d/Unity/Unity_lic.ulf"
    "/Unity_lic.ulf"
    "/unity-builder/Unity_lic.ulf"
)

LICENSE_FOUND=false
for LICENSE_PATH in "${UNITY_LICENSE_PATHS[@]}"; do
    if [ -f "$LICENSE_PATH" ]; then
        echo "✓ Found Unity license file at: $LICENSE_PATH"
        LICENSE_FOUND=true
        
        # Ensure the Unity license directory exists
        UNITY_LICENSE_DIR="/root/.local/share/unity3d/Unity"
        mkdir -p "$UNITY_LICENSE_DIR"
        
        # Copy license file to the expected location if not already there
        if [ "$LICENSE_PATH" != "/root/.local/share/unity3d/Unity/Unity_lic.ulf" ]; then
            echo "Copying license file to Unity's expected location..."
            cp "$LICENSE_PATH" "$UNITY_LICENSE_DIR/Unity_lic.ulf"
            chmod 644 "$UNITY_LICENSE_DIR/Unity_lic.ulf"
        fi
        break
    fi
done

if [ "$LICENSE_FOUND" = true ]; then
    echo "✓ Unity license file is in place"
elif [ -n "$UNITY_USERNAME" ] && [ -n "$UNITY_PASSWORD" ]; then
    echo "No license file found, attempting online activation..."
    echo "Using Unity editor at: $UNITY_EDITOR_PATH"
    
    # Check if Unity executable exists
    if [ ! -f "$UNITY_EDITOR_PATH" ]; then
        echo "✗ Unity editor not found at: $UNITY_EDITOR_PATH"
        exit 1
    fi
    
    # Run Unity license activation with output to see what's happening
        echo "Activating without serial number (named user license)..."
    "$UNITY_EDITOR_PATH" -quit -batchmode -nographics -logFile /dev/stdout -serial -username "$UNITY_USERNAME" -password "$UNITY_PASSWORD"
    ACTIVATION_EXIT_CODE=$?
    
    if [ $ACTIVATION_EXIT_CODE -eq 0 ]; then
        echo "✓ Unity license activation command completed successfully"
    else
        echo "✗ Unity license activation failed with exit code: $ACTIVATION_EXIT_CODE"
        echo "Please check your credentials and ensure you have a valid Unity license"
    fi
else
    echo "WARNING: No Unity license file found and no credentials provided"
    echo "Unity builds may fail without a valid license"
fi
echo ""

if [ -n "${PANOS_JSON}" ]; then
    echo "Panos to process (${PANOS_COUNT} total):"
    echo "${PANOS_JSON}" | jq -r '.[] | "  - Pano ID: \(.panoId) | Tour ID: \(.tourId) | S3 Key: \(.unityUrl) | Name: \(.panoName // "N/A")"'
    echo ""
    
    echo "Detailed Panos JSON:"
    echo "${PANOS_JSON}" | jq '.'
    echo ""
else
    echo "No PANOS_JSON environment variable found"
fi

echo "Unity build process - copying pano files to Unity project"
echo "Processing ${PANOS_COUNT:-0} panos"

if [ -n "${PANOS_JSON}" ] && [ "${PANOS_COUNT:-0}" -gt 0 ]; then
    echo ""
    echo "Starting file copy operations to Unity project..."
    
    # Parse each pano and copy its image to Unity project
    echo "${PANOS_JSON}" | jq -c '.[]' | while read -r pano; do
        TOUR_ID=$(echo "$pano" | jq -r '.tourId')
        UNITY_PANO_ID=$(echo "$pano" | jq -r '.panoId')
        
        # Extract image name from S3 key (remove 'image/' prefix) and add .jpg extension
        IMAGE_NAME=$(echo "$UNITY_PANO_ID" | sed 's|^image/||').jpg
        
        # Create Unity project directory structure with proper permissions
        UNITY_DEST_DIR="/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets/${TOUR_ID}/panos"
        mkdir -p "$UNITY_DEST_DIR"
        chmod -R 755 "/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets"
        
        echo "Copying pano for Tour ID: $TOUR_ID"
        echo "  Source: s3://${S3_BUCKET}/${UNITY_PANO_ID}"
        echo "  Destination: ${UNITY_DEST_DIR}/${IMAGE_NAME}"
        
        set +e
        aws s3 cp "s3://${S3_BUCKET}/${UNITY_URL}" "${UNITY_DEST_DIR}/${IMAGE_NAME}"

        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully copied ${IMAGE_NAME} to Unity project"
        else
            echo "  ✗ Failed to copy ${IMAGE_NAME}"
        fi
        echo ""
        set -e
    done
    
    echo "Starting Unity build process..."
    
    # Find Unity editor path
    UNITY_EDITOR_PATH="/opt/unity/editors/6000.0.55f1/Editor/Unity"
    echo "Using Unity editor at: $UNITY_EDITOR_PATH"
    
    # Build for Android target
    # echo "Refresh assets"
    # "$UNITY_EDITOR_PATH" \
    #   -batchmode \
    #   -quit \
    #   -nographics \
    #   -silent-crashes \
    #   -logFile /dev/stdout \
    #   -projectPath /unity-project/BartsViewerBundlesBuilder \
    #   -executeMethod UnityEditor.AssetDatabase.Refresh
    
    echo "Building for Android..."
    "$UNITY_EDITOR_PATH" \
      -batchmode \
      -quit \
      -nographics \
      -silent-crashes \
      -logFile /dev/stdout \
      -projectPath /unity-project/BartsViewerBundlesBuilder \
      -buildTarget android

    # aws s3 sync /unity-project/BartsViewerBundlesBuilder/ServerData/ s3://${S3_OUTPUT_BUCKET}/assets/
    # ANDROID_EXIT_CODE=$?
    
    #echo "Building for WebGL..."
    #"$UNITY_EDITOR_PATH" \
    #  -batchmode \
    #  -quit \
    #  -nographics \
    #  -silent-crashes \
    #  -logFile /dev/stdout \
    #  -projectPath /unity-project/BartsViewerBundlesBuilder \
    #  -buildTarget webgl
    UNITY_EXIT_CODE=$?
    
    if [ $UNITY_EXIT_CODE -eq 0 ]; then
        #echo "✓ Unity builds completed successfully for both Android and WebGL"
        echo "✓ Unity builds completed successfully for both Android"
        
        echo ""
        echo "Copying Unity build output to S3..."
    else
        #echo "✗ Unity builds failed - Android: WebGL: $UNITY_EXIT_CODE"
        echo "✗ Unity builds failed - Android: $UNITY_EXIT_CODE"
        exit 1
    fi

    find /unity-project/BartsViewerBundlesBuilder
    aws s3 sync /unity-project/BartsViewerBundlesBuilder/ServerData/ "s3://${S3_OUTPUT_BUCKET}/assets/"

    echo "Copying Unity addressables streaming assets output to S3..."
    aws s3 sync /unity-project/BartsViewerBundlesBuilder/Library/com.unity.addressables/aa/ "s3://${S3_OUTPUT_BUCKET}/addressablesstreamingassets/"

    
else
    echo "No panos to process - skipping Unity build"
fi

echo ""
echo "End time: $(date)"
echo "================================================"
echo "Unity Builder Container Completed"
echo "================================================"
