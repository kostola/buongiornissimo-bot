#!/bin/bash

# Script to build and test the buongiornissimo-bot locally with environment variables from .env file
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

echo -e "${BLUE}🚀 Buongiornissimo Bot - Local Test${NC}"
echo -e "${BLUE}====================================${NC}"

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

# Validate required environment variables
required_vars=("TELEGRAM_BOT_TOKEN" "TELEGRAM_CHAT_IDS" "GEMINI_API_KEY")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("${var}")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "${RED}  - ${var}${NC}"
    done
    echo -e "${YELLOW}Please update your ${ENV_FILE} file${NC}"
    exit 1
fi

# Show loaded configuration (with sensitive data masked)
echo -e "${GREEN}✅ Environment loaded successfully:${NC}"
echo -e "  📧 Telegram Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}...${TELEGRAM_BOT_TOKEN: -10}"
echo -e "  💬 Chat IDs: ${TELEGRAM_CHAT_IDS}"
echo -e "  🤖 Gemini API Key: ${GEMINI_API_KEY:0:10}...${GEMINI_API_KEY: -10}"
echo ""

# Build the application
echo -e "${YELLOW}🔨 Building application...${NC}"
go build -o "${BINARY_NAME}"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

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

# Clean up
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
rm -f "${BINARY_NAME}"

echo -e "${BLUE}Done! 🎉${NC}"
