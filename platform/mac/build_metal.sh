#!/bin/bash -ex

CUSTOM_ID=$1
S3_BUCKET=$2
CWD=$(dirname "$0")

# Summarize xcodebuild output to stdout but save full output in separate file
XCODE_LOG_FILTERS="^    export |clang -x |libtool -static |^    cd $CWD"

FULL_LOG_FILE="mac-build-metal-xcodebuild.log"
if [ "$WORKSPACE" != "" ]
then
	FULL_LOG_FILE="$WORKSPACE/$FULL_LOG_FILE"
fi

echo "### Full xcodebuild output can be found in $FULL_LOG_FILE"

# Note build machine details and Xcode version
uname -a >> "$FULL_LOG_FILE"
xcodebuild -version >> "$FULL_LOG_FILE"

# Corona Simulator (MetalANGLE variant)
# Adds Rtt_MetalANGLE and GL_GLEXT_PROTOTYPES preprocessor defines
# Links MetalANGLE static libraries and Metal/IOSurface frameworks via OTHER_LDFLAGS

xcodebuild -project "$CWD"/ratatouille.xcodeproj -target rttplayer -configuration Release \
	CUSTOM_BUILD_ID="$CUSTOM_ID" BUILD_BUCKET="$S3_BUCKET" \
	CLANG_ENABLE_EXPLICIT_MODULES=NO \
	'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) Rtt_MetalANGLE GL_GLEXT_PROTOTYPES' \
	'OTHER_LDFLAGS=$(inherited) -lMetalANGLE_static_mac -langle_common_mac -langle_base_mac -langle_metal_backend_mac -langle_gl_backend_mac -langle_image_util_mac -langle_util_mac -lglslang_mac -lspirv-cross_mac -framework Metal -framework IOSurface' \
	2>&1 | tee -a "$FULL_LOG_FILE" | egrep -v "$XCODE_LOG_FILTERS"

if [ $? -ne 0 ]
then
	exit -1
fi
