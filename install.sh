#!/bin/sh
# Install the kit: copy it to ~/.claude-kit and put `newproject` on PATH.
#
# Re-run this any time you pull a new version of the kit. It is idempotent.
# Existing projects are not touched; run `newproject --update` inside each one.
set -eu

SRC="$(cd "$(dirname "$0")" && pwd)"
KIT_HOME="${CLAUDE_KIT_HOME:-$HOME/.claude-kit}"
BIN="${BIN_DIR:-$HOME/.local/bin}"

OLD=$(cat "$KIT_HOME/VERSION" 2>/dev/null || echo "")

mkdir -p "$KIT_HOME" "$BIN"
rm -rf "$KIT_HOME/template" "$KIT_HOME/bin"
cp -R "$SRC/template" "$KIT_HOME/template"
cp -R "$SRC/bin" "$KIT_HOME/bin"
cp "$SRC/VERSION" "$KIT_HOME/VERSION" 2>/dev/null || echo "unknown" > "$KIT_HOME/VERSION"

# Recorded so `newproject --self-update` knows where to git pull from.
printf '%s\n' "$SRC" > "$KIT_HOME/.source"

chmod +x "$KIT_HOME/bin/newproject" "$KIT_HOME/template/scripts/"*.sh 2>/dev/null || true
ln -sf "$KIT_HOME/bin/newproject" "$BIN/newproject"

NEW=$(cat "$KIT_HOME/VERSION")
if [ -n "$OLD" ] && [ "$OLD" != "$NEW" ]; then
  echo "kit $OLD -> $NEW"
else
  echo "kit $NEW"
fi
echo "  template   $KIT_HOME/template"
echo "  command    $BIN/newproject"
echo

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "NOTE: $BIN is not on your PATH. Add this to your shell rc:"
     echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""; echo ;;
esac

echo "new project:      newproject my-app"
echo "update the kit:   newproject --self-update"
echo "update a project: newproject --update   (run inside the project)"
