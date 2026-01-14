#!/bin/bash
#
# Build MetalANGLE static library for macOS
# This script builds the MetalANGLE static library and copies it to the expected location
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METALANGLE_DIR="$SCRIPT_DIR/../../external/MetalANGLE"
OUTPUT_DIR="$SCRIPT_DIR/../../external/MetalANGLE/build"

CONFIGURATION="${1:-Release}"

echo "==================================="
echo "Building MetalANGLE for macOS"
echo "Configuration: $CONFIGURATION"
echo "==================================="

# Check if MetalANGLE submodule is initialized
if [ ! -f "$METALANGLE_DIR/ios/xcode/fetchDependencies.sh" ]; then
    echo "Error: MetalANGLE submodule not initialized."
    echo "Please run: git submodule update --init external/MetalANGLE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Navigate to MetalANGLE Xcode project directory
cd "$METALANGLE_DIR/ios/xcode"

# Fetch dependencies if needed
if [ ! -d "$METALANGLE_DIR/third_party/angle_deps" ]; then
    echo "Fetching MetalANGLE dependencies..."
    ./fetchDependencies.sh
fi

# Build MetalANGLE static library for macOS
echo "Building MetalANGLE_static_mac..."
xcodebuild build \
    -project OpenGLES.xcodeproj \
    -scheme MetalANGLE_static_mac \
    -sdk macosx \
    -configuration "$CONFIGURATION" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    SYMROOT="$OUTPUT_DIR"

# Find and copy the built library
BUILT_LIB=$(find "$OUTPUT_DIR" -name "libMetalANGLE_static_mac.a" -type f | head -1)

if [ -n "$BUILT_LIB" ]; then
    cp -v "$BUILT_LIB" "$OUTPUT_DIR/libMetalANGLE_static_mac.a"
    echo ""
    echo "==================================="
    echo "Build completed successfully!"
    echo "Library: $OUTPUT_DIR/libMetalANGLE_static_mac.a"
    echo "==================================="
else
    echo "Error: Could not find built library"
    exit 1
fi
