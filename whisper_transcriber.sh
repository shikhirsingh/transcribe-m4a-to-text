#!/bin/bash

# Colors for messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 0: Function to check if Docker is running
check_docker_running() {
  if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
  fi

  if ! pgrep -f 'Docker.app' > /dev/null 2>&1; then
    echo -e "${RED}Docker desktop is not running. Please ensure Docker is running on your system.${NC}"
    exit 1
  fi
}

# Step 0: Ensure Docker is running
check_docker_running

echo "Step 1: Validating input file and setting up directories..."

# Step 1: Check if input file is provided
if [ -z "$1" ]; then
  echo -e "${YELLOW}Usage: $0 <input_file.m4a>${NC}"
  exit 1
fi

# Step 1.1: Variables
INPUT_FILE="$1"
OUTPUT_FILE="to-file.wav"
WHISPER_PORT=9000
TIMESTAMP=$(date +"%y%m%d")
RESULT_DIR="transcribe-$TIMESTAMP"
WORKING_DIR="$RESULT_DIR/working-files"
TRANSCRIBED_DIR="$RESULT_DIR/transcribed-output"

# Function to find an available port starting from 9000
find_available_port() {
  PORT=9000
  while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; do
    PORT=$((PORT + 1))
  done
  echo $PORT
}

# Step 1.2: Find an available port
WHISPER_PORT=$(find_available_port)

# Step 1.3: Ensure directories exist
mkdir -p "$WORKING_DIR"
mkdir -p "$TRANSCRIBED_DIR"

# Step 1.4: Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo -e "${RED}Error: Input file '$INPUT_FILE' does not exist.${NC}"
  exit 1
fi

# Step 1.5: Check if input file is greater than 10KB
if [ $(stat -c%s "$INPUT_FILE") -le 10240 ]; then
  echo -e "${RED}Error: Input file '$INPUT_FILE' is too small (must be greater than 10KB).${NC}"
  exit 1
fi

# Step 1.6: Check if input file has correct format (m4a)
if [[ "$INPUT_FILE" != *.m4a ]]; then
  echo -e "${RED}Error: Input file '$INPUT_FILE' is not an m4a file.${NC}"
  exit 1
fi

# Step 2: Convert m4a to wav using ffmpeg in Docker
echo "Step 2: Converting $INPUT_FILE to WAV format. This may take a few moments..."
docker run --rm -v "$(pwd)":/tmp -w /tmp jrottenberg/ffmpeg -i "$INPUT_FILE" "$OUTPUT_FILE"

if [ $? -ne 0 ]; then
  echo -e "${RED}Error during audio conversion.${NC}"
  exit 1
fi

mv "$OUTPUT_FILE" "$WORKING_DIR/"
OUTPUT_FILE="$WORKING_DIR/to-file.wav"

echo -e "${GREEN}Conversion complete. Output file: $OUTPUT_FILE${NC}"

# Step 3: Start Whisper ASR web service in Docker (if not already running)
echo "Step 3: Ensuring Whisper ASR web service is running on port $WHISPER_PORT..."
if ! docker ps | grep -q "openai-whisper-asr-webservice"; then
  echo "Starting Whisper ASR web service on port $WHISPER_PORT..."
  docker run -d -p $WHISPER_PORT:9000 -e ASR_MODEL=base -e ASR_ENGINE=openai_whisper onerahmet/openai-whisper-asr-webservice:latest

  # Wait a few seconds to ensure the service is up
  echo "Waiting for Whisper ASR web service to start..."
  sleep 5

  if ! docker ps | grep -q "openai-whisper-asr-webservice"; then
    echo -e "${RED}Failed to start Whisper ASR web service.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}Whisper ASR web service is running on port $WHISPER_PORT.${NC}"

# Step 4: Transcribe the WAV file using curl
echo "Step 4: Uploading $OUTPUT_FILE to Whisper service for transcription. You will see progress as the file uploads."
curl --progress-bar -F "audio_file=@$OUTPUT_FILE" -F "task=transcribe" -F "language=en" -F "output=txt" -F "word_timestamps=false" http://localhost:$WHISPER_PORT/asr > "$TRANSCRIBED_DIR/${TIMESTAMP}_transcription.txt"

if [ $? -ne 0 ]; then
  echo -e "${RED}Error during transcription.${NC}"
  exit 1
fi

# Step 5: Save transcription result
TRANSCRIPTION_FILE="$TRANSCRIBED_DIR/${TIMESTAMP}_transcription.txt"

echo "Step 5: Transcription in progress. The system is analyzing the uploaded file, which may take a few moments depending on file size."
sleep 3 # Simulating delay for transcription

# Final output
echo -e "${GREEN}Transcription complete. Saved to: $TRANSCRIPTION_FILE${NC}"

echo -e "${GREEN}All files have been saved to $RESULT_DIR.${NC}"

echo -e "${GREEN}Done.${NC}"

