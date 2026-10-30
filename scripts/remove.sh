#!/usr/bin/env bash
# remove.sh <data folder>: takes glance out of the user's statusLine setting, leaving any other status line alone.
set -e
data=$1
settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

if [ "$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)" != "$data/statusline.sh" ]; then
  echo "Nothing to remove: $settings doesn't run glance."
  exit 0
fi
cp "$settings" "$settings.bak-glance"
jq 'del(.statusLine)' "$settings.bak-glance" >"$settings"
echo "Removed the status line from $settings (backup: $settings.bak-glance). You can now uninstall the plugin."
