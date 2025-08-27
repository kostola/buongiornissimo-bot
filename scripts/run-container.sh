#!/bin/bash

# Script to run the buongiornissimo-bot container image locally with environment variables
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
    echo -e "${YELLOW}Please install podman or docker to run container images${NC}"
    exit 1
fi

# Configuration
IMAGE_NAME="buongiornissimo-bot"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
ENV_FILE="${ENV_FILE:-.env}"

echo -e "${YELLOW}Running container using ${CONTAINER_RUNTIME}: ${FULL_IMAGE_NAME}${NC}"

# Check if .env file exists
if [[ ! -f "${ENV_FILE}" ]]; then
    echo -e "${RED}Error: ${ENV_FILE} file not found${NC}"
    echo -e "${YELLOW}Please create a ${ENV_FILE} file based on .env.example${NC}"
    echo -e "${YELLOW}cp .env.example ${ENV_FILE}${NC}"
    echo -e "${YELLOW}# Then edit ${ENV_FILE} with your actual values${NC}"
    exit 1
fi

# Check if container image exists
if ! ${CONTAINER_RUNTIME} images "${IMAGE_NAME}" | grep -q "${IMAGE_TAG}"; then
    echo -e "${RED}Error: Container image ${FULL_IMAGE_NAME} not found${NC}"
    echo -e "${YELLOW}Please build the image first: scripts/build.sh${NC}"
    exit 1
fi

# Run the container
echo -e "${YELLOW}Loading environment from ${ENV_FILE}...${NC}"
echo -e "${YELLOW}Starting container...${NC}"

${CONTAINER_RUNTIME} run --rm \
    --env-file "${ENV_FILE}" \
    "${FULL_IMAGE_NAME}"

echo -e "${GREEN}✅ Container execution completed${NC}"
