#!/bin/bash

# Build script for buongiornissimo-bot Docker image
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect container runtime (prefer podman over docker)
detect_container_runtime() {
    if command -v podman >/dev/null 2>&1; then
        echo "podman"
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"
    else
        echo ""
    fi
}

CONTAINER_RUNTIME=$(detect_container_runtime)
if [[ -z "$CONTAINER_RUNTIME" ]]; then
    echo -e "${RED}Error: Neither podman nor docker found${NC}"
    echo -e "${YELLOW}Please install podman or docker to build container images${NC}"
    exit 1
fi

# Configuration
IMAGE_NAME="buongiornissimo-bot"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${YELLOW}Building container image using ${CONTAINER_RUNTIME}: ${FULL_IMAGE_NAME}${NC}"

# Check if Dockerfile exists
if [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}Error: Dockerfile not found in current directory${NC}"
    exit 1
fi

# Build the container image
echo -e "${YELLOW}Running ${CONTAINER_RUNTIME} build...${NC}"
${CONTAINER_RUNTIME} build -t "${FULL_IMAGE_NAME}" .

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Successfully built container image: ${FULL_IMAGE_NAME}${NC}"
    
    # Show image size
    echo -e "${YELLOW}Image size:${NC}"
    ${CONTAINER_RUNTIME} images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || \
    ${CONTAINER_RUNTIME} images "${IMAGE_NAME}"
    
    echo ""
    echo -e "${GREEN}To run the image locally:${NC}"
    echo -e "  ${YELLOW}scripts/run-container.sh${NC}"
    echo ""
    echo -e "${GREEN}To push to a registry:${NC}"
    if [[ "$CONTAINER_RUNTIME" == "podman" ]]; then
        echo -e "  ${YELLOW}podman tag ${FULL_IMAGE_NAME} gcr.io/YOUR_PROJECT_ID/${IMAGE_NAME}${NC}"
        echo -e "  ${YELLOW}podman push gcr.io/YOUR_PROJECT_ID/${IMAGE_NAME}${NC}"
    else
        echo -e "  ${YELLOW}docker tag ${FULL_IMAGE_NAME} gcr.io/YOUR_PROJECT_ID/${IMAGE_NAME}${NC}"
        echo -e "  ${YELLOW}docker push gcr.io/YOUR_PROJECT_ID/${IMAGE_NAME}${NC}"
    fi
else
    echo -e "${RED}❌ Failed to build container image${NC}"
    exit 1
fi
