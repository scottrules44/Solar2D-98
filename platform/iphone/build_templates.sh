#!/bin/bash
#
# Checks exit value for error
#
set -ex
checkError() {
    if [ $? -ne 0 ]
    then
        echo "Exiting due to errors (above)"
        exit 1
    fi
}
: "${TEMPLATE_TARGET:=template}"
TEMPLATE_TARGET_SUFFIX="${TEMPLATE_TARGET#template}"

# Passed in arguments
# $1 SDK_VERSION
if [ -z "$1" ]
then	
	SDK_VERSION=$(xcrun --sdk iphoneos --show-sdk-version)
else
	SDK_VERSION=$1

	if [ ! -z "$2" ]
	then
		CORONA_BUILD_ID=$2
	else
		CORONA_BUILD_ID="2100.9999"
	fi
	export CORONA_BUILD_ID
fi


path=$(cd "$(dirname "$0")" && pwd)

# Summarize xcodebuild output to stdout but save full output in separate file
XCODE_LOG_FILTERS="^    export |clang -x |libtool -static |^    cd $path"

FULL_LOG_FILE="iphone-build_templates-xcodebuild.log"
if [ "$WORKSPACE" != "" ]
then
	FULL_LOG_FILE="$WORKSPACE/$FULL_LOG_FILE"
fi

echo "### Full xcodebuild output can be found in $FULL_LOG_FILE"

# Prerequisites
# -----------------------------------------------------------------------------

# setup
# -----------------------------------------------------------------------------
echo "Creating directories:"
rm -rf "$path/template" "$path/template-dSYM"
mkdir -pv "$path/template"
mkdir -pv "$path/template-dSYM"


# Utility method
# -----------------------------------------------------------------------------

# $1 device (e.g. ipad or iphone)
# $2 architecture (e.g. device or simulator)
# $3 version
# $4 configuration (e.g. trial, basic)
# $5 target (e.g. template)
# $6 extension (e.g. 'app' or 'a')
build_target() {
	DEVICE=$1
	ARCHITECTURE=$2
	VERSION=$3
	CONFIGURATION=$4
	TARGET=$5
	EXTENSION=$6

	export SUPPRESS_APP_SIGN=1

	# PRODUCT_NAME=template
	PRODUCT_NAME=$TARGET
	PRODUCT_NAME_REAL=${PRODUCT_NAME%$TEMPLATE_TARGET_SUFFIX}

	if [ -z "$EXTENSION" ]
	then
		EXTENSION=app
	fi

	PRODUCT_DST=${PRODUCT_NAME}.${EXTENSION}
	PRODUCT_DST_REAL="${PRODUCT_NAME%$TEMPLATE_TARGET_SUFFIX}.${EXTENSION}"

	DST_ROOT=$DEVICE
	SDK_BASE=iphoneos
	if [ "$ARCHITECTURE" = "simulator" ]
	then
		SDK_BASE=iphonesimulator
		DST_ROOT=$DEVICE-sim
	fi
	SDK=$SDK_BASE$VERSION

	echo ""
	echo "$DEVICE $VERSION $TARGET $CONFIGURATION ($ARCHITECTURE)"
	echo "-------------------------------------------------------"

	
	mkdir -pv "$path/template/$DST_ROOT/$VERSION/$CONFIGURATION"
	mkdir -pv "$path/template-dSYM/$DST_ROOT/$VERSION/$CONFIGURATION"
	rm -vrf "$path/template/$DST_ROOT/$VERSION/$CONFIGURATION/${PRODUCT_DST}" 
	rm -vrf "$path/template-dSYM/$DST_ROOT/$VERSION/$CONFIGURATION/${PRODUCT_DST}.dSYM" 
	rm -vrf "$path/template/$DST_ROOT/$VERSION/$CONFIGURATION/${PRODUCT_DST_REAL}" 
	rm -vrf "$path/template-dSYM/$DST_ROOT/$VERSION/$CONFIGURATION/${PRODUCT_DST_REAL}.dSYM" 

	echo "Running: xcodebuild -project '$path'/ratatouille.xcodeproj -target '$TARGET' -configuration Release -sdk '$SDK'" SYMROOT="$path/build"
	EXTRA_BUILD_SETTINGS=()
	if [ -n "$TEMPLATE_TARGET_SUFFIX" ]
	then
		# For angle builds: supply compat shim headers (OpenGLES/ES2/gl.h etc.) needed
		# by macCatalyst sub-targets, MetalANGLE public headers, and glslang headers
		# needed by angle_base sub-project targets. Absolute paths avoid $(SRCROOT)
		# resolution issues in sub-project (DependantBuilds) context on Xcode 26+.
		EXTRA_BUILD_SETTINGS=(
			"HEADER_SEARCH_PATHS=$OPENGL_COMPAT $METALANGLE_INCLUDE $GLSLANG_DIR \$(inherited)"
			"GCC_PREPROCESSOR_DEFINITIONS=\$(inherited) Rtt_EGL"
			"ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES=YES"
		)
	fi
	xcodebuild -project "$path"/ratatouille.xcodeproj -target "$TARGET" -configuration Release -sdk "$SDK" SYMROOT="$path/build" "${EXTRA_BUILD_SETTINGS[@]}" 2>&1 | tee -a "$FULL_LOG_FILE" | egrep -v "$XCODE_LOG_FILTERS"
    checkError

	SUFFIX=$SDK_BASE

	# Move build product to final location
	cp -Xr "$path/build/Release-$SUFFIX/${PRODUCT_DST}" "$path/template/$DST_ROOT/$VERSION/$CONFIGURATION/${PRODUCT_DST}"

	if [ "app" = $EXTENSION ]
	then
		# Move dsym for .app executables
		cp -Xr "$path/build/Release-$SUFFIX/${PRODUCT_DST}.dSYM" "$path/template-dSYM/$DST_ROOT/$VERSION/$CONFIGURATION/${PRODUCT_DST}.dSYM"
	fi

	if [  "$PRODUCT_DST" != "$PRODUCT_DST_REAL" ]
	then
	(
		cd "$path/template/$DST_ROOT/$VERSION/$CONFIGURATION"
		mv -v "$PRODUCT_DST" "$PRODUCT_DST_REAL"

		if [ "app" = $EXTENSION ]
		then
			mv -v "$PRODUCT_DST_REAL/$PRODUCT_NAME" "$PRODUCT_DST_REAL/$PRODUCT_NAME_REAL"
			(
				cd "$path/template-dSYM/$DST_ROOT/$VERSION/$CONFIGURATION/"
				mv -v "${PRODUCT_DST}.dSYM" "${PRODUCT_DST_REAL}.dSYM"
				find . -name "$PRODUCT_NAME" -type f -execdir mv -v {} template \;
			)
		fi
	)	
	fi
}


# iOS TEMPLATES
# --------------------------------------------------------------------------------------------------

# For angle builds, MetalANGLE.framework is no longer a sub-project target dependency
# (removed to fix macCatalyst propagation issues). Pre-build it here so that it lands
# in SYMROOT = $path/build, which Xcode implicitly adds to FRAMEWORK_SEARCH_PATHS via
# BUILT_PRODUCTS_DIR — making <MetalANGLE/MGLKit.h> visible when libplayer-core-angle
# and CoronaCards-angle are compiled.
if [ -n "$TEMPLATE_TARGET_SUFFIX" ]
then
    METALANGLE_PROJECT="$path/../../external/MetalANGLE/ios/xcode/OpenGLES.xcodeproj"
    METALANGLE_INCLUDE="$path/../../external/MetalANGLE/include"
    GLSLANG_DIR="$path/../../external/MetalANGLE/third_party/glslang/src"

    echo "Pre-building MetalANGLE.framework for iphoneos (angle build)"
    xcodebuild build \
        -project "$METALANGLE_PROJECT" \
        -target MetalANGLE \
        -configuration Release \
        -sdk iphoneos \
        SYMROOT="$path/build" \
        SKIP_INSTALL=YES \
        DEPLOYMENT_POSTPROCESSING=NO \
        "OTHER_LDFLAGS=-weak_framework OpenGLES \$(inherited)" \
        2>&1 | tee -a "$FULL_LOG_FILE" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:|Undefined symbol|ld:)" || true
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "=== MetalANGLE iphoneos build failed — last 150 lines of log ==="
        tail -150 "$FULL_LOG_FILE"
        echo "Exiting due to errors (above)"; exit 1
    fi

    echo "Pre-building MetalANGLE.framework for iphonesimulator (angle build)"
    xcodebuild build \
        -project "$METALANGLE_PROJECT" \
        -target MetalANGLE \
        -configuration Release \
        -sdk iphonesimulator \
        SYMROOT="$path/build" \
        SKIP_INSTALL=YES \
        DEPLOYMENT_POSTPROCESSING=NO \
        "OTHER_LDFLAGS=-weak_framework OpenGLES \$(inherited)" \
        2>&1 | tee -a "$FULL_LOG_FILE" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:|Undefined symbol|ld:)" || true
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "=== MetalANGLE iphonesimulator build failed — last 150 lines of log ==="
        tail -150 "$FULL_LOG_FILE"
        echo "Exiting due to errors (above)"; exit 1
    fi

    # Create OpenGLES compatibility shim headers so that macCatalyst sub-targets
    # (e.g. tachyon/CoronaCards built with SUPPORTS_MACCATALYST=YES) can resolve
    # <OpenGLES/ES2/gl.h> via MetalANGLE's GLES2 headers.
    OPENGL_COMPAT="$path/build/opengl-compat"
    mkdir -p "$OPENGL_COMPAT/OpenGLES/ES2" \
             "$OPENGL_COMPAT/OpenGLES/ES3" \
             "$OPENGL_COMPAT/OpenGLES/ES1"
    printf '#pragma once\n#include <GLES2/gl2.h>\n#ifndef GL_BGRA\n#define GL_BGRA GL_BGRA_EXT\n#endif\n' \
        > "$OPENGL_COMPAT/OpenGLES/ES2/gl.h"
    printf '#pragma once\n#include <GLES2/gl2ext.h>\n#ifndef GL_BGRA\n#define GL_BGRA GL_BGRA_EXT\n#endif\n' \
        > "$OPENGL_COMPAT/OpenGLES/ES2/glext.h"
    printf '#pragma once\n#include <GLES3/gl3.h>\n' \
        > "$OPENGL_COMPAT/OpenGLES/ES3/gl.h"
    printf '#pragma once\n#include <GLES3/gl3.h>\n' \
        > "$OPENGL_COMPAT/OpenGLES/ES3/gl2.h"
    printf '/* ES1 not supported by MetalANGLE */\n' \
        > "$OPENGL_COMPAT/OpenGLES/ES1/gl.h"
    printf '/* ES1 glext not supported by MetalANGLE */\n' \
        > "$OPENGL_COMPAT/OpenGLES/ES1/glext.h"
fi

# iPhone basic (i.e. for subscribers)
build_target "iphone" "device" "$SDK_VERSION" "basic" "$TEMPLATE_TARGET"
checkError

# iPhone trial
ln -s basic "$path/template/iphone/$SDK_VERSION/trial" || true

# iPhone all is now the same as basic
ln -s basic "$path/template/iphone/$SDK_VERSION/all" || true

# Templates are universal now so iPad versions are just mirrors of the iPhone
ln -s iphone "$path/template/ipad" || true

# Plugins: libtemplate.a
TEMPLATE_DIR=$path/template/iphone/$SDK_VERSION/basic
cp -Xrv "$path"/../../tools/buildsys-ios/libtemplate "$TEMPLATE_DIR"

build_target "iphone" "device" "$SDK_VERSION" "basic" "lib$TEMPLATE_TARGET" "a"
checkError
LIBTEMPLATE_DIR=$TEMPLATE_DIR/libtemplate
mv -v "$TEMPLATE_DIR"/libtemplate.a "$LIBTEMPLATE_DIR"/.

# XCODE SIMULATOR TEMPLATES
# --------------------------------------------------------------------------------------------------

# iPhone basic (i.e. for subscribers)
build_target "iphone" "simulator" "$SDK_VERSION" "basic" "$TEMPLATE_TARGET"

# iPhone trial
ln -s basic "$path/template/iphone-sim/$SDK_VERSION/trial" || true

# iPhone all is now the same as basic
ln -s basic "$path/template/iphone-sim/$SDK_VERSION/all" || true

# Templates are universal now so iPad versions are just mirrors of the iPhone
ln -s iphone-sim "$path/template/ipad-sim" || true

# Plugins: libtemplate.a
TEMPLATE_DIR=$path/template/iphone-sim/$SDK_VERSION/basic
cp -Xrv "$path"/../../tools/buildsys-ios/libtemplate "$TEMPLATE_DIR"

build_target "iphone" "simulator" "$SDK_VERSION" "basic" "lib$TEMPLATE_TARGET" "a"
LIBTEMPLATE_DIR=$TEMPLATE_DIR/libtemplate
mv -v "$TEMPLATE_DIR"/libtemplate.a "$LIBTEMPLATE_DIR"/.



templateArchive=$(date "+template$TEMPLATE_TARGET_SUFFIX.%Y.%m.%d.zip")
zip -ry "$path/$templateArchive" "$path/template"
checkError

dsymArchive=$(date "+template$TEMPLATE_TARGET_SUFFIX-dSYM.%Y.%m.%d.zip")
zip -ry "$path/$dsymArchive" "$path/template-dSYM"
checkError
