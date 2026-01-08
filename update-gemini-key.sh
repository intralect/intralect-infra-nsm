#!/bin/bash

# Update Gemini API Key Script

echo "================================================"
echo "  Update Gemini API Key"
echo "================================================"
echo ""
echo "⚠️  Your current Gemini API key was leaked and blocked by Google."
echo ""
echo "Steps to fix:"
echo "1. Go to https://aistudio.google.com/app/apikey"
echo "2. Create a new API key"
echo "3. Copy the key"
echo "4. Paste it below when prompted"
echo ""
read -p "Enter your NEW Gemini API key: " NEW_KEY

if [ -z "$NEW_KEY" ]; then
    echo "❌ Error: No API key provided"
    exit 1
fi

echo ""
echo "Updating .env file..."
sed -i "s/GEMINI_API_KEY=.*/GEMINI_API_KEY=$NEW_KEY/" .env

echo "✅ API key updated in .env"
echo ""
echo "Restarting Strapi to apply changes..."
docker compose restart strapi

echo ""
echo "Waiting for Strapi to start (15 seconds)..."
sleep 15

echo ""
echo "✅ Done! Strapi has been restarted with the new API key."
echo ""
echo "Test it by:"
echo "1. Go to https://cms.yaicos.com/admin"
echo "2. Open an article"
echo "3. Try generating content again"
echo ""
