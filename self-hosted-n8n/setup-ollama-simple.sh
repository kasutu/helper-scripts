#!/bin/bash
# setup-ollama-simple.sh
# Simple script to install the smallest Ollama model after containers are deployed
# Run this after: docker-compose up -d

echo "Installing llama3.2:1b model..."
docker compose exec ollama ollama pull llama3.2:1b

echo "Listing installed models:"
docker compose exec ollama ollama list

echo "Setup complete!"