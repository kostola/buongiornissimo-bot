#!/bin/bash

# Script to create a Google Cloud Scheduler job for buongiornissimo-bot
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check command line arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: Cloud Run service URL is required${NC}"
    echo -e "${YELLOW}Usage: $0 <CLOUD_RUN_URL> [PROJECT_ID] [REGION]${NC}"
    echo -e "${YELLOW}Example: $0 https://buongiornissimo-bot-abc123-ew.a.run.app${NC}"
    echo -e "${YELLOW}Example: $0 https://buongiornissimo-bot-abc123-ew.a.run.app my-project europe-west1${NC}"
    echo -e "${YELLOW}Note: Default region is europe-west1 (change if your Cloud Run service is in a different region)${NC}"
    exit 1
fi

# Configuration
CLOUD_RUN_URL="$1"
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
REGION="${GC_REGION:-europe-west1}"
ENV_FILE="${ENV_FILE:-.env}"
JOB_NAME="buongiornissimo-bot-scheduler"
SCHEDULE="${2:-*/2 * * * *}"  # Every 2 minutes

echo -e "${BLUE}🚀 Creating Google Cloud Scheduler Job${NC}"
echo -e "${BLUE}====================================${NC}"

# Validate inputs
if [[ -z "$PROJECT_ID" ]]; then
    echo -e "${RED}Error: Could not determine PROJECT_ID${NC}"
    echo -e "${YELLOW}Please provide PROJECT_ID as second argument or set default project:${NC}"
    echo -e "${YELLOW}  gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

if [[ ! "$CLOUD_RUN_URL" =~ ^https?:// ]]; then
    echo -e "${RED}Error: Invalid URL format. URL must start with http:// or https://${NC}"
    exit 1
fi

# Valid regions for Cloud Scheduler
VALID_REGIONS=(
    "asia-east1" "asia-east2" "asia-northeast1" "asia-northeast2" "asia-northeast3"
    "asia-south1" "asia-southeast1" "asia-southeast2"
    "australia-southeast1"
    "europe-north1" "europe-west1" "europe-west2" "europe-west3" "europe-west4" "europe-west6"
    "northamerica-northeast1"
    "southamerica-east1"
    "us-central1" "us-east1" "us-east4" "us-west1" "us-west2" "us-west3" "us-west4"
)

# Validate region
if [[ ! " ${VALID_REGIONS[*]} " =~ " ${REGION} " ]]; then
    echo -e "${RED}Error: '${REGION}' is not a valid Cloud Scheduler region${NC}"
    echo -e "${YELLOW}Valid regions include:${NC}"
    echo -e "${YELLOW}  Europe: europe-west1, europe-west2, europe-west3, europe-west4, europe-west6, europe-north1${NC}"
    echo -e "${YELLOW}  US: us-central1, us-east1, us-east4, us-west1, us-west2, us-west3, us-west4${NC}"
    echo -e "${YELLOW}  Asia: asia-east1, asia-east2, asia-northeast1, asia-southeast1, asia-south1${NC}"
    echo -e "${YELLOW}  Other: australia-southeast1, northamerica-northeast1, southamerica-east1${NC}"
    echo ""
    echo -e "${YELLOW}Usage: $0 <CLOUD_RUN_URL> [PROJECT_ID] [REGION]${NC}"
    echo -e "${YELLOW}Example: $0 https://my-service.a.run.app my-project europe-west1${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  📍 Cloud Run URL: ${CLOUD_RUN_URL}"
echo -e "  🏗️  Project ID: ${PROJECT_ID}"
echo -e "  🌍 Region: ${REGION}"
echo -e "  ⏰ Schedule: ${SCHEDULE} (every 2 minutes)"
echo -e "  💼 Job Name: ${JOB_NAME}"
echo ""

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

# Validate required environment variables
required_vars=("TELEGRAM_BOT_TOKEN" "GEMINI_API_KEY")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("${var}")
    fi
done

# Check that at least one chat configuration exists
if [[ -z "$TELEGRAM_CHAT_IDS" && -z "$TELEGRAM_ADMIN_CHAT_ID" ]]; then
    missing_vars+=("TELEGRAM_CHAT_IDS or TELEGRAM_ADMIN_CHAT_ID")
fi

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "${RED}  - ${var}${NC}"
    done
    echo -e "${YELLOW}Please update your ${ENV_FILE} file${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables loaded successfully${NC}"

# Check if gcloud CLI is available
if ! command -v gcloud >/dev/null 2>&1; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    echo -e "${YELLOW}Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install${NC}"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}Error: Not authenticated with gcloud${NC}"
    echo -e "${YELLOW}Please run: gcloud auth login${NC}"
    exit 1
fi

# Enable required APIs
echo -e "${YELLOW}🔧 Ensuring required APIs are enabled...${NC}"
gcloud services enable cloudscheduler.googleapis.com --project="$PROJECT_ID" --quiet
gcloud services enable run.googleapis.com --project="$PROJECT_ID" --quiet

# Create or get service account for scheduler authentication
SERVICE_ACCOUNT_NAME="buongiornissimo-scheduler"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Check if job already exists
if gcloud scheduler jobs describe "$JOB_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Job ${JOB_NAME} already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Deleting existing job...${NC}"
        gcloud scheduler jobs delete "$JOB_NAME" --location="$REGION" --project="$PROJECT_ID" --quiet
    else
        echo -e "${YELLOW}Cancelled. Existing job preserved.${NC}"
        exit 0
    fi
fi

# Create the scheduler job
echo -e "${YELLOW}📅 Creating scheduler job with authentication...${NC}"

gcloud scheduler jobs create http "$JOB_NAME" \
    --location="$REGION" \
    --schedule="$SCHEDULE" \
    --uri="$CLOUD_RUN_URL" \
    --http-method=POST \
    --headers="Content-Type=application/json" \
    --message-body='{"trigger":"scheduler"}' \
    --time-zone="Europe/Rome" \
    --oidc-service-account-email="$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Successfully created authenticated scheduler job!${NC}"
    echo ""
    echo -e "${GREEN}📋 Job Details:${NC}"
    echo -e "  🏷️  Name: ${JOB_NAME}"
    echo -e "  ⏰ Schedule: Every 2 minutes"
    echo -e "  🎯 Target: ${CLOUD_RUN_URL}"
    echo -e "  🌍 Region: ${REGION}"
    echo -e "  🔐 Service Account: ${SERVICE_ACCOUNT_EMAIL}"
    echo ""
    echo -e "${GREEN}🎛️  Management Commands:${NC}"
    echo -e "${YELLOW}  # View job details${NC}"
    echo -e "  gcloud scheduler jobs describe ${JOB_NAME} --location=${REGION}"
    echo ""
    echo -e "${YELLOW}  # Pause the job${NC}"
    echo -e "  gcloud scheduler jobs pause ${JOB_NAME} --location=${REGION}"
    echo ""
    echo -e "${YELLOW}  # Resume the job${NC}"
    echo -e "  gcloud scheduler jobs resume ${JOB_NAME} --location=${REGION}"
    echo ""
    echo -e "${YELLOW}  # Trigger manually${NC}"
    echo -e "  gcloud scheduler jobs run ${JOB_NAME} --location=${REGION}"
    echo ""
    echo -e "${YELLOW}  # Delete the job${NC}"
    echo -e "  gcloud scheduler jobs delete ${JOB_NAME} --location=${REGION}"
    echo ""
    echo -e "${YELLOW}  # View service account details${NC}"
    echo -e "  gcloud iam service-accounts describe ${SERVICE_ACCOUNT_EMAIL}"
    echo ""
    echo -e "${GREEN}🎉 Your buongiornissimo bot will now run every 2 minutes with proper authentication!${NC}"
else
    echo -e "${RED}❌ Failed to create scheduler job${NC}"
    exit 1
fi
