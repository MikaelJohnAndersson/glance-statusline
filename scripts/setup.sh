#!/usr/bin/env bash
# setup.sh <plugin root> <data folder> [--replace]: points the user's statusLine setting at the plugin.
set -e
root=$1 data=$2 replace=$3
settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
command="$data/statusline.sh"

command -v jq >/dev/null || { echo "jq is missing. Install it (brew install jq, apt install jq), then run setup again."; exit 1; }
command -v git >/dev/null || echo "Note: git is missing, so the repo row will be empty."

"$root/scripts/sync.sh" "$root" "$data"

[ -s "$settings" ] || echo '{}' >"$settings"
current=$(jq -r '.statusLine.command // empty' "$settings")

if [ "$current" = "$command" ]; then
  echo "Already set up: $settings points at $command."
  exit 0
fi
if [ -n "$current" ] && [ "$replace" != "--replace" ]; then
  echo "EXISTING: $settings already has a status line: $current"
  echo "Run again with --replace to swap it for glance. The old settings are backed up first."
  exit 2
fi

cp "$settings" "$settings.bak-glance"
jq --arg command "$command" '.statusLine = {type: "command", command: $command, padding: 0, refreshInterval: 30}' \
  "$settings.bak-glance" >"$settings"
echo "Done: $settings now runs $command (backup: $settings.bak-glance). It shows from the next reply."
