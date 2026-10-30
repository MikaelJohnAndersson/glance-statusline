#!/usr/bin/env bash
# Claude Code status line: the repo, Claude at a glance, and the detail while toggled on. Needs a Nerd Font.
# Icons are UTF-8 byte escapes: macOS bash 3.2 has no \u.
# Runs from the plugin's data folder, which keeps its state beside it.
input=$(cat)

US=$'\x1f'
IFS=$US read -r session dir model ctx tokens window cost added removed \
  five_pct five_reset week_pct week_reset cache_warm cache_expires pr_url \
  in_read in_write in_fresh out_tokens hit_ratio misses miss_cause duration_ms api_ms <<<"$(jq -r '[
    .session_id, (.workspace.current_dir // .cwd), .model.display_name,
    .context_window.used_percentage, .context_window.total_input_tokens,
    .context_window.context_window_size,
    .cost.total_cost_usd, .cost.total_lines_added, .cost.total_lines_removed,
    .rate_limits.five_hour.used_percentage, .rate_limits.five_hour.resets_at,
    .rate_limits.seven_day.used_percentage, .rate_limits.seven_day.resets_at,
    .prompt_cache.warm, .prompt_cache.expires_at, .pr.url,
    .context_window.current_usage.cache_read_input_tokens,
    .context_window.current_usage.cache_creation_input_tokens,
    .context_window.current_usage.input_tokens, .context_window.current_usage.output_tokens,
    .prompt_cache.hit_ratio, .prompt_cache.misses,
    (.prompt_cache.last_miss_cause.causes // null | if . then join(",") else null end),
    .cost.total_duration_ms, .cost.total_api_duration_ms
  ] | map(if . == null then "" else tostring end) | join("\u001f")' <<<"$input" 2>/dev/null)"

now=$(date +%s)
DATA_DIR=$(cd "$(dirname "$0")" && pwd)
HISTORY_DIR="$DATA_DIR/history"
SPARK_LENGTH=8
USAGE_URL=https://claude.ai/settings/usage
CHEATSHEET_URL="file://$DATA_DIR/cheatsheet.html"
DETAIL_FLAG="$DATA_DIR/detail"
LIMITS_FILE="$DATA_DIR/limits"
# wc -m counts characters only under a UTF-8 locale, named differently on macOS and Linux
UTF8_LOCALE=$(locale -a 2>/dev/null | grep -iE '^(en_US|C)\.utf-?8$' | head -n 1)
PENDING=244

ICON_DIR=$'\xef\x81\xbc'
ICON_BRANCH=$'\xef\x84\xa6'
ICON_CLOCK=$'\xef\x80\x97'
ICON_CONTEXT=$'\xef\x8b\x9b'
ICON_CACHE=$'\xef\x83\xa7'
ICON_RESET=$'\xef\x80\xa1'
ICON_HELP=$'\xef\x81\x99'

c() { printf '\e[38;5;%sm' "$1"; }
RESET=$'\e[0m'
TEXT=$(c 252)
DIM=$(c 244)

# OSC 8: ⌘-click opens the URL
link() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }

level_colour() {
  if [ "$1" -ge 85 ]; then printf 203
  elif [ "$1" -ge 60 ]; then printf 214
  else printf 114
  fi
}

tokens_short() {
  awk -v n="$1" 'BEGIN { if (n >= 1000000) printf "%.1fM", n / 1000000; else printf "%dk", n / 1000 }'
}

# seconds as 3m, 1h52, 4d6h
duration_short() {
  local s=$1
  if [ "$s" -lt 3600 ]; then printf '%dm' $(( (s + 59) / 60 ))
  elif [ "$s" -lt 86400 ]; then printf '%dh%02d' $(( s / 3600 )) $(( s % 3600 / 60 ))
  else printf '%dd%dh' $(( s / 86400 )) $(( s % 86400 / 3600 ))
  fi
}

sparkline() {
  local levels=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █) out="" v
  for v in "$@"; do
    out+="${levels[$(( v * 7 / 100 ))]}"
  done
  printf '%s' "$out"
}

GAP="  "
BAR=" ${DIM}│${RESET} "
# Claude Code indents the row 2 columns and keeps 2 free at the right
RIGHT_MARGIN=4

# join_with <separator> <parts…>
join_with() {
  local sep=$1 out="" part
  shift
  for part in "$@"; do
    [ -n "$out" ] && out+="$sep"
    out+="$part"
  done
  printf '%s' "$out"
}

# Cells the text takes on screen, colour and link codes left out
visible_width() {
  printf '%s' "$1" | sed -e $'s/\e\\]8;;[^\e]*\e\\\\//g' -e $'s/\e\\[[0-9;]*m//g' | LC_ALL=${UTF8_LOCALE:-en_US.UTF-8} wc -m | tr -d ' '
}

# left … right, the right part pinned to the end of the row; dropped when it does not fit
pin_right() {
  local left=$1 right=$2 width=${COLUMNS:-0} pad
  pad=$(( width - RIGHT_MARGIN - $(visible_width "$left") - $(visible_width "$right") ))
  if [ "$pad" -ge 2 ]; then
    printf '%s%*s%s' "$left" "$pad" "" "$right"
  else
    printf '%s' "$left"
  fi
}

# --- row 1: the repo ---

SLASH=" ${DIM}/${RESET} "

# remote as https://github.com/owner/repo, or nothing
github_url() {
  local remote
  remote=$(git -C "$dir" remote get-url origin 2>/dev/null) || return
  case $remote in
    git@github.com:*) remote="https://github.com/${remote#git@github.com:}" ;;
    https://github.com/*) ;;
    *) return ;;
  esac
  printf '%s' "${remote%.git}"
}

path=""
stats=()

[ -n "$dir" ] && path="$(c 75)${ICON_DIR}${RESET} ${TEXT}${dir##*/}${RESET}"

if [ -n "$dir" ] && head=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null); then
  repo_url=$(github_url)
  branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)

  if [ -n "$branch" ]; then
    branch_target=${pr_url:-${repo_url:+$repo_url/tree/$branch}}
    branch_text=$branch
    [ -n "$branch_target" ] && branch_text=$(link "$branch_target" "$branch")
    path+="${SLASH}$(c 114)${ICON_BRANCH}${RESET} ${TEXT}${branch_text}${RESET}"
  fi

  head_text=$head
  [ -n "$repo_url" ] && head_text=$(link "$repo_url/commit/$head" "$head")
  path+="${SLASH}$(c 245)${head_text}${RESET}"

  if counts=$(git -C "$dir" --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null); then
    behind=${counts%%[[:space:]]*}
    ahead=${counts##*[[:space:]]}
    [ "$ahead" -gt 0 ] && stats+=("$(c 117)↑${ahead}${RESET}")
    [ "$behind" -gt 0 ] && stats+=("$(c 210)↓${behind}${RESET}")
  fi

  # porcelain v1: XY path, X the index, Y the work tree, ?? untracked
  staged=0 modified=0 untracked=0
  while IFS= read -r line; do
    case $line in
      '??'*) untracked=$(( untracked + 1 )) ;;
      *)
        [ "${line:0:1}" != " " ] && staged=$(( staged + 1 ))
        [ "${line:1:1}" != " " ] && modified=$(( modified + 1 ))
        ;;
    esac
  done < <(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null)
  [ "$staged" -gt 0 ] && stats+=("$(c 114)●${staged}${RESET}")
  [ "$modified" -gt 0 ] && stats+=("$(c 214)✚${modified}${RESET}")
  [ "$untracked" -gt 0 ] && stats+=("$(c 245)?${untracked}${RESET}")

  stashes=$(git -C "$dir" --no-optional-locks rev-list --walk-reflogs --count refs/stash 2>/dev/null)
  [ -n "$stashes" ] && [ "$stashes" -gt 0 ] && stats+=("$(c 140)≡${stashes}${RESET}")

fi

changes=()
[ "${#stats[@]}" -gt 0 ] && changes+=("$(join_with " " "${stats[@]}")")
if [ -n "$added$removed" ]; then
  changes+=("$(c 114)+${added:-0}${RESET} $(c 210)−${removed:-0}${RESET}")
fi

repo_row=$path
[ "${#changes[@]}" -gt 0 ] && repo_row+="${BAR}$(join_with "$GAP" "${changes[@]}")"

clock="$(c 245)${ICON_CLOCK} $(date +%H:%M)${RESET}${BAR}${DIM}$(link "$CHEATSHEET_URL" "$ICON_HELP")${RESET}"

# --- row 2: Claude at a glance ---

model_icon=""
if [ -n "$model" ]; then
  case $(printf '%s' "$model" | tr '[:upper:]' '[:lower:]') in
    *opus*) model_icon=$'\xef\x80\x81' ;;
    *sonnet*) model_icon=$'\xef\x81\x80' ;;
    *haiku*) model_icon=$'\xef\x81\xac' ;;
    *fable*) model_icon=$'\xef\x80\xad' ;;
    *) model_icon="✦" ;;
  esac
fi

# Until a session's first reply Claude Code sends no context or limits; show the last known ones, dim.
ctx_stale="" limits_stale=""
if [ -z "$ctx" ] && [ -n "$session" ] && [ -s "$HISTORY_DIR/$session" ]; then
  ctx=$(tail -n 1 "$HISTORY_DIR/$session")
  ctx_stale=1
fi
if [ -n "$five_pct" ]; then
  printf '%s %s %s %s\n' "$five_pct" "$five_reset" "$week_pct" "$week_reset" >"$LIMITS_FILE" 2>/dev/null
elif [ -s "$LIMITS_FILE" ]; then
  read -r five_pct five_reset week_pct week_reset <"$LIMITS_FILE"
  if [ -n "$five_reset" ] && [ "$five_reset" -gt "$now" ]; then limits_stale=1; else five_pct="" week_pct=""; fi
fi

# level_colour, or dim while the value is the last known one
shown_colour() { if [ -n "$1" ]; then printf '%s' "$PENDING"; else level_colour "$2"; fi; }

[ -n "$ctx" ] && pct=${ctx%.*}

spark=""
if [ -n "$ctx" ] && [ -z "$ctx_stale" ]; then
  # The script only sees the present, so it keeps the session's context readings itself.
  if [ -n "$session" ] && mkdir -p "$HISTORY_DIR" 2>/dev/null; then
    history_file="$HISTORY_DIR/$session"
    last=$(tail -n 1 "$history_file" 2>/dev/null)
    [ "$last" != "$pct" ] && echo "$pct" >>"$history_file"
    readings=($(tail -n "$SPARK_LENGTH" "$history_file" 2>/dev/null))
    [ "${#readings[@]}" -gt 1 ] && spark="$(c 109)$(sparkline "${readings[@]}")${RESET}"
    find "$HISTORY_DIR" -type f -mtime +7 -delete 2>/dev/null
  fi
fi

cache=""
if [ "$cache_warm" = "true" ] && [ -n "$cache_expires" ] && [ "$cache_expires" -gt "$now" ]; then
  cache="$(c 80)${ICON_CACHE} $(duration_short $(( cache_expires - now )))${RESET}"
elif [ "$cache_warm" = "false" ]; then
  cache="${DIM}${ICON_CACHE} cold${RESET}"
fi

[ -n "$five_pct" ] && five=${five_pct%.*}
[ -n "$week_pct" ] && week=${week_pct%.*}

DROP_MODEL_NAME=1 DROP_WEEK_RESET=2 DROP_WEEK=3 DROP_FIVE_RESET=4 DROP_CACHE=5
GLANCE_LEAST=5

glance_row() {
  local level=$1 groups=() part

  if [ -n "$model" ]; then
    part="$(c 177)${model_icon}"
    [ "$level" -lt "$DROP_MODEL_NAME" ] && part+=" ${model}"
    groups+=("${part}${RESET}")
  fi

  if [ -n "$ctx" ]; then
    part="$(c "$(shown_colour "$ctx_stale" "$pct")")${ICON_CONTEXT} ${pct}%${RESET}"
    [ -n "$cache" ] && [ "$level" -lt "$DROP_CACHE" ] && part+="${GAP}${cache}"
    groups+=("$part")
  elif [ -n "$model" ]; then
    groups+=("$(c "$PENDING")${ICON_CONTEXT} …${RESET}")
  fi

  if [ -n "$five_pct" ]; then
    part="$(link "$USAGE_URL" "${DIM}5h${RESET} $(c "$(shown_colour "$limits_stale" "$five")")${five}%")${RESET}"
    if [ -n "$five_reset" ] && [ "$five_reset" -gt "$now" ] && [ "$level" -lt "$DROP_FIVE_RESET" ]; then
      part+=" $(c 245)${ICON_RESET} $(duration_short $(( five_reset - now )))${RESET}"
    fi
    groups+=("$part")
  fi

  if [ -n "$week_pct" ] && [ "$level" -lt "$DROP_WEEK" ]; then
    part="$(link "$USAGE_URL" "${DIM}7d${RESET} $(c "$(shown_colour "$limits_stale" "$week")")${week}%")${RESET}"
    if [ -n "$week_reset" ] && [ "$week_reset" -gt "$now" ] && [ "$level" -lt "$DROP_WEEK_RESET" ]; then
      part+=" $(c 245)${ICON_RESET} $(duration_short $(( week_reset - now )))${RESET}"
    fi
    groups+=("$part")
  fi

  join_with "$BAR" "${groups[@]}"
}

# --- row 3: the detail, shown while the toggle file exists (/glance:detail) ---

# label value, the label dim
labelled() { printf '%s%s%s %s' "$DIM" "$1" "$RESET" "$2"; }

# date_at <epoch> <format>: BSD date takes -r, GNU date -d @
date_at() { date -r "$1" "$2" 2>/dev/null || date -d "@$1" "$2"; }

# epoch as 14:05 today, or Mon 14:05 later
clock_at() {
  if [ $(( $1 - now )) -lt 86400 ]; then date_at "$1" +%H:%M; else date_at "$1" '+%a %H:%M'; fi
}

DROP_MISS_CAUSE=1 DROP_API_TIME=2 DROP_RESET_CLOCKS=3 DROP_BREAKDOWN=4 DROP_SPARK=5 DROP_SESSION_TIME=6
DROP_WINDOW=7 DROP_CACHE_GROUP=8 DROP_RESETS=9
DETAIL_LEAST=9

detail_row() {
  local level=$1 groups=() parts=() part

  if [ -n "$tokens" ]; then
    part="${TEXT}$(tokens_short "$tokens")${RESET}"
    [ -n "$window" ] && [ "$level" -lt "$DROP_WINDOW" ] && part+="${DIM}/$(tokens_short "$window")${RESET}"
    parts+=("$part")
    if [ -n "$in_read$in_write$in_fresh" ] && [ "$level" -lt "$DROP_BREAKDOWN" ]; then
      parts+=("$(labelled r "$(tokens_short "${in_read:-0}")") $(labelled w "$(tokens_short "${in_write:-0}")") $(labelled i "$(tokens_short "${in_fresh:-0}")") $(labelled o "$(tokens_short "${out_tokens:-0}")")")
    fi
    [ -n "$spark" ] && [ "$level" -lt "$DROP_SPARK" ] && parts+=("$spark")
    groups+=("$(c 109)${ICON_CONTEXT}${RESET} $(join_with " " "${parts[@]}")")
  fi

  if [ -n "$hit_ratio" ] && [ "$level" -lt "$DROP_CACHE_GROUP" ]; then
    part="$(c 80)${ICON_CACHE}${RESET} $(labelled hit "$(awk -v r="$hit_ratio" 'BEGIN { printf "%d%%", r * 100 }')")"
    if [ -n "$misses" ] && [ "$misses" -gt 0 ]; then
      part+=" $(labelled miss "$(c 214)${misses}${RESET}")"
      [ -n "$miss_cause" ] && [ "$level" -lt "$DROP_MISS_CAUSE" ] && part+=" ${DIM}(${miss_cause})${RESET}"
    fi
    groups+=("$part")
  fi

  parts=()
  if [ -n "$five_reset" ] && [ "$five_reset" -gt "$now" ]; then
    part="$(labelled 5h "$(duration_short $(( five_reset - now )))")"
    [ "$level" -lt "$DROP_RESET_CLOCKS" ] && part+=" ${DIM}$(clock_at "$five_reset")${RESET}"
    parts+=("$part")
  fi
  if [ -n "$week_reset" ] && [ "$week_reset" -gt "$now" ]; then
    part="$(labelled 7d "$(duration_short $(( week_reset - now )))")"
    [ "$level" -lt "$DROP_RESET_CLOCKS" ] && part+=" ${DIM}$(clock_at "$week_reset")${RESET}"
    parts+=("$part")
  fi
  [ "${#parts[@]}" -gt 0 ] && [ "$level" -lt "$DROP_RESETS" ] && groups+=("$(c 245)${ICON_RESET}${RESET} $(join_with "$GAP" "${parts[@]}")")

  parts=()
  [ -n "$cost" ] && parts+=("$(c 222)$(printf '$%.2f' "$cost")${RESET}")
  if [ -n "$duration_ms" ] && [ "$level" -lt "$DROP_SESSION_TIME" ]; then
    part="$(c 245)${ICON_CLOCK} $(duration_short $(( duration_ms / 1000 )))${RESET}"
    [ -n "$api_ms" ] && [ "$level" -lt "$DROP_API_TIME" ] && part+=" $(labelled api "$(duration_short $(( api_ms / 1000 )))")"
    parts+=("$part")
  fi
  [ "${#parts[@]}" -gt 0 ] && groups+=("$(join_with "$GAP" "${parts[@]}")")

  join_with "$BAR" "${groups[@]}"
}

# fit <row function> <least detail>: the most detailed version that fits; the full one without a width
fit() {
  local build=$1 least=$2 width=$(( ${COLUMNS:-0} - RIGHT_MARGIN )) level=0 row
  while :; do
    row=$("$build" "$level")
    if [ "${COLUMNS:-0}" -eq 0 ] || [ "$level" -ge "$least" ] || [ "$(visible_width "$row")" -le "$width" ]; then
      printf '%s' "$row"
      return
    fi
    level=$(( level + 1 ))
  done
}

pin_right "$repo_row" "$clock"
glance=$(fit glance_row "$GLANCE_LEAST")
[ -n "$glance" ] && printf '\n%s' "$glance"
if [ -e "$DETAIL_FLAG" ]; then
  detail=$(fit detail_row "$DETAIL_LEAST")
  [ -n "$detail" ] && printf '\n%s' "$detail"
fi
