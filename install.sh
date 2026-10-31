#!/usr/bin/env bash
# Install ios-claude-skills into a Claude Code / Cursor / Copilot / Gemini CLI project or user directory.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash -s -- [options]
#
# Options:
#   --tool <claude|cursor|copilot|gemini|codex>   Target tool (default: claude)
#   --scope <project|user>                        Install location (default: project)
#   --skill <name>                                Install only this one skill (default: all)
#   -h, --help                                     Show this help

set -euo pipefail

REPO_URL="https://github.com/Sajidisrar/ios-claude-skills.git"
TOOL="claude"
SCOPE="project"
ONLY_SKILL=""

# Inlined rather than read back from "$0": under `curl | bash`, $0 is "bash",
# not this file.
usage() {
  cat <<'EOF'
Install ios-claude-skills into a Claude Code / Cursor / Copilot / Gemini CLI project or user directory.
Usage:
  curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash -s -- [options]

Options:
  --tool <claude|cursor|copilot|gemini|codex>   Target tool (default: claude)
  --scope <project|user>                        Install location (default: project)
  --skill <name>                                Install only this one skill (default: all)
  -h, --help                                     Show this help
EOF
}

need_value() {
  if [ $# -lt 2 ] || [ -z "$2" ]; then
    echo "Option $1 requires a value." >&2
    usage >&2
    exit 1
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) need_value "$@"; TOOL="$2"; shift 2 ;;
    --scope) need_value "$@"; SCOPE="$2"; shift 2 ;;
    --skill) need_value "$@"; ONLY_SKILL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

case "$TOOL" in
  claude)  DEST_PROJECT=".claude/skills";  DEST_USER="$HOME/.claude/skills" ;;
  cursor)  DEST_PROJECT=".cursor/skills";  DEST_USER="$HOME/.cursor/skills" ;;
  copilot) DEST_PROJECT=".github/skills";  DEST_USER="" ;;
  gemini)  DEST_PROJECT=".gemini/skills";  DEST_USER="$HOME/.gemini/skills" ;;
  codex)
    echo "Codex reads this repo's skills/ directory directly via its own plugin manifest — nothing to copy."
    echo
    echo "Run:"
    echo "  codex plugin marketplace add Sajidisrar/ios-claude-skills"
    echo "  codex plugin add ios-claude-skills@ios-claude-skills"
    exit 0
    ;;
  *)
    echo "Unknown --tool '$TOOL'. Expected one of: claude, cursor, copilot, gemini, codex" >&2
    exit 1
    ;;
esac

if [ "$SCOPE" = "user" ]; then
  if [ -z "$DEST_USER" ]; then
    echo "Tool '$TOOL' has no documented user-level scope — use --scope project instead." >&2
    exit 1
  fi
  DEST="$DEST_USER"
elif [ "$SCOPE" = "project" ]; then
  DEST="$DEST_PROJECT"
else
  echo "Unknown --scope '$SCOPE'. Expected 'project' or 'user'." >&2
  exit 1
fi

# Resolve the source: a local clone this script lives in, or fetch a fresh one.
# Only trust SCRIPT_DIR when the script was run from a real file. Under
# `curl | bash` there is no file, dirname falls back to ".", and the current
# directory's unrelated skills/ folder would be installed instead.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi
CLEANUP_DIR=""

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills" ] && [ -f "$SCRIPT_DIR/.claude-plugin/plugin.json" ]; then
  SOURCE="$SCRIPT_DIR/skills"
else
  TMP_DIR="$(mktemp -d)"
  CLEANUP_DIR="$TMP_DIR"
  echo "Fetching ios-claude-skills..."
  git clone --depth 1 --quiet "$REPO_URL" "$TMP_DIR"
  SOURCE="$TMP_DIR/skills"
fi

cleanup() {
  # An `if`, not `[ ... ] && rm`: a false test as the trap's last command
  # would become the script's exit status, failing every local-clone install.
  if [ -n "$CLEANUP_DIR" ]; then
    rm -rf "$CLEANUP_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$DEST"

if [ -n "$ONLY_SKILL" ]; then
  if [ ! -d "$SOURCE/$ONLY_SKILL" ]; then
    echo "No skill named '$ONLY_SKILL' found under skills/." >&2
    exit 1
  fi
  cp -R "$SOURCE/$ONLY_SKILL" "$DEST/"
  echo "Installed $ONLY_SKILL -> $DEST/$ONLY_SKILL"
else
  count=0
  for d in "$SOURCE"/*/; do
    # Strip the glob's trailing slash: some cp implementations (notably
    # macOS/BSD cp) copy a trailing-slash source's *contents* into the
    # destination instead of the directory itself, which would flatten
    # every skill's files into one shared DEST, overwriting each other.
    src="${d%/}"
    name="$(basename "$src")"
    cp -R "$src" "$DEST/"
    count=$((count + 1))
  done
  echo "Installed $count skills -> $DEST"
fi

echo "Restart $TOOL (or start a new session) so it picks up the new skills."
