#!/bin/bash

# Setup script for buongiornissimo-bot
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ENV_FILE="${ENV_FILE:-.env}"

echo -e "${BLUE}🌅 Buongiornissimo Bot Setup${NC}"
echo -e "${BLUE}============================${NC}"
echo ""

# Check if .env already exists
if [[ -f "${ENV_FILE}" ]]; then
    echo -e "${YELLOW}⚠️  ${ENV_FILE} file already exists${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Setup cancelled. Existing ${ENV_FILE} preserved.${NC}"
        exit 0
    fi
fi

# Copy .env.example to .env
echo -e "${YELLOW}📁 Creating ${ENV_FILE} from template...${NC}"
cp .env.example "${ENV_FILE}"

echo -e "${GREEN}✅ ${ENV_FILE} file created${NC}"
echo ""

# Guide user through configuration
echo -e "${CYAN}📝 Now you need to configure your environment variables:${NC}"
echo ""

echo -e "${YELLOW}1. Telegram Bot Token:${NC}"
echo -e "   • Message @BotFather on Telegram"
echo -e "   • Create a new bot with /newbot"
echo -e "   • Copy the bot token"
echo ""

echo -e "${YELLOW}2. Telegram Chat IDs:${NC}"
echo -e "   • Add your bot to the desired chats/groups"
echo -e "   • Send a message to the bot in each chat"
echo -e "   • Visit: https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
echo -e "   • Look for 'chat.id' values in the response"
echo -e "   • Use negative IDs for groups, positive for direct messages"
echo ""

echo -e "${YELLOW}3. Google Gemini API Key:${NC}"
echo -e "   • Go to: https://aistudio.google.com/"
echo -e "   • Create a new API key"
echo -e "   • Ensure you have access to Gemini and Imagen models"
echo ""

echo -e "${CYAN}📝 Edit the ${ENV_FILE} file with your actual values:${NC}"
echo -e "${YELLOW}   nano ${ENV_FILE}${NC}"
echo -e "${YELLOW}   # or use your preferred editor${NC}"
echo ""

echo -e "${CYAN}🚀 After configuration, you can:${NC}"
echo -e "${GREEN}   • Test locally:          scripts/test-local.sh${NC}"
echo -e "${GREEN}   • Run locally:           scripts/run-local.sh${NC}"
echo -e "${GREEN}   • Build container image: scripts/build.sh${NC}"
echo -e "${GREEN}   • Run container locally: scripts/run-container.sh${NC}"
echo ""

echo -e "${BLUE}🎉 Setup complete! Don't forget to edit ${ENV_FILE}${NC}"
