#!/usr/bin/env bash
# Build lazygit <version> from source with untracked files shown as " U" instead of "??"
# in the files panel, and install it to ~/.local/bin/lazygit.
#
# Usage: patch-untracked.sh <version> [--force]     e.g. patch-untracked.sh 0.66.2
#
# Only the display is changed: formatFileStatus() in pkg/gui/presentation/files.go
# gets an early return for "??". Git status parsing and file.ShortStatus are untouched,
# so tracked/untracked logic keeps working. " U" (blank index column, U in the worktree
# column) lines up with other unstaged-only statuses like " M" and " D".
#
# Idempotent: if ~/.local/bin/lazygit is already the patched build of <version>, it exits
# without doing anything (pass --force to rebuild anyway). Each build uses a fresh clone.
# Fails loudly if lazygit's source no longer looks the way this patch expects.
set -euo pipefail

die() { echo "patch-untracked: ERROR: $*" >&2; exit 1; }

VERSION="${1:-}"
VERSION="${VERSION#v}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: $0 <version> [--force]  (e.g. 0.66.2), got '${1:-}'"
FORCE="${2:-}"

INSTALL_DIR="${LAZYGIT_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_DIR/lazygit"
BUILD_SOURCE="patched-untracked-U"
TARGET_FILE="pkg/gui/presentation/files.go"
MARKER="// patch-untracked: show untracked files as \" U\""

if [ "$FORCE" != "--force" ] && [ -x "$TARGET" ]; then
  current="$("$TARGET" --version 2>/dev/null || true)"
  if [[ "$current" == *"version=$VERSION,"* && "$current" == *"build source=$BUILD_SOURCE,"* ]]; then
    echo "Already installed: $TARGET is the patched lazygit v$VERSION. Nothing to do (use --force to rebuild)."
    exit 0
  fi
fi

GO="$(command -v go || true)"
[ -n "$GO" ] || GO=/opt/homebrew/bin/go
[ -x "$GO" ] || die "Go not found (install it with: brew install go)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lazygit-patch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/lazygit"

echo "Cloning lazygit v$VERSION ..."
git -c advice.detachedHead=false clone -q --depth 1 --branch "v$VERSION" \
  https://github.com/jesseduffield/lazygit.git "$SRC" || die "could not clone tag v$VERSION"

cd "$SRC"
[ -f "$TARGET_FILE" ] || die "$TARGET_FILE not found in v$VERSION; lazygit's layout changed, update this script"

echo "Patching $TARGET_FILE ..."
# Insert the early return right after the function's opening line. The match must include the
# exact signature AND its first statement, and must occur exactly once, or nothing is written.
PATCH_MARKER="$MARKER" /usr/bin/perl -0777 -i -pe '
  BEGIN { $marker = $ENV{PATCH_MARKER}; $n = 0 }
  if (index($_, $marker) >= 0) { die "already patched, refusing to patch twice\n" }
  $n = 0 + s{
    (^func\ formatFileStatus\(file\ \*models\.File,\ restColor\ style\.TextStyle\)\ string\ \{\n)
    (\tfirstChar\ :=\ file\.ShortStatus\[0:1\]\n)
  }{$1\t$marker\n\tif file.ShortStatus == "??" {\n\t\treturn restColor.Sprint(" ") + theme.UnstagedChangesColor.Sprint("U")\n\t}\n\n$2}mx;
  END { die "expected exactly 1 match for formatFileStatus, found $n\n" if $n != 1 }
' "$TARGET_FILE" || die "patch did not apply to $TARGET_FILE; lazygit's source changed, update this script"

[ "$(grep -cF "$MARKER" "$TARGET_FILE")" = 1 ] || die "patch marker missing after edit"
[ "$(grep -rlF "$MARKER" --include='*.go' . | wc -l | tr -d ' ')" = 1 ] || die "patch marker found in more than one file"
"$GO" fmt "./${TARGET_FILE%/*}" >/dev/null
git --no-pager diff --stat
git --no-pager diff

echo "Building with $("$GO" version) ..."
COMMIT="$(git rev-parse HEAD)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GOTOOLCHAIN=local CGO_ENABLED=0 "$GO" build -trimpath -o "$WORK/lazygit-bin" \
  -ldflags "-s -w -X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE -X main.buildSource=$BUILD_SOURCE" \
  . || die "go build failed"

built="$("$WORK/lazygit-bin" --version)"
[[ "$built" == *"version=$VERSION,"* ]] || die "built binary reports unexpected version: $built"

mkdir -p "$INSTALL_DIR"
cp "$WORK/lazygit-bin" "$TARGET.new"
chmod 755 "$TARGET.new"
mv -f "$TARGET.new" "$TARGET"
echo "Installed $TARGET"
"$TARGET" --version

first="$(command -v lazygit || true)"
if [ "$first" != "$TARGET" ]; then
  echo "WARNING: 'lazygit' on PATH resolves to '${first:-nothing}', not $TARGET." >&2
  echo "         Put $INSTALL_DIR before /opt/homebrew/bin in PATH." >&2
fi
