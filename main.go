package main

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"google.golang.org/genai"
)

// Config holds all environment configuration
type Config struct {
	TelegramBotToken string
	ChatIDs          []string
	AdminChatID      string
	GeminiAPIKey     string
	InitialPrompt    string
	TextModelID      string
	ImageModelID     string
	MessageCaption   string
}

// loadConfig reads configuration from environment variables
func loadConfig() (*Config, error) {
	botToken := os.Getenv("TELEGRAM_BOT_TOKEN")
	if botToken == "" {
		return nil, fmt.Errorf("TELEGRAM_BOT_TOKEN environment variable is required")
	}

	chatIDsStr := os.Getenv("TELEGRAM_CHAT_IDS")
	adminChatID := os.Getenv("TELEGRAM_ADMIN_CHAT_ID")

	// At least one of TELEGRAM_CHAT_IDS or TELEGRAM_ADMIN_CHAT_ID must be present
	if chatIDsStr == "" && adminChatID == "" {
		return nil, fmt.Errorf("at least one of TELEGRAM_CHAT_IDS or TELEGRAM_ADMIN_CHAT_ID environment variables is required")
	}

	geminiAPIKey := os.Getenv("GEMINI_API_KEY")
	if geminiAPIKey == "" {
		return nil, fmt.Errorf("GEMINI_API_KEY environment variable is required")
	}

	var chatIDs []string
	if chatIDsStr != "" {
		chatIDs = strings.Split(chatIDsStr, ",")
		for i, id := range chatIDs {
			chatIDs[i] = strings.TrimSpace(id)
		}
	}

	// Load configurable parameters with defaults
	initialPrompt := os.Getenv("INITIAL_PROMPT")
	if initialPrompt == "" {
		initialPrompt = "Genera un prompt per un immagine surreale stile buongiornissimo kaffee. Aggiungi il testo \"Buongiorno\". Ritorna solo il prompt senza altro testo."
	}

	textModelID := os.Getenv("TEXT_MODEL_ID")
	if textModelID == "" {
		textModelID = "gemini-2.5-flash-lite"
	}

	imageModelID := os.Getenv("IMAGE_MODEL_ID")
	if imageModelID == "" {
		imageModelID = "imagen-4.0-generate-001"
	}

	messageCaption := os.Getenv("MESSAGE_CAPTION")
	if messageCaption == "" {
		messageCaption = "Buongiornissimo ☕"
	}

	return &Config{
		TelegramBotToken: botToken,
		ChatIDs:          chatIDs,
		AdminChatID:      adminChatID,
		GeminiAPIKey:     geminiAPIKey,
		InitialPrompt:    initialPrompt,
		TextModelID:      textModelID,
		ImageModelID:     imageModelID,
		MessageCaption:   messageCaption,
	}, nil
}

// generateImagePrompt uses Gemini to generate a prompt for image generation
func generateImagePrompt(ctx context.Context, config *Config) (string, error) {
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey: config.GeminiAPIKey,
	})
	if err != nil {
		return "", fmt.Errorf("failed to create Gemini client: %w", err)
	}

	fullPrompt := config.InitialPrompt + ". Non includere generazione di testo nel prompt. Ritorna solo il prompt senza altro testo."

	content := genai.NewContentFromText(fullPrompt, genai.RoleUser)

	resp, err := client.Models.GenerateContent(ctx, config.TextModelID, []*genai.Content{content}, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate content: %w", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("no content generated")
	}

	// Extract text from the first part
	firstPart := resp.Candidates[0].Content.Parts[0]
	if firstPart.Text != "" {
		return firstPart.Text, nil
	}

	return "", fmt.Errorf("unexpected response format")
}

// truncateCaption ensures the caption doesn't exceed Telegram's 1024 character limit
func truncateCaption(caption string) string {
	const maxCaptionLength = 1024
	if len(caption) <= maxCaptionLength {
		return caption
	}

	// Truncate and add ellipsis
	truncated := caption[:maxCaptionLength-3]
	return truncated + "..."
}

// generateImage uses Google Imagen to generate an image from the prompt
func generateImage(ctx context.Context, config *Config, prompt string) ([]byte, error) {
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey: config.GeminiAPIKey,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create Gemini client: %w", err)
	}

	imageConfig := &genai.GenerateImagesConfig{
		NumberOfImages: 1,
	}

	fullPrompt := prompt + " Ritorna solo il prompt senza altro testo."

	resp, err := client.Models.GenerateImages(ctx, config.ImageModelID, fullPrompt, imageConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to generate image: %w", err)
	}

	if len(resp.GeneratedImages) == 0 {
		return nil, fmt.Errorf("no image generated")
	}

	// Get the first generated image
	generatedImage := resp.GeneratedImages[0]
	if generatedImage.Image != nil && len(generatedImage.Image.ImageBytes) > 0 {
		return generatedImage.Image.ImageBytes, nil
	}

	return nil, fmt.Errorf("no image data found in response")
}

// sendImageToChats sends the generated image to all configured Telegram chats
func sendImageToChats(ctx context.Context, config *Config, imageData []byte, fullPrompt string) error {
	bot, err := tgbotapi.NewBotAPI(config.TelegramBotToken)
	if err != nil {
		return fmt.Errorf("failed to create Telegram bot: %w", err)
	}

	// Send to regular chats
	for _, chatIDStr := range config.ChatIDs {
		chatID, err := strconv.ParseInt(chatIDStr, 10, 64)
		if err != nil {
			log.Printf("Invalid chat ID %s: %v", chatIDStr, err)
			continue
		}

		log.Printf("Sending image to chat: %d", chatID)

		// Create a fresh reader for each chat
		photoReader := bytes.NewReader(imageData)
		photoConfig := tgbotapi.NewPhoto(chatID, tgbotapi.FileReader{
			Name:   "buongiornissimo.jpg",
			Reader: photoReader,
		})
		photoConfig.Caption = truncateCaption(config.MessageCaption)

		_, err = bot.Send(photoConfig)
		if err != nil {
			log.Printf("Failed to send image to chat %d: %v", chatID, err)
			continue
		}

		log.Printf("Successfully sent image to chat: %d", chatID)
	}

	// Send to admin chat with full prompt
	if config.AdminChatID != "" {
		adminChatID, err := strconv.ParseInt(config.AdminChatID, 10, 64)
		if err != nil {
			log.Printf("Invalid admin chat ID %s: %v", config.AdminChatID, err)
		} else {
			log.Printf("Sending image to admin chat: %d", adminChatID)

			// Create a fresh reader for admin chat
			photoReader := bytes.NewReader(imageData)
			photoConfig := tgbotapi.NewPhoto(adminChatID, tgbotapi.FileReader{
				Name:   "buongiornissimo.jpg",
				Reader: photoReader,
			})
			caption := fmt.Sprintf("Generated with prompt: %s", fullPrompt)
			photoConfig.Caption = truncateCaption(caption)

			_, err = bot.Send(photoConfig)
			if err != nil {
				log.Printf("Failed to send image to admin chat %d: %v", adminChatID, err)
			} else {
				log.Printf("Successfully sent image to admin chat: %d", adminChatID)
			}
		}
	}

	return nil
}

// runBuongiornissimoBot executes the bot logic once
func runBuongiornissimoBot(ctx context.Context, config *Config) error {
	totalChats := len(config.ChatIDs)
	if config.AdminChatID != "" {
		totalChats++
	}
	log.Printf("Starting buongiornissimo bot for %d chats (%d regular + %d admin)", totalChats, len(config.ChatIDs), func() int {
		if config.AdminChatID != "" {
			return 1
		}
		return 0
	}())

	// Generate image prompt using Gemini
	prompt, err := generateImagePrompt(ctx, config)
	if err != nil {
		return fmt.Errorf("failed to generate image prompt: %w", err)
	}

	log.Printf("Generated prompt: %s", prompt)

	// Generate image using Imagen
	imageData, err := generateImage(ctx, config, prompt)
	if err != nil {
		return fmt.Errorf("failed to generate image: %w", err)
	}

	log.Printf("Generated image of %d bytes", len(imageData))

	// Send image to all chats
	err = sendImageToChats(ctx, config, imageData, prompt)
	if err != nil {
		return fmt.Errorf("failed to send images: %w", err)
	}

	log.Println("Successfully sent images to all chats")
	return nil
}

// HTTP handler for triggering the bot
func botHandler(config *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		ctx := r.Context()
		err := runBuongiornissimoBot(ctx, config)
		if err != nil {
			log.Printf("Bot execution failed: %v", err)
			http.Error(w, fmt.Sprintf("Bot execution failed: %v", err), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "Buongiornissimo bot executed successfully")
	}
}

// Health check handler
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

func main() {
	// Load configuration
	config, err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Determine if running in direct mode (for local testing) or HTTP mode (for Cloud Run)
	runMode := os.Getenv("RUN_MODE")

	if runMode == "direct" {
		// Direct execution mode (for local testing and Cloud Functions)
		ctx := context.Background()
		err := runBuongiornissimoBot(ctx, config)
		if err != nil {
			log.Fatalf("Bot execution failed: %v", err)
		}
		return
	}

	// HTTP server mode (for Cloud Run)
	totalChats := len(config.ChatIDs)
	if config.AdminChatID != "" {
		totalChats++
	}
	log.Printf("Starting buongiornissimo bot HTTP server for %d chats (%d regular + %d admin)", totalChats, len(config.ChatIDs), func() int {
		if config.AdminChatID != "" {
			return 1
		}
		return 0
	}())

	// Set up HTTP routes
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/", botHandler(config))

	// Get port from environment variable (required by Cloud Run)
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting HTTP server on port %s", port)
	log.Printf("Health check available at: http://localhost:%s/health", port)
	log.Printf("Bot trigger available at: http://localhost:%s/ (POST)", port)

	// Start the HTTP server
	err = http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatalf("HTTP server failed: %v", err)
	}
}
