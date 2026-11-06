#!/usr/bin/env bash
# config.sh <data folder> [colour|icon <value>|reset]: shows or changes this account's theme file.
# The names here are the ones statusline.sh knows; keep the two in step.
data=$1 setting=$2
shift
[ $# -gt 0 ] && shift
value=$(printf '%s' "$*" | tr -d '[:space:][:cntrl:]')
theme="$data/theme"
COLOURS="sky mint lavender pink gold coral teal lilac"
ICONS="user briefcase home rocket heart star code gamepad flask"

# The value of one key in the theme file; a bare line is the colour
read_key() {
  [ -r "$theme" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | tr -d '[:space:][:cntrl:]')
    case $line in
      "$1"=*) printf '%s' "${line#*=}" ;;
      color=*) [ "$1" = colour ] && printf '%s' "${line#*=}" ;;
      *=*|"") ;;
      *) [ "$1" = colour ] && printf '%s' "$line" ;;
    esac
  done <"$theme"
}

# Rewrites the theme file with one key changed, or removed when the value is empty
write_key() {
  local colour icon
  colour=$(read_key colour) icon=$(read_key icon)
  [ "$1" = colour ] && colour=$2
  [ "$1" = icon ] && icon=$2
  mkdir -p "$data"
  { [ -n "$colour" ] && echo "colour=$colour"; [ -n "$icon" ] && echo "icon=$icon"; } >"$theme.tmp"
  if [ -s "$theme.tmp" ]; then mv "$theme.tmp" "$theme"; else rm -f "$theme.tmp" "$theme"; fi
}

# A colour or icon name on its own sets that; the two lists share no names
lower_setting=$(printf '%s' "$setting" | tr '[:upper:]' '[:lower:]')
if [ -z "$value" ] && { [[ " $COLOURS " == *" $lower_setting "* ]] || [[ $lower_setting =~ ^[0-9]+$ ]]; }; then
  value=$setting setting=colour
elif [ -z "$value" ] && [[ " $ICONS " == *" $lower_setting "* ]]; then
  value=$lower_setting setting=icon
fi

case $setting in
  colour|color)
    lower=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    if [ "$lower" = auto ]; then
      write_key colour "" && echo "Colour back to automatic."
    elif [[ " $COLOURS " == *" $lower "* ]] || { [[ $lower =~ ^[0-9]+$ ]] && [ "$lower" -le 255 ]; }; then
      write_key colour "$lower" && echo "Colour set to $lower."
    else
      echo "Unknown colour \"$value\". Pick one of: $COLOURS, a 256-colour number (0–255), or auto." && exit 1
    fi ;;
  icon)
    if [ -z "$value" ]; then
      echo "Name an icon: $ICONS, any emoji, or auto." && exit 1
    elif [ "$value" = auto ]; then
      write_key icon "" && echo "Icon back to the default."
    else
      write_key icon "$value" && echo "Icon set to $value."
    fi ;;
  reset)
    rm -f "$theme" && echo "Theme reset: automatic colour, default icon." ;;
  "")
    account=$(jq -r '.oauthAccount // {} | [.displayName, (.emailAddress // "" | split("@")[0])] | map(select(. != null and . != "")) | first // empty' \
      "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json" 2>/dev/null)
    email=$(jq -r '.oauthAccount.emailAddress // empty' "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json" 2>/dev/null)
    colour=$(read_key colour) icon=$(read_key icon)
    if [ -z "$colour" ] && [ -n "$account" ]; then
      set -- $COLOURS
      shift $(( $(printf '%s' "${email:-$account}" | cksum | cut -d ' ' -f 1) % $# ))
      colour="$1 (automatic)"
    fi
    echo "Account: ${account:-none signed in}"
    echo "Colour:  ${colour:-none, no account}"
    echo "Icon:    ${icon:-user (default)}"
    if [ -e "$data/detail" ]; then echo "Detail row: on"; else echo "Detail row: off"; fi
    echo
    echo "Colours: $COLOURS, or a 256-colour number (0–255). Icons: $ICONS, or any emoji."
    echo "Change with: /glance:config <colour or icon>, or colour <value>, icon <value> (any emoji), reset. 'auto' resets one."
    exit 0 ;;
  *)
    echo "Unknown setting \"$setting\". Use colour, icon or reset, or nothing to see the current settings." && exit 1 ;;
esac
echo "It changes on the next refresh, within 30 s."
