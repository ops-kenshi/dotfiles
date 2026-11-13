#!/usr/bin/env bash
# Replace lazygit's "??" untracked-file marker with "U" by building a patched lazygit.
#
# Run this after every `brew upgrade lazygit`.
#   1. If patch-untracked.sh exists (written by a previous Claude session), it runs that
#      script directly, with no Claude involved.
#   2. If that script is missing or fails (e.g. lazygit's source changed), it starts a
#      Claude Code session with the full context to (re)do the patch and update the script.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_SCRIPT="$DIR/patch-untracked.sh"
LOG="$DIR/patch-untracked.log"
BREW_LG=/opt/homebrew/bin/lazygit
VERSION="$("$BREW_LG" --version | sed -n 's/.*version=\([^,]*\),.*/\1/p')"

if [ -x "$PATCH_SCRIPT" ]; then
  echo "Running $PATCH_SCRIPT for lazygit v$VERSION ..."
  if "$PATCH_SCRIPT" "$VERSION" >"$LOG" 2>&1; then
    echo "Done. Patched lazygit v$VERSION installed (log: $LOG)."
    exit 0
  fi
  echo "Patch script failed (log: $LOG). Starting Claude to fix it..."
  FAILURE="The existing $PATCH_SCRIPT failed for v$VERSION; its output is in $LOG. Read it first, then fix the script."
else
  FAILURE="There is no $PATCH_SCRIPT yet; this is the first run."
fi

read -r -d '' PROMPT <<EOF
I want lazygit's files panel to show "U" instead of "??" for untracked (new) files.

Context:
- lazygit is installed with Homebrew at $BREW_LG, version v$VERSION (macOS, arm64).
- "??" is git's porcelain status for untracked files. lazygit prints it as-is, and there is no config
  option to change it (checked against lazygit 0.66.2's config), so this has to be a source patch.
- My lazygit config is ~/.config/lazygit/config.yml (symlinked from
  ~/Library/Application Support/lazygit/config.yml). It uses Nerd Font file icons and a delta
  diffRenderer. Don't change it.
- $FAILURE

What to do:
1. Clone github.com/jesseduffield/lazygit at tag v$VERSION into a temp dir and find where the
   files/commit-files tree renders the short status "??". Only change what is displayed: keep it
   two characters wide ("U " or " U", matching how other single-letter statuses align), and leave
   git status parsing and logic such as HasUntracked or tracked/untracked checks alone.
2. Build it with Go (install Go via Homebrew first if it's missing; ask me before installing
   anything). Install the binary to ~/.local/bin/lazygit, make sure that comes before
   /opt/homebrew/bin on my PATH, and tell me if it doesn't.
3. Write $PATCH_SCRIPT: a standalone, idempotent bash script that takes the lazygit version as \$1,
   clones that tag, applies the change with a robust edit (fail loudly if the target code isn't
   found, never patch silently in the wrong place), builds and installs to ~/.local/bin/lazygit.
   chmod +x it. The goal is that future runs of $DIR/fix-untracked-marker.sh need no Claude.
4. Before saying it works, confirm the patched binary's --version and that it shows "U" for an
   untracked file in a scratch repo.
EOF

cd "$DIR" && exec claude "$PROMPT"
