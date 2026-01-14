#!/bin/bash
#
# Build Corona Simulator with MetalANGLE support
# This script builds both MetalANGLE and the Corona Simulator with Metal rendering
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
METALANGLE_DIR="$SCRIPT_DIR/../../external/MetalANGLE"

CONFIGURATION="${1:-Release}"

echo "========================================"
echo "Building Corona Simulator with MetalANGLE"
echo "Configuration: $CONFIGURATION"
echo "========================================"

# Step 1: Build MetalANGLE
echo ""
echo "Step 1: Building MetalANGLE..."
echo "----------------------------------------"
"$SCRIPT_DIR/build_metalangle.sh" "$CONFIGURATION"

# Step 2: Build Corona Simulator with MetalANGLE
echo ""
echo "Step 2: Building Corona Simulator..."
echo "----------------------------------------"

cd "$PROJECT_DIR"

# Build with MetalANGLE xcconfig
xcodebuild build \
    -project ratatouille.xcodeproj \
    -target rttplayer \
    -configuration "$CONFIGURATION" \
    -xcconfig MetalANGLE.xcconfig \
    SYMROOT="$PROJECT_DIR/build-angle" \
    GCC_PREPROCESSOR_DEFINITIONS='$(inherited) Rtt_MetalANGLE=1' \
    HEADER_SEARCH_PATHS='$(inherited) "$(SRCROOT)/../../external/MetalANGLE/include" "$(SRCROOT)/../../external/MetalANGLE/ios/xcode/MGLKit"' \
    LIBRARY_SEARCH_PATHS='$(inherited) "$(SRCROOT)/../../external/MetalANGLE/build"' \
    OTHER_LDFLAGS='$(inherited) -lMetalANGLE_static_mac -framework Metal -framework MetalKit -framework IOSurface -framework QuartzCore -framework CoreVideo'

echo ""
echo "========================================"
echo "Build completed!"
echo ""
echo "The MetalANGLE-enabled Corona Simulator is at:"
echo "  $PROJECT_DIR/build-angle/$CONFIGURATION/Corona Simulator.app"
echo "========================================"
