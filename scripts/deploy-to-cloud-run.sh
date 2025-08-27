#!/bin/bash

# Script to run the buongiornissimo-bot container image locally with environment variables
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
ENV_FILE="${ENV_FILE:-.env}"

echo -e "${YELLOW}Deploying to Cloud Run${NC}"

# Check if .env file exists
if [[ ! -f "${ENV_FILE}" ]]; then
    echo -e "${RED}Error: ${ENV_FILE} file not found${NC}"
    echo -e "${YELLOW}Please create a ${ENV_FILE} file based on .env.example${NC}"
    echo -e "${YELLOW}cp .env.example ${ENV_FILE}${NC}"
    echo -e "${YELLOW}# Then edit ${ENV_FILE} with your actual values${NC}"
    exit 1
fi

# Load environment variables from .env file
echo -e "${YELLOW}📁 Loading environment from ${ENV_FILE}...${NC}"
set -o allexport
source "${ENV_FILE}"
set +o allexport

env

GC_REGION="${GC_REGION:-europe-west1}"

set -x
gcloud run deploy buongiornissimo-bot \
  --image "$GC_IMAGE_TAG" \
  --platform managed \
  --region "$GC_REGION" \
  --set-env-vars TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
  --set-env-vars TELEGRAM_CHAT_IDS="$TELEGRAM_CHAT_IDS" \
  --set-env-vars TELEGRAM_ADMIN_CHAT_ID="$TELEGRAM_ADMIN_CHAT_ID" \
  --set-env-vars GEMINI_API_KEY="$GEMINI_API_KEY" \
  --set-env-vars INITIAL_PROMPT="$INITIAL_PROMPT" \
  --set-env-vars TEXT_MODEL_ID="$TEXT_MODEL_ID" \
  --set-env-vars IMAGE_MODEL_ID="$IMAGE_MODEL_ID" \
  --set-env-vars MESSAGE_CAPTION="$MESSAGE_CAPTION" \
  --no-allow-unauthenticated

# Get the project ID
PROJECT_ID="${GC_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"

if [[ -z "$PROJECT_ID" ]]; then
    echo -e "${RED}Error: Could not determine PROJECT_ID${NC}"
    echo -e "${YELLOW}Please set GC_PROJECT_ID environment variable or configure default project:${NC}"
    echo -e "${YELLOW}  gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

# Create or get service account for scheduler authentication
SERVICE_ACCOUNT_NAME="buongiornissimo-scheduler"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${YELLOW}🔐 Setting up service account for authentication...${NC}"

# Check if service account exists
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo -e "${YELLOW}📝 Creating service account: ${SERVICE_ACCOUNT_EMAIL}${NC}"
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Buongiornissimo Bot Scheduler" \
        --description="Service account for Cloud Scheduler to invoke buongiornissimo-bot Cloud Run service" \
        --project="$PROJECT_ID"

    # Grant Cloud Run Invoker role to the service account
    echo -e "${YELLOW}🔑 Granting Cloud Run Invoker permissions...${NC}"
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="roles/run.invoker" \
        --quiet
else
    echo -e "${GREEN}✅ Service account already exists: ${SERVICE_ACCOUNT_EMAIL}${NC}"
fi
