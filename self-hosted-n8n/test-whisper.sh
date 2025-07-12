#!/bin/bash
# test-whisper.sh
# Test script to verify the local Whisper service is working

echo "Testing local Whisper service..."

# Check if Whisper container is running
if ! docker compose ps whisper | grep -q "Up"; then
    echo "❌ Whisper container is not running. Start it with: docker compose up -d whisper"
    exit 1
fi

echo "✅ Whisper container is running"

# Test the Whisper API endpoint
echo "Testing Whisper API endpoint..."
if curl -f http://localhost:9000/docs > /dev/null 2>&1; then
    echo "✅ Whisper API is accessible at http://localhost:9000"
    echo "📖 API documentation available at: http://localhost:9000/docs"
else
    echo "❌ Whisper API is not accessible. Check container logs with: docker compose logs whisper"
    exit 1
fi

# Test with a sample audio file (if you have one)
echo ""
echo "To test with an actual audio file, use:"
echo "curl -X POST -F 'audio_file=@your_audio.wav' -F 'task=transcribe' -F 'language=en' -F 'output=json' http://localhost:9000/asr"

echo ""
echo "✅ Whisper service test completed successfully!"
