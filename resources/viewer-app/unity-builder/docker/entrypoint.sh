#!/bin/bash
set -e

echo "Unity Builder Container Started"
echo "Unity Version: $(unity-editor -version 2>/dev/null || echo 'Unable to get version')"
echo "Current directory: $(pwd)"
echo "Environment variables:"
echo "  PANO_ID: ${PANO_ID}"
echo "  S3_BUCKET: ${S3_BUCKET}"
echo "  S3_KEY: ${S3_KEY}"

# TODO: Add Unity build logic here
echo "Unity build process placeholder - no operations performed yet"

echo "Unity Builder Container Completed"