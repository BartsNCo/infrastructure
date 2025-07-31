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
echo ""

if [ -n "${PANOS_JSON}" ]; then
    echo "Panos to process (${PANOS_COUNT} total):"
    echo "${PANOS_JSON}" | jq -r '.[] | "  - Pano ID: \(.panoId) | Tour ID: \(.tourId) | S3 Key: \(.s3Key) | Name: \(.panoName // "N/A")"'
    echo ""
    
    echo "Detailed Panos JSON:"
    echo "${PANOS_JSON}" | jq '.'
    echo ""
else
    echo "No PANOS_JSON environment variable found"
fi

# TODO: Add Unity build logic here
echo "Unity build process - copying pano files to Unity project"
echo "Processing ${PANOS_COUNT:-0} panos"

if [ -n "${PANOS_JSON}" ] && [ "${PANOS_COUNT:-0}" -gt 0 ]; then
    echo ""
    echo "Starting file copy operations to Unity project..."
    
    # Parse each pano and copy its image to Unity project
    echo "${PANOS_JSON}" | jq -c '.[]' | while read -r pano; do
        TOUR_ID=$(echo "$pano" | jq -r '.tourId')
        S3_KEY=$(echo "$pano" | jq -r '.s3Key')
        
        # Extract image name from S3 key (remove 'image/' prefix) and add .jpg extension
        IMAGE_NAME=$(echo "$S3_KEY" | sed 's|^image/||').jpg
        
        # Create Unity project directory structure with proper permissions
        UNITY_DEST_DIR="/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets/${TOUR_ID}/panos"
        mkdir -p "$UNITY_DEST_DIR"
        chmod -R 755 "/unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets"
        
        echo "Copying pano for Tour ID: $TOUR_ID"
        echo "  Source: s3://${S3_BUCKET}/${S3_KEY}"
        echo "  Destination: ${UNITY_DEST_DIR}/${IMAGE_NAME}"
        
        # Copy the file from S3 to Unity project directory
        aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "${UNITY_DEST_DIR}/${IMAGE_NAME}"
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully copied ${IMAGE_NAME} to Unity project"
        else
            echo "  ✗ Failed to copy ${IMAGE_NAME}"
        fi
        echo ""
    done
    
    echo "File copy operations to Unity project completed"
    echo "Unity project structure:"
    find /unity-project/BartsViewerBundlesBuilder/Assets/ToursAssets -type f -name "*.jpg" | head -10
    
    echo ""
    echo "Starting Unity build process..."
    
    # Find Unity editor path
    UNITY_EDITOR_PATH=$(unity-hub editors --installed | grep "6000.0.54f1" | sed 's/.*installed at //' | head -n 1)
    if [ -z "$UNITY_EDITOR_PATH" ]; then
        echo "Unity 6000.0.54f1 not found, trying default path..."
        UNITY_EDITOR_PATH="/opt/unity/Editor/Unity"
    fi
    
    echo "Using Unity editor at: $UNITY_EDITOR_PATH"
    
    # Build for Android target
    echo "Building for Android..."
    "$UNITY_EDITOR_PATH" \
      -batchmode \
      -quit \
      -nographics \
      -silent-crashes \
      -logFile /dev/stdout \
      -projectPath /unity-project/BartsViewerBundlesBuilder \
      -buildTarget Android \
      -executeMethod UnityEditor.AssetDatabase.Refresh
    
    ANDROID_EXIT_CODE=$?
    
    # Build for WebGL target
    echo "Building for WebGL..."
    "$UNITY_EDITOR_PATH" \
      -batchmode \
      -quit \
      -nographics \
      -silent-crashes \
      -logFile /dev/stdout \
      -projectPath /unity-project/BartsViewerBundlesBuilder \
      -buildTarget WebGL \
      -executeMethod UnityEditor.AssetDatabase.Refresh
    
    UNITY_EXIT_CODE=$?
    
    if [ $ANDROID_EXIT_CODE -eq 0 ] && [ $UNITY_EXIT_CODE -eq 0 ]; then
        echo "✓ Unity builds completed successfully for both Android and WebGL"
        
        echo ""
        echo "Copying Unity build output to S3..."
        
        # Check if ServerData directory exists
        if [ -d "/unity-project/BartsViewerBundlesBuilder/ServerData" ]; then
            echo "Found ServerData directory, copying to S3..."
            
            # Copy all ServerData contents to S3 output bucket
            aws s3 sync /unity-project/BartsViewerBundlesBuilder/ServerData/ s3://${S3_OUTPUT_BUCKET}/assets/
            
            S3_COPY_EXIT_CODE=$?
            
            if [ $S3_COPY_EXIT_CODE -eq 0 ]; then
                echo "✓ Successfully uploaded Unity build output to S3"
                echo "Build artifacts available at: s3://${S3_OUTPUT_BUCKET}/assets/"
            else
                echo "✗ Failed to upload Unity build output to S3 (exit code: $S3_COPY_EXIT_CODE)"
                exit $S3_COPY_EXIT_CODE
            fi
        else
            echo "⚠ ServerData directory not found - Unity build may not have generated expected output"
            echo "Available directories in Unity project:"
            ls -la /unity-project/BartsViewerBundlesBuilder/
        fi
        
    else
        echo "✗ Unity builds failed - Android: $ANDROID_EXIT_CODE, WebGL: $UNITY_EXIT_CODE"
        exit 1
    fi
    
else
    echo "No panos to process - skipping Unity build"
fi

echo ""
echo "End time: $(date)"
echo "================================================"
echo "Unity Builder Container Completed"
echo "================================================"
