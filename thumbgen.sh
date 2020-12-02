#!/bin/bash

set -e

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "thumbgen - generate a video thumbnail with title"
      echo
      echo "thumbgen.sh [options] videopath 'Title Goes Here'"
      echo " "
      echo "options:"
      echo "-h, --help       show brief help"
      echo "-f FRAMENUM      specify a frame number manually (defaults to a random frame)"
      echo "-t SECONDS       specify a time index in seconds"
      echo "-bg RGB          specify background red green blue separated by comma (default '0,0,0')"
      echo "-fg RGB          specify foreground red green blue separated by comma (default '0,0,0')"
      echo "-o OPACITY       specify a opacity of the title overlay as a decimal number between 0.0 and 1.0 (default 0.8)"
      exit 0
      ;;
    -f)
      shift
      FRAME=$1
      shift
      ;;
    -t)
      shift
      TIME=$1
      shift
      ;;
    -o)
      shift
      OPACITY=$1
      shift
      ;;
    -bg)
      shift
      BG_RGB=$1
      shift
      ;;
    -fg)
      shift
      FG_RGB=$1
      shift
      ;;
    *)
      break
      ;;
  esac
done

file="$1"
shift

thumbstr="$@"
echo "Working..."

if [[ -z "$OPACITY" ]]; then
  OPACITY="0.85"
fi

if [[ -z "$BG_RGB" ]]; then
  BG_RGB="0,0,0"
fi

if [[ -z "$FG_RGB" ]]; then
  FG_RGB="0,0,0"
fi

# Grab a random frame from the video
if [[ -z "$FRAME" && -z "$TIME" ]]; then
  TOTAL_FRAMES=$(ffmpeg -i "$file" -vcodec copy -acodec copy -f null /dev/null 2>&1 | egrep -o "frame=[0-9]+" | cut -d '=' -f 2)
  FRAME=$((RANDOM % TOTAL_FRAMES))
fi
if [[ -z "$TIME" ]]; then
  FPS=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=avg_frame_rate "$file" | cut -d'/' -f 1)
  TIME=$((FRAME/FPS))
else
  FRAME="$TIME" # FIXME: just set it to something for now
fi
ffmpeg -ss $TIME -i "$file" -frames:v 1 "$FRAME".png > /dev/null 2>&1
FILENAME="$FRAME.png"

VIDEO_WIDTH=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1 -show_entries stream "$file" | grep "^width=" | cut -d'=' -f2)
VIDEO_HEIGHT=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1 -show_entries stream "$file" | grep "^height=" | cut -d'=' -f2)

# Superimpose stuff with imagemagick
# Add the dark rectangle
convert $FILENAME -strokewidth 0 -fill "rgba($BG_RGB, $OPACITY)" -draw "rectangle 0,$((($VIDEO_HEIGHT / 2) - 250)) $VIDEO_WIDTH,$((($VIDEO_HEIGHT / 2) + 210))" temp.png

# (What I use) FONT="/Users/vkoskiv/Library/Fonts/SFMono-Regular.otf"
FONT="helvetica-bold"
LINE_SPACING=25
FONTSIZE=180
# And finally, add the title text.
out="thumbnail${FRAME}.png"
convert temp.png \( -gravity Center -pointsize $FONTSIZE -size "$((VIDEO_WIDTH - 50))"x -background transparent -fill "rgb($FG_RGB)" -font $FONT -interline-spacing $LINE_SPACING caption:"$thumbstr" \) -gravity Center -geometry +0+0 -composite $out
rm temp.png
rm "$FRAME".png
echo "Wrote $out"
