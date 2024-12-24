# Audio Transcription Script

This bash script will take a m4a file which and convert it to a txt file which contains the transcription 

## Overview

This Bash script provides a complete workflow to transcribe audio files into text using OpenAI's Whisper ASR web service. It automates the following steps:

1. **Input Validation**: Ensures the input file exists, is in `.m4a` format, and is of adequate size.
2. **Audio Conversion**: Converts the `.m4a` file to `.wav` using `FFmpeg` via Docker.
3. **Service Initialization**: Checks if the Whisper ASR web service is running on port 9000. If not, it starts the service or finds an available port.
4. **Transcription**: Uploads the `.wav` file to the Whisper ASR service and retrieves the transcription.
5. **File Management**: Organizes the outputs in timestamped directories, ensuring no file name collisions.
6. **Elapsed Time Reporting**: Displays the total runtime of the script.

## Features

- Automated detection and dynamic allocation of available ports to avoid conflicts.
- Ensures unique file names to prevent overwrites using timestamps and counters.
- Displays progress during uploads and reports the total script execution time.

## Prerequisites

1. **Docker**: Ensure Docker is installed and running on your system.
2. **FFmpeg Docker Image**: Uses the `jrottenberg/ffmpeg` Docker image for audio conversion.
3. **Whisper ASR Web Service**: Uses the `onerahmet/openai-whisper-asr-webservice` Docker image for transcription.

## Installation

1. Clone or download this script to your local machine.
2. Make the script executable:
   ```bash
   chmod +x audio_transcribe.sh
   ```

## Usage

Run the script with the path to the `.m4a` file as an argument:

```bash
./audio_transcribe.sh <input_file.m4a>
```

### Example:

```bash
./audio_transcribe.sh my_audio_file.m4a
```

## Output

- All outputs are saved in a timestamped directory (`transcribe-<date>`).
  - **Working Files**: Contains the converted `.wav` file.
  - **Transcribed Output**: Contains the transcription as `transcribed-<timestamp>.txt`.

### Sample Directory Structure:

```plaintext
transcribe-231223
├── working-files
│   └── converted-23-12-23-12-30-00.wav
└── transcribed-output
    └── transcribed-23-12-23-12-30-00.txt
```

## How It Works

1. **Validation**:
   - Verifies that the input file exists and meets requirements.
2. **Audio Conversion**:
   - Converts the `.m4a` input file to `.wav` using FFmpeg.
3. **Whisper ASR Service**:
   - Checks if the service is running on port 9000. If unavailable, allocates the next available port.
4. **Transcription**:
   - Uploads the `.wav` file to the Whisper ASR service for transcription.
5. **Elapsed Time**:
   - Reports the total runtime of the script for transparency.

## Error Handling

- Displays clear error messages if:
  - Docker is not running.
  - The input file is missing or invalid.
  - Audio conversion or transcription fails.
- Avoids file overwrites by generating unique file names with timestamps.

## Notes

- Ensure Docker has sufficient permissions to access the working directory.
- Large audio files may take longer to process during conversion and transcription.

## Future Improvements

- Support for additional audio formats.
- Parallel transcription for batch processing.
- Enhanced progress reporting during transcription.

## License

This script is open-source and distributed under the MIT License.

## Author

Developed by Shikhir Singh. Contributions are welcome!

