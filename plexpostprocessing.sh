#!/bin/bash

# ---------------------------------------------------------
# Plex Post-Processing Script for .ts Files (DVR recordings)
# ---------------------------------------------------------
# This script:
# 1. Creates a temporary working directory and moves all files there.
# 2. Creates two running log files for monitoring and tracking issues with detailed errors and all activity.
# 3. Checks for required and optional tools.
# 4. Check resolution of file(s) and transcode accordingly.
# 5. Optionally creates chapters and cuts commercials based on .ini using comchap/comcut/comskip (Can be adjusted)
# 6. Transcodes .ts DVR files to a new format using HandBrakeCLI.
# 7. Retains subtitles during transcoding.
# 8. Deletes the original .ts file after successful transcoding and cleans up tmp directory removing all extra files.
# ---------------------------------------------------------

# ---------------------------------------------------------
# Default configurations
# ---------------------------------------------------------
LOG_FILE="/PATH/TO/LOCATION"	# Log for processing output
TERMINAL_LOG_FILE="/PATH/TO/LOCATION"  # Additional log for entire terminal output
HANDBRAKE_PRESET="Very Fast 1080p30"
SUBTITLE_TRACKS="1,2,3,4,5,6"
OUTPUT_FORMAT="mp4"
TMP_DIR="/PATH/TO/LOCATION"       # Temporary directory for processing
COMCHAP_PATH="/PATH/TO/LOCATION"  # Set the location of comchap tool
COMCUT_PATH="/PATH/TO/LOCATION"   # Set the location of comcut tool
#COMSKIP_INI="/PATH/TO/LOCATION"  # Set the location of the comskip.ini file, defaults to /root/.comskip.ini

# Redirect all output to terminal log file
exec > >(tee -a "$TERMINAL_LOG_FILE") 2>&1

# ---------------------------------------------------------
# Function to log messages with timestamp
# ---------------------------------------------------------
log_message() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp - $1" | tee -a "$LOG_FILE"
}

# ---------------------------------------------------------
# Check if required tools are available
# ---------------------------------------------------------
check_dependencies() {
	# Check for necessary tools: HandBrakeCLI, ffmpeg, ffprobe
    for tool in HandBrakeCLI ffmpeg ffprobe; do
        if ! command -v $tool &>/dev/null; then
            log_message "Error: $tool is not installed or not in PATH."
            exit 1
        fi
    done

	# Check if comchap is available (optional for chapter creation)
    if [ ! -f "$COMCHAP_PATH" ]; then
        log_message "Warning: comchap not found in '$COMCHAP_PATH'. Chapter creation will be skipped."
    fi

	# Check if comcut is available (optional for commercial cutting)
    if [ ! -f "$COMCUT_PATH" ]; then
        log_message "Warning: comcut not found in '$COMCUT_PATH'. Commercial cutting will be skipped."
    fi

	# Check if comskip.ini file exists
    if [ ! -f "$COMSKIP_INI" ]; then
        log_message "Warning: comskip.ini file not found at '$COMSKIP_INI'."
    fi
}

# ---------------------------------------------------------
# Ensure a file is provided and validate it
# ---------------------------------------------------------
validate_input() {
    if [ $# -ne 1 ]; then
        log_message "Error: No file specified. Provide a .ts file as an argument."
        exit 4
    fi

    input_file="$1"

    if [ ! -f "$input_file" ]; then
        log_message "Error: Input file '$input_file' does not exist."
        exit 5
    fi

    if [[ "$input_file" != *.ts ]]; then
        log_message "Error: The file '$input_file' is not a .ts file."
        exit 6
    fi

    log_message "Processing file: $input_file"
}

# ---------------------------------------------------------
# Get the resolution of the video file
# ---------------------------------------------------------
get_resolution() {
	# Extract the height (resolution) of the video
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$1" | tr -d ',' | head -n 1)

    if [ -z "$resolution" ]; then
        log_message "Error: Could not determine resolution of '$1'."
        exit 7
    fi

    log_message "Resolution of '$1': $resolution"

	# Determine the HandBrake preset based on resolution
    if [ "$resolution" -gt 1080 ]; then
        HANDBRAKE_PRESET="Very Fast 2160p60 4K AV1"
    elif [ "$resolution" -eq 720 ]; then
        HANDBRAKE_PRESET="Very Fast 720p30"
    elif [ "$resolution" -eq 480 ]; then
        HANDBRAKE_PRESET="Very Fast 480p30"
    elif [ "$resolution" -eq 1080 ]; then
        HANDBRAKE_PRESET="Very Fast 1080p30"
    else
        HANDBRAKE_PRESET="Very Fast 1080p30" # Default preset
    fi

    log_message "Using HandBrake preset: $HANDBRAKE_PRESET"
}

# ---------------------------------------------------------
# Move necessary files to the temporary directory
# ---------------------------------------------------------
move_files_to_tmp() {
    local input_file="$1"
    local base_name=$(basename "$input_file" .ts)

	# Ensure the temporary directory exists
    mkdir -p "$TMP_DIR"

	# Move the .ts and associated files to the temp directory
    log_message "Moving files to temporary directory $TMP_DIR"
    mv "$input_file" "$TMP_DIR" || log_message "Warning: Failed to move .ts file to $TMP_DIR"

	# Move related files: .log, .logo.txt, .txt, .edl, .ffmeta, .ffsplit
    for ext in .log .logo.txt .txt .edl .ffmeta .ffsplit; do
        if [ -f "$base_name$ext" ]; then
            mv "$base_name$ext" "$TMP_DIR" || log_message "Warning: Failed to move $base_name$ext to $TMP_DIR"
        fi
    done
}

# ---------------------------------------------------------
# Main processing steps
# ---------------------------------------------------------
process_file() {
    local input_file="$1"
    local original_dir
    original_dir=$(dirname "$input_file")  # Get the directory of the input file

	# Get the resolution and select the appropriate HandBrake preset
    get_resolution "$input_file"
	
	# Move the files to the temporary directory
    move_files_to_tmp "$input_file"

	# Add chapters using comchap
    if [ -f "$COMCHAP_PATH" ]; then
        log_message "Adding chapters using comchap."
        $COMCHAP_PATH "$TMP_DIR/$(basename "$input_file")" || log_message "Warning: comchap failed to add chapters."
    fi

	# Cut commercials using comcut
    if [ -f "$COMCUT_PATH" ]; then
        log_message "Cutting commercials using comcut."
		$COMCUT_PATH "$TMP_DIR/$(basename "$input_file")" || log_message "Warning: comcut failed to cut commercials."
        #$COMCUT_PATH "$TMP_DIR/$(basename "$input_file")" --comskip=$COMSKIP_INI || log_message "Warning: comcut failed to cut commercials."
    fi

	# Transcode using HandBrakeCLI
    local transcoded_file="$TMP_DIR/$(basename "$input_file" .ts).$OUTPUT_FORMAT"
    log_message "Transcoding with HandBrakeCLI. Output: $transcoded_file"
    HandBrakeCLI -i "$TMP_DIR/$(basename "$input_file")" -o "$transcoded_file" -e x264 -q 20 -B 160 -s "$SUBTITLE_TRACKS" --preset="$HANDBRAKE_PRESET" --encopts="threads=$(( $(nproc) / 2 ))"

    if [ $? -ne 0 ]; then
        log_message "Error: HandBrakeCLI failed for '$input_file'."
        exit 8
    fi

	# Move transcoded file back to the original directory
    log_message "Moving transcoded file back to the original directory: $original_dir"
    mv "$transcoded_file" "$original_dir" || log_message "Error: Failed to move transcoded file to original directory."

	# Cleanup original and temporary files
    log_message "Cleaning up original file and temporary files."

    # Remove all related files: .ts, .log, .logo.txt, .edl, .ffmeta, .ffsplit, .txt
    rm -f "$TMP_DIR/$(basename "$input_file")" || log_message "Warning: Failed to remove original .ts file."
    rm -f "$TMP_DIR/$(basename "$input_file" .ts).log" || log_message "Warning: Failed to remove .log file."
    rm -f "$TMP_DIR/$(basename "$input_file" .ts).logo.txt" || log_message "Warning: Failed to remove .logo.txt file."
    rm -f "$TMP_DIR/$(basename "$input_file" .ts).edl" || log_message "Warning: Failed to remove .edl file."
    rm -f "$TMP_DIR/$(basename "$input_file" .ts).ffmeta" || log_message "Warning: Failed to remove .ffmeta file."
    rm -f "$TMP_DIR/$(basename "$input_file" .ts).ffsplit" || log_message "Warning: Failed to remove .ffsplit file."
    rm -f "$TMP_DIR/$(basename "$input_file" .ts).txt" || log_message "Warning: Failed to remove .txt file."

	# Always clean up the temporary directory
    log_message "Cleaning up temporary directory $TMP_DIR"
    rm -rf "$TMP_DIR" || log_message "Warning: Failed to remove temporary directory."

    log_message "Processing completed successfully for '$input_file'. Output: $original_dir/$(basename "$transcoded_file")"
}

# ---------------------------------------------------------
# Script entry point
# ---------------------------------------------------------
main() {
    check_dependencies
    for input_file in "$@"; do
    validate_input "$input_file"
    process_file "$input_file"
done
}

main "$@"
