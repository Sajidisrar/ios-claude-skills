#!/usr/bin/env bash
# Set the release version in every manifest, so they never drift apart.
# Usage: scripts/bump-version.sh <X.Y.Z>
#        scripts/bump-version.sh --check [X.Y.Z]   # verify they all match (and equal X.Y.Z if given)

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

MANIFESTS=(
  plugin.json
  .claude-plugin/plugin.json
  .claude-plugin/marketplace.json
  .codex-plugin/plugin.json
  .agents/plugins/marketplace.json
)

versions() {
  for f in "${MANIFESTS[@]}"; do
    printf '%s %s\n' "$(grep -oE '"version": *"[^"]+"' "$f" | sed -E 's/.*"([^"]+)"$/\1/')" "$f"
  done
}

if [ "${1:-}" = "--check" ]; then
  expected="${2:-}"
  distinct="$(versions | cut -d' ' -f1 | sort -u)"
  if [ "$(printf '%s\n' "$distinct" | wc -l | tr -d ' ')" != "1" ]; then
    echo "Manifest versions disagree:" >&2; versions >&2; exit 1
  fi
  if [ -n "$expected" ] && [ "$distinct" != "$expected" ]; then
    echo "Manifests say $distinct, expected $expected." >&2; exit 1
  fi
  echo "All manifests at $distinct"
  exit 0
fi

new="${1:-}"
if ! printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Usage: scripts/bump-version.sh <X.Y.Z> | --check [X.Y.Z]" >&2
  exit 1
fi

for f in "${MANIFESTS[@]}"; do
  sed -i.bak -E "s/(\"version\": *\")[^\"]+\"/\1$new\"/" "$f" && rm "$f.bak"
done
versions
grep -qs "^## \[$new\]" CHANGELOG.md || echo "Reminder: add a '## [$new] - $(date +%F)' section to CHANGELOG.md."
