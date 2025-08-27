#!/bin/bash

# Script to run the pre-built buongiornissimo-bot binary with environment variables from .env file
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BINARY_NAME="buongiornissimo-bot"
ENV_FILE="${ENV_FILE:-.env}"

echo -e "${BLUE}🚀 Buongiornissimo Bot - Local Run${NC}"
echo -e "${BLUE}==================================${NC}"

# Check if binary exists
if [[ ! -f "${BINARY_NAME}" ]]; then
    echo -e "${RED}Error: ${BINARY_NAME} binary not found${NC}"
    echo -e "${YELLOW}Please build it first:${NC}"
    echo -e "${YELLOW}  go build -o ${BINARY_NAME}${NC}"
    echo -e "${YELLOW}Or use the test script: scripts/test-local.sh${NC}"
    exit 1
fi

# Check if .env file exists
if [[ ! -f "${ENV_FILE}" ]]; then
    echo -e "${RED}Error: ${ENV_FILE} file not found${NC}"
    echo -e "${YELLOW}Please create a ${ENV_FILE} file based on .env.example:${NC}"
    echo -e "${YELLOW}  cp .env.example ${ENV_FILE}${NC}"
    echo -e "${YELLOW}  # Then edit ${ENV_FILE} with your actual values${NC}"
    exit 1
fi

# Load environment variables from .env file
echo -e "${YELLOW}📁 Loading environment from ${ENV_FILE}...${NC}"
set -o allexport
source "${ENV_FILE}"
set +o allexport

# Show loaded configuration (with sensitive data masked)
echo -e "${GREEN}✅ Environment loaded${NC}"
echo -e "  💬 Chat IDs: ${TELEGRAM_CHAT_IDS}"
echo ""

# Run the application
echo -e "${YELLOW}🚀 Running buongiornissimo-bot...${NC}"
echo -e "${BLUE}===================================== BOT OUTPUT =====================================${NC}"

./"${BINARY_NAME}"
exit_code=$?

echo -e "${BLUE}===================================================================================${NC}"

if [[ ${exit_code} -eq 0 ]]; then
    echo -e "${GREEN}✅ Bot execution completed successfully!${NC}"
    echo -e "${GREEN}🌅 Check your Telegram chats for the buongiornissimo image! ☕${NC}"
else
    echo -e "${RED}❌ Bot execution failed with exit code: ${exit_code}${NC}"
    echo -e "${YELLOW}Check the logs above for error details${NC}"
fi

echo -e "${BLUE}Done! 🎉${NC}"
