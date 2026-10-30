#!/usr/bin/env bash
# sync.sh <plugin root> <data folder>: copies the installed version into the data folder, which outlives updates.
# Silent: a SessionStart hook's output goes into Claude's context.
set -e
root=$1 data=$2
mkdir -p "$data"
cp "$root/scripts/statusline.sh" "$data/statusline.sh.tmp" && mv "$data/statusline.sh.tmp" "$data/statusline.sh"
chmod +x "$data/statusline.sh"
cp "$root/scripts/cheatsheet.html" "$data/cheatsheet.html"
