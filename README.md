# plexpostprocessing

## Note

This is my first GitHub post and I wanted to share this script with others who may be in need.  I needed a way to transcode new Plex Live TV DVR recordings from the large TS file formats while cutting commercials out and a few other features.  I didn't find any that did exactly what I needed so I decided to create one myself.  This is a work in progress and more features could come.  Thanks to all authors and their tools necessary to make this script work including BrettSheleski for comchap/comcut as well as HandbrakeCLI, ffmpeg/ffprobe, git, comskip, and Kaashoek and MCEbuddy for comskip.ini examples.

## Overview

This script automates the post-processing of .ts files, such as DVR recordings, for use with Plex, Jellyfin, or other media servers. It creates a temporary working directory, logs detailed activity, checks for required tools and configurations, analyzes file resolution to apply appropriate transcoding settings, and optionally adds chapters and removes commercials using comchap, comcut, and comskip. The script transcodes .ts files to a new format using HandBrakeCLI, retaining subtitles, and cleans up temporary files while deleting the original .ts file upon successful transcoding.

## Features

The script provides automated transcoding based on video resolution and integrates with comchap and comcut for chapter creation and commercial removal. It supports customizable logging and temporary directory paths, handles subtitles, and has a modular design for future enhancements.

## Requirements

The script requires several tools to function. HandBrakeCLI is used for transcoding, and you can install it from the HandBrake Downloads page or on Ubuntu using sudo apt install handbrake handbrake-cli. ffprobe, which retrieves video resolution, can be installed from FFmpeg or on Ubuntu with sudo apt install ffmpeg. comchap adds chapters to transcoded files, and you can install it by cloning the repository with git clone https://github.com/BrettSheleski/comchap. Similarly, comcut, which optionally removes commercials from videos, can be installed using the same command. Additionally, git is required for cloning repositories and can be installed on Ubuntu with sudo apt install git.

## Configuration

The script logs and tmp directories will need to be added as well as the location for the comchap/comcut installation (/PATH/TO/comchap/comchap and /PATH/TO/comchap/comcut). The HandBrake preset is set to Very Fast 1080p30, and the output format is mp4. It handles subtitle tracks 1,2,3,4,5,6 by default. To use the script, save it as plexpostprocessing.sh and make it executable using `chmod +x plexpostprocessing.sh`. It should be placed in /var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scripts for Plex to use it.

## Usage

You can also run the script manually with the path to a .ts file as an argument, for example: `./plexpostprocessing.sh /path/to/your/file.ts`. For processing multiple .ts files, modify the script entry point to iterate through a list of files by replacing the main function with the following code:
```
main() {
    check_dependencies
    for input_file in "$@"; do
        validate_input "$input_file"
        process_file "$input_file"
    done
}
main "$@"
```
## Known Issues

There are some known issues with the script. Commercial removal for 1080p files may fail due to a corrupted double-linked list error. Additionally, ensure that /root/.comskip.ini exists after setting up the comskip tools for the first time.

## Future Enhancements

Future improvements to the script could include automating file renaming, adding support for additional file formats, improving error handling and progress reporting, and implementing disk space checks and email alerts.

## References

For more information and examples, refer to the [Comskip Examples](https://discussion.mcebuddy2x.com/t/comskip-ini-help/4353) and the [Comskip Forum](https://www.kaashoek.com/comskip/viewforum.php?f=7&sid=a009d7f9b6236e73953d2a625b1062d2).
