# plexpostprocessing

## Note

This is my first GitHub post and I wanted to share this script with others who may benefit from it.  I needed a way to transcode new Plex Live TV DVR recordings from the large TS file formats while cutting commercials out and a few other features.  I didn't find any that did exactly what I needed so I decided to create one myself.  This is a work in progress and more features could come.  Thanks to all authors and their tools necessary to make this script work including BrettSheleski for comchap/comcut as well as HandbrakeCLI, ffmpeg/ffprobe, git, comskip, and Kaashoek and MCEbuddy for comskip.ini examples.

## Overview

This script automates the post-processing of .ts files, such as DVR recordings, for use with Plex, Jellyfin, Emby, or other media servers. It creates a temporary working directory, logs detailed activity, checks for required tools and configurations, analyzes file resolution to apply appropriate transcoding settings, and optionally adds chapters and removes commercials using comchap, comcut, and comskip. The script transcodes .ts files to a new format using HandBrakeCLI, retaining subtitles, and cleans up temporary files while deleting the original .ts file upon successful transcoding.

## Features

The script provides automated transcoding based on video resolution and integrates with comchap and comcut for chapter creation and commercial removal. It supports customizable logging and temporary directory paths, handles subtitles, and has a modular design for future enhancements.

## Requirements

The script requires several tools to function. HandBrakeCLI is used for transcoding, and you can install it from the HandBrake Downloads page or on Ubuntu using `sudo apt install handbrake handbrake-cli`. ffprobe, which retrieves video resolution, can be installed from FFmpeg or on Ubuntu with `sudo apt install ffmpeg`. comchap adds chapters to transcoded files, and you can install it by cloning the repository with `git clone https://github.com/BrettSheleski/comchap`. Similarly, comcut, which optionally removes commercials from videos, can be installed using the same command. Additionally, git is required for cloning repositories and can be installed on Ubuntu with `sudo apt install git`.	

## Configuration

The script logs and tmp directories will need to be added as well as the location for the comchap/comcut installation (/PATH/TO/comchap/comchap and /PATH/TO/comchap/comcut). The HandBrake preset is set to Very Fast 1080p30, and the output format is mp4. It handles subtitle tracks 1,2,3,4,5,6 by default. To use the script, save it as plexpostprocessing.sh and make it executable using `chmod +x plexpostprocessing.sh`. It should be placed in /var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scripts for Plex to use it.

## Usage

1. Name the script plexpostprocessing.sh and chmod +x on it.
2. Save it here: var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scripts.
3. Uses /root/.comskip.ini for the comskip.ini file after the initial run.  Location is commented out in the script for now.
4. Update the log directory, tmp directory, and comchap/comcut installation location as necessary.
5. Change the number of processors for HandBrake as needed.  This is done via _--encopts="threads=$(( $(nproc) / 2 ))"_ in the script.  This uses nproc (the number of processors on the server) divided by 2.
You could use _--encopts="threads=$(nproc)"_ to use all available processors.

You can also run the script manually with the path to a .ts file as an argument, for example: `./plexpostprocessing.sh /path/to/your/file.ts`. For processing multiple .ts files add each file as an argument after calling the script to iterate through a list of files.

## Known Issues

There are some known issues with the script. Commercial removal for 1080p files may fail due to a corrupted double-linked list error. Additionally, ensure that /root/.comskip.ini exists after setting up the comskip tools for the first time.

## Future Enhancement Ideas

Future improvements to the script could include chapter creation for Plex use, automating file renaming, more or better error handling, adding support for additional file formats, and implementing disk space checks, email alerts, and progress reporting.  The multithread/parallel processing could be reviewed further.  Another idea is to process all .ts files in a folder in batch processes.

## References

For more information and examples, refer to the [Comskip Examples](https://discussion.mcebuddy2x.com/t/comskip-ini-help/4353) and the [Comskip Forum](https://www.kaashoek.com/comskip/viewforum.php?f=7&sid=a009d7f9b6236e73953d2a625b1062d2).  Comchap can be found at [here](https://github.com/BrettSheleski/comchap).

## Credits and Licensing

The below tools are used in the plexpostprocessing.sh script and licensed as follows.  The rest which is not attributed it is licensed under the GNU General Public License v2.0 (or later) within this repository.

[BrettSheleski](https://github.com/BrettSheleski) - Comchap/comcut is used under the MIT license provided by BrettSheleski.  [Comchap/Comcut License](https://github.com/BrettSheleski/comchap/blob/master/LICENSE.txt)

[Handbrake](https://handbrake.fr/) - Handbrake uses the Creative Commons Attribution-ShareAlike 4.0 International Public License. [Handbrake License](https://handbrake.fr/docs/license-cc-by-sa-4.0.html)

[FFmpeg/ffprobe](https://www.ffmpeg.org/) - FFmpeg is licensed under the [GNU Lesser General Public License (LGPL) version 2.1](http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html) or later. However, FFmpeg incorporates several optional parts and optimizations that are covered by the [GNU General Public License (GPL) version 2](http://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later. If those parts get used the GPL applies to all of FFmpeg. [FFmpeg/ffprobe License](https://www.ffmpeg.org/legal.html)

[erikkaashoek](https://github.com/erikkaashoek) - Comskip uses the GNU General Public License v2.0 license. [Comskip License](https://github.com/erikkaashoek/Comskip/blob/master/LICENSE)

Refer to the respective licenses for full terms and conditions. Attribution has been provided where required.
