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
echo ""

# Clone Unity repository if not already cloned
if [ ! -d "/unity-project/BartsViewerBundlesBuilder" ]; then
    echo "Cloning Unity repository..."
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "ERROR: GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    # Clone using token authentication
    git clone -b dev "https://${GITHUB_TOKEN}@github.com/BartsNCo/Unity.git" /unity-project
    
    # Remove .git directory to save space
    rm -rf /unity-project/.git
    
    echo "✓ Repository cloned successfully"
else
    echo "Unity project already exists, skipping clone"
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

    aws s3 sync /unity-project/BartsViewerBundlesBuilder/ServerData/ "s3://${S3_OUTPUT_BUCKET}/assets/"
else
    echo "No panos to process - skipping Unity build"
fi

echo ""
echo "End time: $(date)"
echo "================================================"
echo "Unity Builder Container Completed"
echo "================================================"
