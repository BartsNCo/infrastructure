#!/bin/bash
export AWS_PROFILE=barts-admin

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
S3_OUTPUT_BUCKET='development-unity-builds-20250730233014807900000001'

echo -e "${GREEN}Unity Builder Local Test${NC}"
echo "================================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Check if AWS credentials exist
if [ ! -d "$HOME/.aws" ]; then
    echo -e "${RED}Error: AWS credentials not found at $HOME/.aws${NC}"
    echo "Please configure AWS credentials first: aws configure"
    exit 1
fi

# Get the image name (you'll need to update this with your ECR URL)
DOCKER_IMAGE=${1:-"641564157514.dkr.ecr.us-east-1.amazonaws.com/development-unity-builder:latest"}

echo -e "${YELLOW}Using Docker image: $DOCKER_IMAGE${NC}"
echo ""

# Sample environment variables (you can modify these for testing)
SAMPLE_PANOS_JSON='[{"tourId":"6882733cd1e45d6f0c587ab3","panoId":"68827360d1e45d6f0c587ae7","unityUrl":"image/7335df4b-a92f-4bad-bf01-e9cb83438f8a"},{"tourId":"6882733cd1e45d6f0c587ab3","panoId":"6882737ed1e45d6f0c587aed","unityUrl":"image/7c039b71-8bb4-47ef-8c02-dbb55f91c561"},{"tourId":"68892f2903b5985a9d6511d4","panoId":"68892f8103b5985a9d65121f","unityUrl":"image/1b98a91b-4bd0-47ca-8881-d5edcec67d8d"},{"tourId":"68892f2903b5985a9d6511d4","panoId":"68892fca03b5985a9d651225","unityUrl":"image/26a16623-f20c-46a5-8ac3-eff0b3a83bc6"},{"tourId":"68892f2903b5985a9d6511d4","panoId":"6889301003b5985a9d65122d","unityUrl":"image/45847a9f-18e7-43a9-970a-13c052a56a2a"},{"tourId":"689625521b5bada561ea91f9","panoId":"6896258f1b5bada561ea9240","unityUrl":"image/5b808ed9-d6aa-4776-b18b-02b6f8c20c9f"},{"tourId":"6896094e1b5bada561ea9023","panoId":"689613511b5bada561ea90be","unityUrl":"image/2ce6c3bd-44fa-4457-a1ee-35bd2025c757"},{"tourId":"68920c3c8afa7f51ff58db60","panoId":"689210448afa7f51ff58db8a","unityUrl":"image/f313e298-85f2-43ab-848f-22c1e4061172"},{"tourId":"68920c3c8afa7f51ff58db60","panoId":"68921cd237a9eb7c7a5d0485","unityUrl":"image/eecfb0e2-15ae-46d9-888a-c085c82ebd4d"},{"tourId":"686b27113d3c9e3d48f3836d","panoId":"689354a937a9eb7c7a5d25fe","unityUrl":"image/c0ebbda9-d91d-4de3-94a2-98bef44d438c"},{"tourId":"686b27113d3c9e3d48f3836d","panoId":"6893552537a9eb7c7a5d2610","unityUrl":"image/894f78b1-2a5b-42d9-a616-e829229cb14f"},{"tourId":"686b27113d3c9e3d48f3836d","panoId":"6893588937a9eb7c7a5d261b","unityUrl":"image/26626fb9-7c57-413e-ae4b-5bea66b62aa9"},{"tourId":"686b27113d3c9e3d48f3836d","panoId":"6893596a37a9eb7c7a5d2631","unityUrl":"image/cc43558d-2fe5-4b35-b06e-46d5683ee2e9"},{"tourId":"686b27113d3c9e3d48f3836d","panoId":"6893599a37a9eb7c7a5d2642","unityUrl":"image/e5bb9000-d178-4af3-b42c-3557dee081b1"},{"tourId":"6894b1b337a9eb7c7a5d414b","panoId":"6894b1f737a9eb7c7a5d41ba","unityUrl":"image/18dee44b-a863-44e2-a5ee-ecd55635a84f"},{"tourId":"6894b1b337a9eb7c7a5d414b","panoId":"6894b21c37a9eb7c7a5d41c2","unityUrl":"image/e9d2135e-f56a-4b4c-bf1b-fe138546577a"},{"tourId":"6894b1b337a9eb7c7a5d414b","panoId":"6894b25a37a9eb7c7a5d41cd","unityUrl":"image/09d89eac-d490-4a44-8150-8d5b9e1b4a6f"},{"tourId":"6894b1b337a9eb7c7a5d414b","panoId":"6894b29c37a9eb7c7a5d41db","unityUrl":"image/e061e3f2-8d97-4f35-9fc8-a7f569e0cf81"},{"tourId":"6894b1b337a9eb7c7a5d414b","panoId":"6894b2e337a9eb7c7a5d41ec","unityUrl":"image/06cf0060-2f14-441e-b50e-6a328be9b6e3"},{"tourId":"6893675537a9eb7c7a5d2b2c","panoId":"689367a837a9eb7c7a5d2bb7","unityUrl":"image/941fb16e-716d-496c-8dcb-936b9b4b45ce"},{"tourId":"6893675537a9eb7c7a5d2b2c","panoId":"689367ca37a9eb7c7a5d2bbd","unityUrl":"image/781175f0-daa3-4e94-9ae4-dc9c72767042"},{"tourId":"6893675537a9eb7c7a5d2b2c","panoId":"6893680d37a9eb7c7a5d2bcf","unityUrl":"image/0172c297-45a9-4e7f-8580-8a352c92676b"},{"tourId":"689628c828d90d96ddd1e6a8","panoId":"689628f128d90d96ddd1e6f6","unityUrl":"image/ba549718-0ed5-465e-a5f3-01ab41d36050"}]'

echo -e "${YELLOW}Test Environment Variables:${NC}"
echo "S3_BUCKET: bartsnco-main"
echo "S3_OUTPUT_BUCKET: ${S3_OUTPUT_BUCKET}"
echo "PANOS_COUNT: 1"
echo "AWS_DEFAULT_REGION: us-east-1"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:+[REDACTED]}"
echo "UNITY_USERNAME: ${UNITY_USERNAME:+[SET]}"
echo "UNITY_PASSWORD: ${UNITY_PASSWORD:+[SET]}"
echo "UNITY_SERIAL: ${UNITY_SERIAL:+[SET]}"
echo ""
echo -e "${YELLOW}Sample Panos JSON:${NC}"
echo "$SAMPLE_PANOS_JSON" | jq '.'
echo ""

read -p "Press Enter to start the container..."
docker rm test-android
# Run the Docker container with AWS credentials mounted
echo -e "${GREEN}Starting Unity Builder container...${NC}"
docker run --name test-android -it \
  -v "$HOME/.aws:/root/.aws:ro" \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e AWS_PROFILE="${AWS_PROFILE}" \
  -e S3_BUCKET=bartsnco-main \
  -e S3_OUTPUT_BUCKET="${S3_OUTPUT_BUCKET}" \
  -e PANOS_JSON="$SAMPLE_PANOS_JSON" \
  -e PANOS_COUNT=1 \
  -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
  -e UNITY_USERNAME="${UNITY_USERNAME}" \
  -e UNITY_PASSWORD="${UNITY_PASSWORD}" \
  -e UNITY_SERIAL="${UNITY_SERIAL}" \
  "$DOCKER_IMAGE"

echo ""
echo -e "${GREEN}Container execution completed!${NC}"
