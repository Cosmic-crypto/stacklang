#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="zig-out/bin"
NAME="stacklang"

echo "Building $NAME for multiple platforms..."

# Build the default (current host) version first
echo "→ Building native version..."
if ! zig build-exe src/main.zig -fstrip; then
  echo "❌ Native compilation failed. Previous binaries preserved."
  rm -f main
  exit 1
fi

# Clean old build artifacts
echo "→ Cleaning old files..."
rm -f main
rm -rf "$OUT_DIR"
find . -name "*.pdb" -delete 2>/dev/null || true

mkdir -p "$OUT_DIR"

build() {
  local target="$1"
  local mode="$2"
  local label="$3"
  local ext="$4"

  echo "→ Building $label ($target, $mode)..."

  if zig build-exe src/main.zig \
    -target "$target" \
    -O "$mode" \
    -fstrip \
    -femit-bin="$OUT_DIR/$NAME-$label$ext"; then
    echo "   ✅ $label built successfully"
  else
    echo "   ❌ Failed to build $label"
    # Continue building other targets instead of exiting
  fi
}

# ==================== Build Matrix ====================

# -------- Linux --------
build "x86_64-linux" "ReleaseFast" "linux-x86_64-fast" ""
build "x86_64-linux" "ReleaseSmall" "linux-x86_64-small" ""
build "aarch64-linux" "ReleaseFast" "linux-arm64-fast" ""
build "aarch64-linux" "ReleaseSmall" "linux-arm64-small" ""

# -------- macOS --------
build "x86_64-macos" "ReleaseFast" "macos-x86_64-fast" ""
build "x86_64-macos" "ReleaseSmall" "macos-x86_64-small" ""
build "aarch64-macos" "ReleaseFast" "macos-arm64-fast" ""
build "aarch64-macos" "ReleaseSmall" "macos-arm64-small" ""

# -------- Windows --------
build "x86_64-windows" "ReleaseFast" "win-x86_64-fast" ".exe"
build "x86_64-windows" "ReleaseSmall" "win-x86_64-small" ".exe"
build "aarch64-windows" "ReleaseFast" "win-arm64-fast" ".exe"
build "aarch64-windows" "ReleaseSmall" "win-arm64-small" ".exe"

echo "All builds completed! Binaries are in: $OUT_DIR"
