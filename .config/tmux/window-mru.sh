#!/bin/sh
# Browser-style ctrl+tab: a most-recently-used window history across all sessions.
# Entries are "session_id:window_id", most recent first, kept in the global @mru option.
#
#   touch <entry>                          move entry to the front (run by the window/session hooks;
#                                          ignored while the switcher is open)
#   open <next|prev> <client> <current>    open the switcher popup on client
#   pick <next|prev> <client>              the switcher itself, run inside the popup
#
# The popup reads tab / shift+tab itself (a popup takes the keyboard) and switches the window behind
# it live. Letting go of ctrl or Enter stays on the highlighted window; Esc goes back. The keys and
# ctrl being let go come from the switcher-keys helper, since tmux only gets key presses. Only the
# start and end windows are moved to the front, so the next ctrl+tab returns to where the cycle started.

MAX=15
KEYS_SRC=${0%/*}/switcher-keys.c
KEYS=$HOME/.cache/tmux/switcher-keys

opt() {
  tmux show -gqv "$1"
}

# Words of $1 that are still open windows, skipping $2
prune() {
  live=$(tmux list-windows -a -F '#{session_id}:#{window_id}')
  out=
  for w in $1; do
    [ "$w" = "$2" ] && continue
    printf '%s\n' "$live" | grep -qxF -- "$w" && out="$out $w"
  done
  printf '%s' "${out# }"
}

to_front() {
  rest=$(prune "$(opt @mru)" "$1")
  tmux set -g @mru "$1${rest:+ $rest}"
}

# One "session:index name" line per entry of $1, in order
labels() {
  info=$(tmux list-windows -a -F '#{session_id}:#{window_id} #{session_name}:#{window_index} #{window_name}')
  for w in $1; do
    printf '%s\n' "$info" | awk -v w="$w" '$1 == w { sub(/^[^ ]+ /, ""); print; found = 1; exit } END { if (!found) print w }'
  done
}

count() {
  n=0
  for w in $1; do n=$((n + 1)); done
  echo "$n"
}

case $1 in
touch)
  [ "$(opt @mru-cycling)" = 1 ] || to_front "$2"
  ;;
open)
  dir=$2 client=$3 cur=$4
  rest=$(prune "$(opt @mru)" "$cur")
  [ -n "$rest" ] || exit 0
  snap=$(printf '%s\n' "$cur" $rest | head -n "$MAX" | tr '\n' ' ')
  snap=${snap% }
  tmux set -g @mru-snap "$snap"

  # Built here so the first build doesn't happen behind the popup
  if [ ! "$KEYS" -nt "$KEYS_SRC" ]; then
    mkdir -p "${KEYS%/*}"
    if ! cc -O2 -framework CoreGraphics -o "$KEYS" "$KEYS_SRC" >/dev/null 2>&1; then
      tmux display-message -c "$client" "ctrl+tab: couldn't build $KEYS_SRC"
      exit 1
    fi
  fi

  # Room for the " ▶ " marker, " (start)" and the border
  width=$(labels "$snap" | awk 'length > m { m = length } END { m += 16; print (m < 24 ? 24 : m) }')
  height=$(($(count "$snap") + 2))
  tmux display-popup -c "$client" -E -w "$width" -h "$height" -T ' recent windows ' "'$0' pick $dir '$client'"
  ;;
pick)
  dir=$2 client=$3
  snap=$(opt @mru-snap)
  lbls=$(labels "$snap")
  n=$(count "$snap")
  if [ "$dir" = prev ]; then pos=$((n - 1)); else pos=1; fi

  # Hold off the hooks while switching live, and let them back on however the popup ends
  tmux set -g @mru-cycling 1
  trap 'tmux set -g @mru-cycling 0; exit 1' HUP INT TERM

  saved=$(stty -g)
  stty -icanon -echo -icrnl min 1 time 0
  printf '\033[?25l'

  # Switch behind the popup and redraw it; drawn on fd 3 since stdout is the result below
  show() {
    target=$(printf '%s\n' $snap | sed -n "$((pos + 1))p")
    tmux switch-client -c "$client" -t "$target"
    # No newline after the last line, or the popup scrolls by one
    printf '\033[H\033[2J' >&3
    printf '%s\n' "$lbls" | awk -v p="$pos" '{
      s = (NR == 1 ? " (start)" : "")
      if (NR - 1 == p) line = sprintf("\033[7m ▶ %s%s \033[0m", $0, s)
      else line = sprintf("   %s%s", $0, s)
      printf "%s%s", (NR > 1 ? "\n" : ""), line
    }' >&3
  }

  exec 3>&1
  show
  result=$("$KEYS" | {
    while read -r key; do
      case $key in
      (next) pos=$(((pos + 1) % n)) && show ;;
      (prev) pos=$(((pos + n - 1) % n)) && show ;;
      (esc) echo cancel && exit ;;
      (enter | up) break ;;
      esac
    done
    echo "switch $pos"
  })
  exec 3>&-
  stty "$saved"
  printf '\033[?25h'

  [ -n "$result" ] || result=cancel
  action=${result%% *}
  target=$(printf '%s\n' $snap | sed -n "$((${result#* } + 1))p")

  # The start window goes second and the chosen one first, skipping the windows passed on the way
  start=${snap%% *}
  [ "$action" = cancel ] && target=$start
  tmux set -g @mru-cycling 0 \; switch-client -c "$client" -t "$target"
  to_front "$start"
  [ "$target" = "$start" ] || to_front "$target"
  ;;
esac
