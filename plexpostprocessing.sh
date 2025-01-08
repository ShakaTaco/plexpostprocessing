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
# Notes:
# ---------------------------------------------------------
# Name the script plexpostprocessing.sh and chmod +x on it.
# Then save it here: var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scripts.
# Make sure to change the location of the comskip.ini file, list the location below in the default
# configurations, chmod 777 on it as well if needed so the Plex user can call it.  (This is currently commented out for
# comcut until it can call the correct file location.  Until then, it uses /root/.comskip.ini which is apparently created when
# git cloning the respository, installing one of the apps, and then after the first initial run.  Check /root/.comskip.ini
# exists after installing all required tools and running once.  Change log directory, tmp directory, compskip.ini directory
# and comchap/comcut installation location as necessary.  Commented out use of all processors for HandBrake and instead using
# half.  Change the number of processors for HandBrake as needed.  This is done via --encopts="threads=$(( $(nproc) / 2 ))".
# This uses nproc (the number of processors on the server) divided by 2.  This script can be adjusted at the end to process
# multiple files via arguments in terminal.  One could also update this to run on any .ts files found in the DVR/recordings
# folder.  This script can be used for Plex or Jellyfin.  Perhaps Emby or others as well with some adjustment.
# Seeing an issue with 1080p files creating an .edl file and removing commercials.  Could be local to my setup.
#
#Comskip.ini examples: https://discussion.mcebuddy2x.com/t/comskip-ini-help/4353
#				       https://www.kaashoek.com/comskip/viewforum.php?f=7&sid=a009d7f9b6236e73953d2a625b1062d2
#
# ---------------------------------------------------------
# Future Adjustment Ideas:
# ---------------------------------------------------------
# Chapter creation for Plex use
# Automatic file renaming
# Another option for extracting and embedding subtitles
# More/Better error handling and logging, if necessary
# Update to work with more than .ts files
# Test output to formats other than .mp4
# Review mkvpropedit, mkvtoolnix, mkvmerge, comskip, ccextractor
# Multithread and parallel processing
# Disk space Check
# Progress reporting when run manually
# Email alert
# Input validation
# Processing for all .ts files in folder
# 1080p .edl file creation and commercial removing fix (corrupted double-linked list)

# ---------------------------------------------------------
# Required tools for this script:
# 1. **HandBrakeCLI**: Used for transcoding the .ts file into the desired format.
#    - Installation: https://handbrake.fr/downloads.php
#    - On Ubuntu:
#      sudo apt install handbrake handbrake-cli
# 2. **ffprobe**: Used to get the resolution of the video file.
#    - Installation: https://ffmpeg.org/download.html
#    - On Ubuntu:
#      sudo apt install ffmpeg
# 3. **comchap**: Used to add chapters to the transcoded file.
#    - Installation: https://github.com/BrettSheleski/comchap
#    - git clone https://github.com/BrettSheleski/comchap
# 4. **comcut**: Optional tool for cutting commercials from the video.
#    - Installation: https://github.com/BrettSheleski/comchap
#    - git clone https://github.com/BrettSheleski/comchap
# 5. **git**: Use to clone git repositories.
#    - Installation on Ubuntu:
#      sudo apt install git											
# ---------------------------------------------------------

# ---------------------------------------------------------
# Default configurations
# ---------------------------------------------------------
LOG_FILE="/PATH/TO/LOCATION"	# Log for processing output
TERMINAL_LOG_FILE="/PATH/TO/LOCATION"  # Additional log for entire terminal output
HANDBRAKE_PRESET="Very Fast 1080p30"
SUBTITLE_TRACKS="1,2,3,4,5,6"
OUTPUT_FORMAT="mp4"
TMP_DIR="/PATH/TO/LOCATION"  # Temporary directory for processing
COMCHAP_PATH="/PATH/TO/LOCATION" # Set the location of comchap tool
COMCUT_PATH="/PATH/TO/LOCATION"   # Set the location of comcut tool
#COMSKIP_INI="/PATH/TO/LOCATION"     # Set the location of the comskip.ini file, defaults to /root/.comskip.ini

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
	#HandBrakeCLI -i "$TMP_DIR/$(basename "$input_file")" -o "$transcoded_file" -e x264 -q 20 -B 160 -s "$SUBTITLE_TRACKS" --preset="$HANDBRAKE_PRESET" --encopts="threads=$(nproc)"


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
    validate_input "$@"
    process_file "$input_file"
}

main "$@"

# ---------------------------------------------------------
# Script entry point v2 for multi-file arguments via command line.  Just comment out the script entry point above
# ---------------------------------------------------------
#main() {
#    check_dependencies
#    for input_file in "$@"; do
#    validate_input "$input_file"
#    process_file "$input_file"
#done
#}

#main "$@"

# HandBrake Presets - choose from the following options below and hardcode it above to change the preset being used.
#
# Preset Type|Preset Name|Type|Video|Audio|Picture Quality|Encoding Speed|File Size|Max Resolution|Frame Types|GOP Size
# General|Very Fast 2160p60 4K AV1|MP4|AV1|AAC stereo|Average|Very fast|Small|||
# General|Very Fast 2160p60 4K HEVC|MP4|H.265|AAC stereo|Average|Very fast|Small|||
# General|Very Fast 1080p30|MP4|H.264|AAC stereo|Average|Very fast|Small|||
# General|Very Fast 720p30|MP4|H.264|AAC stereo|Average|Very fast|Small|||
# General|Very Fast 576p25|MP4|H.264|AAC stereo|Average|Very fast|Small|||
# General|Very Fast 480p30|MP4|H.264|AAC stereo|Average|Very fast|Small|||
# General|Fast 2160p60 4K AV1|MP4|AV1|AAC stereo|Standard|Fast|Average|||
# General|Fast 2160p60 4K HEVC|MP4|H.265|AAC stereo|Standard|Fast|Average|||
# General|Fast 1080p30|MP4|H.264|AAC stereo|Standard|Fast|Average|||
# General|Fast 720p30|MP4|H.264|AAC stereo|Standard|Fast|Average|||
# General|Fast 576p25|MP4|H.264|AAC stereo|Standard|Fast|Average|||
# General|Fast 480p30|MP4|H.264|AAC stereo|Standard|Fast|Average|||
# General|HQ 2160p60 4K AV1 Surround|MP4|AV1|AAC stereo; Dolby Digital (AC-3)|High|Slow|Large|||
# General|HQ 2160p60 4K HEVC Surround|MP4|H.265|AAC stereo; Dolby Digital (AC-3)|High|Slow|Large|||
# General|HQ 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|High|Slow|Large|||
# General|HQ 720p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|High|Slow|Large|||
# General|HQ 576p25 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|High|Slow|Large|||
# General|HQ 480p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|High|Slow|Large|||
# General|Super HQ 2160p60 4K AV1 Surround|MP4|AV1|AAC stereo; Dolby Digital (AC-3)|Super High|Very slow|Very large|||
# General|Super HQ 2160p60 4K HEVC Surround|MP4|H.265|AAC stereo; Dolby Digital (AC-3)|Super High|Very slow|Very large|||
# General|Super HQ 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|Super high|Very slow|Very large|||
# General|Super HQ 720p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|Super high|Very slow|Very large|||
# General|Super HQ 576p25 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|Super high|Very slow|Very large|||
# General|Super HQ 480p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)|Super high|Very slow|Very large|||
# Web|Creator 2160p60 4K|MP4|H.264|AAC stereo|High|Medium|Large|||
# Web|Creator 1440p60 2.5K|MP4|H.264|AAC stereo|High|Medium|Large|||
# Web|Creator 1080p60|MP4|H.264|AAC stereo|High|Medium|Large|||
# Web|Creator 720p60|MP4|H.264|AAC stereo|High|Medium|Large|||
# Web|Social 25 MB 30 Seconds 1080p60|MP4|H.264|AAC stereo|Depends on source|Medium|25 MB or less|||
# Web|Social 25 MB 1 Minute 720p60|MP4|H.264|AAC stereo|Depends on source|Medium|25 MB or less|||
# Web|Social 25 MB 2 Minutes 540p60|MP4|H.264|AAC stereo|Depends on source|Medium|25 MB or less|||
# Web|Social 25 MB 5 Minutes 360p60|MP4|H.264|AAC stereo|Depends on source|Medium|25 MB or less|||
# Devices|Amazon Fire 2160p60 4K HEVC Surround|MP4|H.265|AAC stereo; Dolby Digital (AC-3)||Slow||||
# Devices|Amazon Fire 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Amazon Fire 720p30 Surround|MP4|H.264|AAC stereo||Medium||||
# Devices|Android 1080p30|MP4|H.264|AAC stereo||Medium||||
# Devices|Android 720p30|MP4|H.264|AAC stereo||Medium||||
# Devices|Android 576p25|MP4|H.264|AAC stereo||Medium||||
# Devices|Android 480p30|MP4|H.264|AAC stereo||Medium||||
# Devices|Apple 2160p60 4K HEVC Surround|MP4|H.265|AAC stereo; Dolby Digital (AC-3)||Slow||||
# Devices|Apple 1080p60 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Apple 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Apple 720p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Apple 540p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Chromecast 2160p60 4K HEVC Surround|MP4|H.265|AAC stereo; Dolby Digital (AC-3)||Slow||||
# Devices|Chromecast 1080p60 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Chromecast 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Playstation 2160p60 4K Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Slow||||
# Devices|Playstation 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Playstation 720p30|MP4|H.264|AAC stereo||Medium||||
# Devices|Playstation 540p30|MP4|H.264|AAC stereo||Medium||||
# Devices|Roku 2160p60 4K HEVC Surround|MKV|H.265|AAC stereo; AAC, Dolby Digital (AC-3), Dolby Digital Plus (E-AC-3), DTS, or MP3||Slow||||
# Devices|Roku 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Roku 720p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Devices|Roku 576p25|MP4|H.264|AAC stereo||Medium||||
# Devices|Roku 480p30|MP4|H.264|AAC stereo||Medium||||
# Devices|Xbox 1080p30 Surround|MP4|H.264|AAC stereo; Dolby Digital (AC-3)||Medium||||
# Matroska|AV1 MKV 2160p60 4K|MKV|AV1|AAC stereo||Slow||||
# Matroska|H.265 MKV 2160p60 4K|MKV|H.265|AAC stereo||Slow||||
# Matroska|H.265 MKV 1080p30|MKV|H.265|AAC stereo||Slow||||
# Matroska|H.265 MKV 720p30|MKV|H.265|AAC stereo||Slow||||
# Matroska|H.265 MKV 576p25|MKV|H.265|AAC stereo||Slow||||
# Matroska|H.265 MKV 480p30|MKV|H.265|AAC stereo||Slow||||
# Matroska|H.264 MKV 2160p60 4K|MKV|H.264|AAC stereo||Standard||||
# Matroska|H.264 MKV 1080p30|MKV|H.264|AAC stereo||Standard||||
# Matroska|H.264 MKV 720p30|MKV|H.264|AAC stereo||Standard||||
# Matroska|H.264 MKV 576p25|MKV|H.264|AAC stereo||Standard||||
# Matroska|H.264 MKV 480p30|MKV|H.264|AAC stereo||Standard||||
# Matroska|VP9 MKV 2160p60 4K|MKV|VP9|Opus stereo||Ultra slow||||
# Matroska|VP9 MKV 1080p30|MKV|VP9|Opus stereo||Ultra slow||||
# Matroska|VP9 MKV 720p30|MKV|VP9|Opus stereo||Ultra slow||||
# Matroska|VP9 MKV 576p25|MKV|VP9|Opus stereo||Ultra slow||||
# Matroska|VP9 MKV 480p30|MKV|VP9|Opus stereo||Ultra slow||||
# Hardware|AV1 QSV 2160p60 4K|MP4|AV1|AAC stereo||Very Fast||||
# Hardware|H.265 NVENC 2160p60 4K|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 NVENC 1080p60|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 QSV 2160p60 4K|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 QSV 1080p60|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 VCN 2160p60 4K|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 VCN 1080p60|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 MF 2160p60 4K|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 MF 1080p60|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 Apple VideoToolbox 2160p60 4K|MP4|H.265|AAC stereo||Very Fast||||
# Hardware|H.265 Apple VideoToolbox 1080p60|MP4|H.265|AAC stereo||Very Fast||||
# Production|Production Max|MP4|H.264|AAC stereo|Max Master|Depends on source|Gigantic|Unlimited|I/P|45669
# Production|Production Standard|MP4|H.264|AAC stereo|Standard Master|Depends on source|Huge|Unlimited|I/P|45669
# Production|Production Proxy 1080p|MP4|H.264|AAC stereo|Proxy|Fast|Average|¼ 2160p 4K|Intra-only|1
# Production|Production Proxy 540p|MP4|H.264|AAC stereo|Proxy|Very Fast|Small|¼ 1080p HD|Intra-only|1
