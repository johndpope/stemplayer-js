#!/bin/bash
# Build script for audio_palette Rust library

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_DIR/rust"

echo "Building Rust library..."

cd "$RUST_DIR"

# Build for macOS (universal binary)
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Building for macOS..."

    # Build for x86_64
    cargo build --release --target x86_64-apple-darwin 2>/dev/null || true

    # Build for arm64
    cargo build --release --target aarch64-apple-darwin 2>/dev/null || true

    # Check if we can create universal binary
    if [ -f "target/x86_64-apple-darwin/release/libaudio_palette.dylib" ] && \
       [ -f "target/aarch64-apple-darwin/release/libaudio_palette.dylib" ]; then
        echo "Creating universal binary..."
        lipo -create \
            target/x86_64-apple-darwin/release/libaudio_palette.dylib \
            target/aarch64-apple-darwin/release/libaudio_palette.dylib \
            -output target/release/libaudio_palette.dylib
    else
        # Fall back to native build
        cargo build --release
    fi

    # Copy to macOS project
    mkdir -p "$PROJECT_DIR/macos/Runner/Libs"
    cp target/release/libaudio_palette.dylib "$PROJECT_DIR/macos/Runner/Libs/"
    echo "Copied library to macos/Runner/Libs/"
fi

echo "Build complete!"
