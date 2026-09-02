#!/bin/sh
# Install the kit: copy it to ~/.claude-kit and put `newproject` on PATH.
set -eu

SRC="$(cd "$(dirname "$0")" && pwd)"
KIT_HOME="${CLAUDE_KIT_HOME:-$HOME/.claude-kit}"
BIN="${BIN_DIR:-$HOME/.local/bin}"

mkdir -p "$KIT_HOME" "$BIN"
rm -rf "$KIT_HOME/template" "$KIT_HOME/bin"
cp -R "$SRC/template" "$KIT_HOME/template"
cp -R "$SRC/bin" "$KIT_HOME/bin"
chmod +x "$KIT_HOME/bin/newproject" \
         "$KIT_HOME/template/scripts/"*.sh \
         "$KIT_HOME/template/.claude/hooks/"*.sh 2>/dev/null || true

ln -sf "$KIT_HOME/bin/newproject" "$BIN/newproject"

echo "installed:"
echo "  template   $KIT_HOME/template"
echo "  command    $BIN/newproject"
echo

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "NOTE: $BIN is not on your PATH. Add this to your shell rc:"
     echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""; echo ;;
esac

echo "try:  newproject my-first-project"
