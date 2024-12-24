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

# Function to find an available port starting from 9000
find_available_port() {
  local START_PORT=$1
  local PORT=$START_PORT
  while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; do
    if docker ps | grep -q "openai-whisper-asr-webservice" && docker inspect --format='{{(index (index .HostConfig.PortBindings "9000/tcp") 0).HostPort}}' $(docker ps -q --filter ancestor=onerahmet/openai-whisper-asr-webservice) | grep -q "$PORT"; then
      echo "$PORT"
      return
    fi
    PORT=$((PORT + 1))
  done
  echo "$PORT"
}

# Function to generate unique file names
generate_unique_filename() {
  local BASE_NAME="$1"
  local EXT="$2"
  local DIR="$3"
  local TIMESTAMP=$(date +"%y-%m-%d-%H-%M-%S")
  local FILENAME="$DIR/$BASE_NAME-$TIMESTAMP.$EXT"
  local COUNTER=1

  while [ -e "$FILENAME" ]; do
    FILENAME="$DIR/$BASE_NAME-$TIMESTAMP-$COUNTER.$EXT"
    COUNTER=$((COUNTER + 1))
  done

  echo "$FILENAME"
}

# Start timer
START_TIME=$(date +%s)

# Step 0: Ensure Docker is running
check_docker_running

# Step 1: Validate input file and set up directories
echo "Step 1: Validating input file and setting up directories..."

if [ -z "$1" ]; then
  echo -e "${YELLOW}Usage: $0 <input_file.m4a>${NC}"
  exit 1
fi

INPUT_FILE="$1"
WHISPER_PORT=$(find_available_port 9000)
RESULT_DIR="transcribe-$(date +"%y%m%d")"
WORKING_DIR="$RESULT_DIR/working-files"
TRANSCRIBED_DIR="$RESULT_DIR/transcribed-output"

mkdir -p "$WORKING_DIR"
mkdir -p "$TRANSCRIBED_DIR"

if [ ! -f "$INPUT_FILE" ]; then
  echo -e "${RED}Error: Input file '$INPUT_FILE' does not exist.${NC}"
  exit 1
fi

if [ $(stat -c%s "$INPUT_FILE") -le 10240 ]; then
  echo -e "${RED}Error: Input file '$INPUT_FILE' is too small (must be greater than 10KB).${NC}"
  exit 1
fi

if [[ "$INPUT_FILE" != *.m4a ]]; then
  echo -e "${RED}Error: Input file '$INPUT_FILE' is not an m4a file.${NC}"
  exit 1
fi

# Step 2: Convert m4a to wav
echo "Step 2: Converting $INPUT_FILE to WAV format. This may take a few moments..."
OUTPUT_FILE=$(generate_unique_filename "converted" "wav" "$WORKING_DIR")
docker run --rm -v "$(pwd)":/tmp -w /tmp jrottenberg/ffmpeg -i "$INPUT_FILE" "$OUTPUT_FILE"

if [ $? -ne 0 ]; then
  echo -e "${RED}Error during audio conversion.${NC}"
  exit 1
fi

echo -e "${GREEN}Conversion complete. Output file: $OUTPUT_FILE${NC}"

# Step 3: Start Whisper ASR web service
echo "Step 3: Ensuring Whisper ASR web service is running on port $WHISPER_PORT..."
if ! docker ps | grep -q "openai-whisper-asr-webservice"; then
  echo "Starting Whisper ASR web service on port $WHISPER_PORT..."
  docker run -d -p $WHISPER_PORT:9000 -e ASR_MODEL=base -e ASR_ENGINE=openai_whisper onerahmet/openai-whisper-asr-webservice:latest

  echo "Waiting for Whisper ASR web service to start..."
  sleep 5

  if ! docker ps | grep -q "openai-whisper-asr-webservice"; then
    echo -e "${RED}Failed to start Whisper ASR web service.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}Whisper ASR web service is already running on port $WHISPER_PORT.${NC}"
fi

# Step 4: Transcribe the WAV file
echo "Step 4: Uploading $OUTPUT_FILE to Whisper service for transcription. You will see progress as the file uploads."
TRANSCRIPTION_FILE=$(generate_unique_filename "transcribed" "txt" "$TRANSCRIBED_DIR")
curl --progress-bar -F "audio_file=@$OUTPUT_FILE" -F "task=transcribe" -F "language=en" -F "output=txt" -F "word_timestamps=false" http://localhost:$WHISPER_PORT/asr > "$TRANSCRIPTION_FILE"

if [ $? -ne 0 ]; then
  echo -e "${RED}Error during transcription.${NC}"
  exit 1
fi

# Final output
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo -e "${GREEN}Transcription complete. Saved to: $TRANSCRIPTION_FILE${NC}"
echo -e "${GREEN}All files have been saved to $RESULT_DIR.${NC}"
echo -e "${GREEN}Total time elapsed: $ELAPSED_TIME seconds.${NC}"
echo -e "${GREEN}Done.${NC}"
