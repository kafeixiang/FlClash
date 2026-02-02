#!/usr/bin/env bash
set -euo pipefail

# Locate project root by walking up from script location until we find pubspec.yaml
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
while [ "$PROJECT_DIR" != "/" ]; do
  if [ -f "$PROJECT_DIR/pubspec.yaml" ] && [ -d "$PROJECT_DIR/core" ]; then
    break
  fi
  PROJECT_DIR="$(dirname "$PROJECT_DIR")"
done

if [ "$PROJECT_DIR" = "/" ]; then
  echo "Error: Could not find project root (no pubspec.yaml found)" >&2
  exit 1
fi

# Build tool is always relative to this script
BUILD_TOOL_DIR="$SCRIPT_DIR/build_tool"

# Find Dart executable
if [ -n "${DART_SDK:-}" ]; then
  DART="$DART_SDK/bin/dart"
elif command -v dart >/dev/null 2>&1; then
  DART="$(command -v dart)"
elif [ -x "$HOME/fvm/default/bin/dart" ]; then
  DART="$HOME/fvm/default/bin/dart"
else
  echo "Error: dart not found. Set DART_SDK or ensure dart is in PATH." >&2
  exit 1
fi

# Run from build_tool directory so it finds its own .dart_tool/package_config.json
cd "$BUILD_TOOL_DIR"

exec "$DART" run build_tool "$@" --root-dir "$PROJECT_DIR"
