# Buongiornissimo Bot

A Telegram bot written in Go that generates daily "buongiornissimo" images using Google Gemini and Imagen APIs.

## Overview

This bot is designed to run once daily via Google Cloud Scheduler. It:

1. Uses Google Gemini's `gemini-2.5-flash-lite` model to generate an Italian-style "buongiornissimo kaffee" image prompt
2. Uses Google's `imagen-4.0-generate-001` model to generate an image based on that prompt
3. Sends the generated image to all configured Telegram chats

## Prerequisites

- Go 1.21 or later
- Google Cloud account with access to Gemini and Imagen APIs
- Telegram Bot Token
- Google Gemini API Key

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/kostola/buongiornissimo-bot
cd buongiornissimo-bot
scripts/setup.sh  # Creates .env file and shows configuration guide
```

### 2. Configure Environment

Edit the `.env` file with your actual values:
```bash
nano .env  # or use your preferred editor
```

### 3. Test Locally

```bash
scripts/test-local.sh  # Builds and runs the bot locally
```

## Setup

### 2. Create a Telegram Bot

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Create a new bot with `/newbot`
3. Save the bot token

### 3. Get Chat IDs

To find your chat IDs:
1. Add your bot to the desired chats/groups
2. Send a message to the bot
3. Visit `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Look for the `chat.id` values in the response

### 4. Get Google Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/)
2. Create a new API key
3. Ensure you have access to both Gemini and Imagen models

## Environment Variables

The bot requires the following environment variables:

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `TELEGRAM_BOT_TOKEN` | Your Telegram bot token | `1234567890:ABC...` |
| `GEMINI_API_KEY` | Your Google Gemini API key | `AIza...` |

### Chat Configuration (At least one required)

| Variable | Description | Example |
|----------|-------------|---------|
| `TELEGRAM_CHAT_IDS` | Comma-separated list of chat IDs for regular messages | `-1001234567890,-1001234567891` |
| `TELEGRAM_ADMIN_CHAT_ID` | Admin chat ID that receives images with full prompts | `123456789` |

**Note**: At least one of `TELEGRAM_CHAT_IDS` or `TELEGRAM_ADMIN_CHAT_ID` must be configured for the bot to start.

#### Admin Chat Functionality

The `TELEGRAM_ADMIN_CHAT_ID` feature allows you to receive additional information about generated images:

- **Regular chats** (`TELEGRAM_CHAT_IDS`): Receive images with the standard caption (customizable via `MESSAGE_CAPTION`)
- **Admin chat** (`TELEGRAM_ADMIN_CHAT_ID`): Receives the same image but with the **full prompt** used for generation as the caption

This is useful for:
- Monitoring what prompts are being generated
- Debugging image generation issues
- Understanding how the AI interprets your initial prompts
- Keeping a record of successful prompt patterns

### Optional Variables (with defaults)

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `INITIAL_PROMPT` | Prompt sent to text model for generating image prompts | `"Genera un prompt per un immagine surreale stile buongiornissimo kaffee..."` |
| `TEXT_MODEL_ID` | Model ID for text generation (prompt creation) | `gemini-2.5-flash-lite` |
| `IMAGE_MODEL_ID` | Model ID for image generation | `imagen-4.0-generate-001` |
| `MESSAGE_CAPTION` | Caption text added to sent images | `Buongiornissimo ☕` |

### Customization Examples

You can customize the bot's behavior by setting these optional environment variables:

```bash
# Use English prompts and messages
INITIAL_PROMPT="Generate a prompt for a surreal good morning coffee-style image. Add the text 'Good Morning'. Return only the prompt without any other text."
MESSAGE_CAPTION="Good Morning! ☕"

# Use different AI models
TEXT_MODEL_ID="gemini-1.5-pro"
IMAGE_MODEL_ID="imagen-3.0"

# Create themed variations
INITIAL_PROMPT="Create a cyberpunk-style morning coffee image prompt with neon colors"
MESSAGE_CAPTION="🌆 Cyber Morning! ⚡☕"

# Admin-only setup (no regular chats)
TELEGRAM_ADMIN_CHAT_ID=123456789
# Leave TELEGRAM_CHAT_IDS empty or unset

# Mixed setup (both regular chats and admin monitoring)
TELEGRAM_CHAT_IDS=-1001234567890,-1001234567891
TELEGRAM_ADMIN_CHAT_ID=987654321
```

## Available Scripts

The project includes several convenience scripts for development and deployment:

### Local Development

| Script | Description |
|--------|-------------|
| `scripts/setup.sh` | Initial setup - creates `.env` file and shows configuration guide |
| `scripts/test-local.sh` | Build and test the bot locally (loads from `.env` file) |
| `scripts/run-local.sh` | Run pre-built binary locally (loads from `.env` file) |

### Container (Docker/Podman)

| Script | Description |
|--------|-------------|
| `scripts/build.sh` | Build container image for the bot (supports both podman and docker) |
| `scripts/run-container.sh` | Run container locally (loads from `.env` file, supports both podman and docker) |

### Deployment

| Script | Description |
|--------|-------------|
| `scripts/deploy-to-cloud-run.sh` | Deploy to Google Cloud Run with environment configuration |
| `scripts/create-scheduler-job.sh` | Create Google Cloud Scheduler job for daily execution |

### Environment File

The project uses a `.env` file for local development:
- Copy `.env.example` to `.env`
- Edit with your actual API keys and chat IDs
- The `.env` file is automatically excluded from git

### Container Runtime Support

The scripts automatically detect and prefer **Podman** over Docker:
- If Podman is installed, it will be used
- If only Docker is available, it will be used as fallback
- If neither is found, the scripts will display helpful error messages

Both `build.sh` and `run-container.sh` support this auto-detection.

## Running Locally

### Method 1: Using Scripts (Recommended)

```bash
scripts/setup.sh      # First time setup
scripts/test-local.sh # Build and run
```

### Method 2: Manual

```bash
export TELEGRAM_BOT_TOKEN="your_bot_token_here"
export TELEGRAM_CHAT_IDS="chat_id_1,chat_id_2"
export GEMINI_API_KEY="your_gemini_api_key_here"

go build -o buongiornissimo-bot
./buongiornissimo-bot
```

## Deployment to Google Cloud

### Cloud Run + Cloud Scheduler

1. **Create a service account and assign roles:**

```bash
# Create service account
gcloud iam service-accounts create buongiornissimo-bot \
  --display-name="Buongiornissimo Bot Service Account" \
  --description="Service account for the Buongiornissimo Telegram Bot"

# Assign necessary roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:buongiornissimo-bot@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:buongiornissimo-bot@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

2. **Build and push container image:**

```bash
# Build locally first (optional, for testing)
scripts/build.sh

# Build and push to Google Container Registry
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/buongiornissimo-bot
```

3. **Deploy to Cloud Run:**

```bash
gcloud run deploy buongiornissimo-bot \
  --image gcr.io/YOUR_PROJECT_ID/buongiornissimo-bot \
  --platform managed \
  --region YOUR_REGION \
  --service-account=buongiornissimo-bot@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --set-env-vars TELEGRAM_BOT_TOKEN="your_bot_token" \
  --set-env-vars TELEGRAM_CHAT_IDS="chat_id_1,chat_id_2" \
  --set-env-vars TELEGRAM_ADMIN_CHAT_ID="admin_chat_id" \
  --set-env-vars GEMINI_API_KEY="your_gemini_api_key" \
  --set-env-vars INITIAL_PROMPT="your_custom_prompt" \
  --set-env-vars TEXT_MODEL_ID="gemini-2.5-flash-lite" \
  --set-env-vars IMAGE_MODEL_ID="imagen-4.0-generate-001" \
  --set-env-vars MESSAGE_CAPTION="Buongiornissimo ☕" \
  --no-allow-unauthenticated
```

4. **Create Cloud Scheduler job:**

```bash
gcloud scheduler jobs create http buongiornissimo-daily \
  --schedule="0 8 * * *" \
  --uri="https://YOUR_CLOUD_RUN_URL" \
  --http-method=POST \
  --oidc-service-account-email=buongiornissimo-bot@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --time-zone="Europe/Rome"
```

## Security Considerations

- Store sensitive environment variables using Google Secret Manager
- Use service accounts with minimal required permissions
- Consider using VPC for additional network security
- Regularly rotate API keys

## Troubleshooting

### Common Issues

1. **"Invalid chat ID" errors**: Ensure chat IDs are correct and the bot has been added to those chats
2. **Gemini API errors**: Check your API key and ensure you have access to the required models
3. **Image generation failures**: Verify you have access to Imagen and check API quotas

### Logs

Check logs using:
```bash
# Cloud Run
gcloud logs read --service=buongiornissimo-bot

# Cloud Functions  
gcloud logs read --filter="resource.type=cloud_function AND resource.labels.function_name=buongiornissimo"
```

## Development

### Project Structure

```
buongiornissimo-bot/
├── main.go                       # Main application code
├── go.mod                        # Go module dependencies
├── go.sum                        # Go module checksums
├── Dockerfile                    # Container build configuration
├── LICENSE                       # MIT License file
├── README.md                     # This file
└── scripts/                      # Development and deployment scripts
    ├── setup.sh                  # Initial setup script
    ├── test-local.sh             # Build and test locally
    ├── run-local.sh              # Run pre-built binary locally
    ├── build.sh                  # Build container image (podman/docker)
    ├── run-container.sh          # Run container locally (podman/docker)
    ├── create-scheduler-job.sh   # Create Google Cloud Scheduler job
    └── deploy-to-cloud-run.sh    # Deploy to Google Cloud Run
```

### Key Functions

- `loadConfig()`: Loads environment variables
- `generateImagePrompt()`: Uses Gemini to create image prompts
- `generateImage()`: Uses Imagen to create images
- `sendImageToChats()`: Sends images via Telegram

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues and questions, please create an issue in the GitHub repository.
