#!/bin/bash
#
# build_dual_simulator.sh
#
# Builds both OpenGL (default) and MetalANGLE variants of Corona Simulator
# and bundles them into a single .app with the execv() launcher.
#
# Usage:
#   ./build_dual_simulator.sh [Debug|Release]
#
# The resulting .app contains:
#   Contents/MacOS/Corona Simulator         (OpenGL — default)
#   Contents/MacOS/Corona Simulator-Metal   (MetalANGLE — opt-in via Preferences)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/ratatouille.xcodeproj"
CONFIG="${1:-Debug}"

# Use Xcode's xcodebuild (xcode-select may point to CommandLineTools)
if [ -x /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild ]; then
    XCODEBUILD=/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
else
    XCODEBUILD=xcodebuild
fi

# Query build settings to find the output directories
BUILD_SETTINGS=$($XCODEBUILD -project "$PROJECT" \
    -scheme rttplayer \
    -configuration "$CONFIG" \
    -showBuildSettings 2>/dev/null)

BUILT_PRODUCTS_DIR=$(echo "$BUILD_SETTINGS" | grep '^ *BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
SYMROOT=$(echo "$BUILD_SETTINGS" | grep '^ *SYMROOT' | head -1 | sed 's/.*= //')
OBJROOT=$(echo "$BUILD_SETTINGS" | grep '^ *OBJROOT' | head -1 | sed 's/.*= //')

echo "============================================"
echo "Building dual-binary Corona Simulator"
echo "  Configuration: $CONFIG"
echo "  Products dir:  $BUILT_PRODUCTS_DIR"
echo "============================================"
echo ""

# ---------------------------------------------------------
# 1. Build the OpenGL variant (default, no Rtt_MetalANGLE)
# ---------------------------------------------------------
echo "=== [1/3] Building OpenGL variant (Corona Simulator) ==="
$XCODEBUILD -project "$PROJECT" \
    -scheme rttplayer \
    -configuration "$CONFIG" \
    build \
    CLANG_ENABLE_EXPLICIT_MODULES=NO

GL_APP="$BUILT_PRODUCTS_DIR/Corona Simulator.app"
if [ ! -d "$GL_APP" ]; then
    echo "ERROR: OpenGL build failed — .app not found at: $GL_APP"
    exit 1
fi
echo "=== OpenGL build complete ==="
echo ""

# ---------------------------------------------------------
# 2. Build the MetalANGLE variant (adds Rtt_MetalANGLE)
#    Uses separate SYMROOT and OBJROOT to avoid clobbering
#    the OpenGL build products and object files.
# ---------------------------------------------------------
METAL_SYMROOT="${SYMROOT}-Metal"
METAL_OBJROOT="${OBJROOT}-Metal"
METAL_PRODUCTS_DIR="${METAL_SYMROOT}/${CONFIG}"

echo "=== [2/3] Building MetalANGLE variant (Corona Simulator-Metal) ==="
$XCODEBUILD -project "$PROJECT" \
    -scheme rttplayer \
    -configuration "$CONFIG" \
    build \
    CLANG_ENABLE_EXPLICIT_MODULES=NO \
    "GCC_PREPROCESSOR_DEFINITIONS=\$(inherited) Rtt_MetalANGLE GL_GLEXT_PROTOTYPES" \
    "OTHER_LDFLAGS=\$(inherited) -lMetalANGLE_static_mac -langle_common_mac -langle_base_mac -langle_metal_backend_mac -langle_gl_backend_mac -langle_image_util_mac -langle_util_mac -lglslang_mac -lspirv-cross_mac -framework Metal -framework IOSurface" \
    "SYMROOT=$METAL_SYMROOT" \
    "OBJROOT=$METAL_OBJROOT"

METAL_APP="$METAL_PRODUCTS_DIR/Corona Simulator.app"
METAL_BINARY="$METAL_APP/Contents/MacOS/Corona Simulator"
if [ ! -f "$METAL_BINARY" ]; then
    echo "ERROR: MetalANGLE build failed — binary not found at: $METAL_BINARY"
    exit 1
fi
echo "=== MetalANGLE build complete ==="
echo ""

# ---------------------------------------------------------
# 3. Copy the Metal binary into the OpenGL .app bundle
#    and rename it to "Corona Simulator-Metal"
# ---------------------------------------------------------
echo "=== [3/3] Bundling Metal binary into OpenGL .app ==="
cp "$METAL_BINARY" "$GL_APP/Contents/MacOS/Corona Simulator-Metal"

echo ""
echo "============================================"
echo "SUCCESS! Dual-binary Corona Simulator built."
echo "============================================"
echo ""
echo "App bundle: $GL_APP"
echo ""
echo "Binaries:"
ls -la "$GL_APP/Contents/MacOS/Corona Simulator" "$GL_APP/Contents/MacOS/Corona Simulator-Metal"
echo ""
echo "Default renderer: OpenGL (Legacy)"
echo "To switch: Preferences → Switch to MetalANGLE → Restart"
