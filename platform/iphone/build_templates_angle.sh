#!/bin/bash
#
# Build iOS templates with MetalANGLE support
# This builds the template-angle and libtemplate-angle targets for iOS device and simulator
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Building iOS Templates with MetalANGLE"
echo "========================================"

# Build MetalANGLE for iOS first (device and simulator)
METALANGLE_DIR="$SCRIPT_DIR/../../external/MetalANGLE"

if [ ! -f "$METALANGLE_DIR/ios/xcode/fetchDependencies.sh" ]; then
    echo "Error: MetalANGLE submodule not initialized."
    echo "Please run: git submodule update --init external/MetalANGLE"
    exit 1
fi

cd "$METALANGLE_DIR/ios/xcode"

# Fetch dependencies if needed
if [ ! -d "$METALANGLE_DIR/third_party/angle_deps" ]; then
    echo "Fetching MetalANGLE dependencies..."
    ./fetchDependencies.sh
fi

# Build MetalANGLE for iOS device
echo ""
echo "Building MetalANGLE for iOS device..."
xcodebuild build \
    -project OpenGLES.xcodeproj \
    -scheme MetalANGLE_static \
    -sdk iphoneos \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Build MetalANGLE for iOS simulator
echo ""
echo "Building MetalANGLE for iOS simulator..."
xcodebuild build \
    -project OpenGLES.xcodeproj \
    -scheme MetalANGLE_static \
    -sdk iphonesimulator \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Now build the templates with the angle target
cd "$SCRIPT_DIR"

echo ""
echo "Building iOS templates (template-angle)..."
export TEMPLATE_TARGET=template-angle
./build_templates.sh "$@"

echo ""
echo "========================================"
echo "MetalANGLE iOS templates build completed!"
echo "========================================"
