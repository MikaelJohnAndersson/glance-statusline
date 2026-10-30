#!/usr/bin/env bash
# detail.sh <data folder>: turns the third row on or off.
flag="$1/detail"
if [ -e "$flag" ]; then rm "$flag" && echo "Detail row off."; else mkdir -p "$1" && touch "$flag" && echo "Detail row on."; fi
echo "It changes on the next refresh, within 30 s."
