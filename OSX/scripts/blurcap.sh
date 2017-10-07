#!/usr/bin/env bash

screenSaver="$HOME/Pictures/screensaver/ss.png"

tempCapture="/tmp/wallpaper.png"

/usr/sbin/screencapture -x ${tempCapture} >/dev/null 2>&1

/usr/local/bin/convert -blur 0x4 ${tempCapture} ${screenSaver}