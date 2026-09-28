#!/usr/bin/env bash
# Install the start-product and ship-feature skills and the request-reviewer agent.
#
#   ./install.sh           install; refuse if a file you already have would change
#   ./install.sh --force   replace changed files, backing each one up first
#
# Files go into your Claude Code config directory: $CLAUDE_CONFIG_DIR if you set it,
# otherwise ~/.claude. This script never edits your CLAUDE.md. It prints the lines to
# paste into it.
set -euo pipefail

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

FORCE=0
case "${1:-}" in
  "") ;;
  --force) FORCE=1 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "install.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "install.sh: takes at most one option" >&2
  exit 2
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
FILES="skills/start-product/SKILL.md skills/ship-feature/SKILL.md agents/request-reviewer.md"
MIN_VERSION="2.1.271"

# True when version $1 is at least version $2 (dotted numbers only).
version_at_least() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".");
    for (i = 1; i <= (n > m ? n : m); i++) {
      if ((x[i] + 0) > (y[i] + 0)) exit 0;
      if ((x[i] + 0) < (y[i] + 0)) exit 1;
    }
    exit 0
  }'
}

if command -v claude >/dev/null 2>&1; then
  installed="$(claude --version 2>/dev/null | awk '{print $1}')"
  if [ -n "$installed" ] && ! version_at_least "$installed" "$MIN_VERSION"; then
    echo "Warning: Claude Code $installed is older than $MIN_VERSION, which the reviewer needs." >&2
  fi
else
  echo "Warning: 'claude' is not on your PATH. Install Claude Code $MIN_VERSION or later." >&2
fi

for f in $FILES; do
  if [ ! -f "$SRC/$f" ]; then
    echo "install.sh: $SRC/$f is missing; run this from a full copy of the repository." >&2
    exit 1
  fi
done

# Decide everything before touching anything, so a refusal leaves nothing half-installed.
conflicts=""
for f in $FILES; do
  if [ -e "$DEST/$f" ] && ! cmp -s "$SRC/$f" "$DEST/$f"; then
    conflicts="$conflicts $f"
  fi
done

if [ -n "$conflicts" ] && [ "$FORCE" -eq 0 ]; then
  echo "Not installing: these files already exist in $DEST and differ from this version:" >&2
  for f in $conflicts; do echo "  $DEST/$f" >&2; done
  echo "Nothing was changed. Run ./install.sh --force to back them up and replace them." >&2
  exit 1
fi

backup=""
if [ -n "$conflicts" ]; then
  backup="$DEST/build-harness-v2-backup-$(date +%Y%m%d-%H%M%S)-$$"
  for f in $conflicts; do
    mkdir -p "$(dirname "$backup/$f")"
    cp -p "$DEST/$f" "$backup/$f"
  done
fi

for f in $FILES; do
  if [ -e "$DEST/$f" ] && cmp -s "$SRC/$f" "$DEST/$f"; then
    echo "unchanged  $DEST/$f"
    continue
  fi
  mkdir -p "$(dirname "$DEST/$f")"
  cp "$SRC/$f" "$DEST/$f"
  echo "installed  $DEST/$f"
done

if [ -n "$backup" ]; then
  echo "Backed up the files it replaced to $backup"
fi

echo
echo "Last step, by hand: this script does not edit your CLAUDE.md."
echo "Paste the lines between the markers into $DEST/CLAUDE.md:"
if [ -f "$DEST/CLAUDE.md" ] && grep -q "use the start-product skill" "$DEST/CLAUDE.md"; then
  echo "(Your CLAUDE.md already seems to have them. Check it matches.)"
fi
echo "----- paste from here -----"
cat "$SRC/CLAUDE.md.snippet"
echo "----- to here -----"
echo "Then start a new Claude Code session."
