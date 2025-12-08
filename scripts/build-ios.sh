#!/bin/bash
#
# Copyright © 2025 Agora
# This file is part of TEN Framework, an open source project.
# Licensed under the Apache License, Version 2.0, with certain conditions.
# Refer to the "LICENSE" file in the root directory for more information.
#
# Build script for TEN VAD iOS XCFramework with statically linked ONNX Runtime
# This creates a self-contained framework that doesn't require separate ONNX Runtime at runtime

set -e

# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ONNX Runtime pod archive path
if [ -z "$ORT_POD_PATH" ]; then
    echo "Error: ORT_POD_PATH environment variable not set"
    echo ""
    echo "Please download and extract the ONNX Runtime pod archive:"
    echo "  1. Download: https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.20.0.zip"
    echo "  2. Extract the archive"
    echo "  3. Set ORT_POD_PATH to the extracted directory:"
    echo "     export ORT_POD_PATH=/path/to/pod-archive-onnxruntime-c-1.20.0"
    echo "     bash build-ios.sh"
    exit 1
fi

if [ ! -d "$ORT_POD_PATH" ]; then
    echo "Error: ONNX Runtime pod archive not found at $ORT_POD_PATH"
    echo "Please verify the path and try again"
    exit 1
fi

ORT_HEADERS="${ORT_POD_PATH}/Headers"
ORT_XCFRAMEWORK="${ORT_POD_PATH}/onnxruntime.xcframework"

if [ ! -d "$ORT_XCFRAMEWORK" ]; then
    echo "Error: ONNX Runtime xcframework not found at $ORT_XCFRAMEWORK"
    exit 1
fi

echo "Using ONNX Runtime from: $ORT_POD_PATH"

# Build settings
BUILD_DIR="${PROJECT_ROOT}/build/iOS-static-temp"
OUTPUT_DIR="${PROJECT_ROOT}/lib/iOS"
MIN_IOS_VERSION="13.0"

# Source files to compile
SOURCE_FILES=(
    "${PROJECT_ROOT}/src/aed.cc"
    "${PROJECT_ROOT}/src/biquad.cc"
    "${PROJECT_ROOT}/src/fftw.c"
    "${PROJECT_ROOT}/src/fscvrt.cc"
    "${PROJECT_ROOT}/src/pitch_est.cc"
    "${PROJECT_ROOT}/src/stft.cc"
    "${PROJECT_ROOT}/src/ten_vad.cc"
)

# Clean and create build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Function to build framework for a specific platform and architecture
build_framework() {
    local platform=$1
    local arch=$2
    local sdk=$3
    local platform_name=$4

    echo ""
    echo "=========================================="
    echo "Building for ${platform_name} (${arch})..."
    echo "=========================================="

    local build_subdir="${BUILD_DIR}/${platform}-${arch}"
    mkdir -p "${build_subdir}"
    cd "${build_subdir}"

    local sdk_path=$(xcrun --sdk ${sdk} --show-sdk-path)
    echo "SDK Path: ${sdk_path}"

    # Set target platform for proper identification in XCFramework
    local target_platform=""
    if [ "${platform}" == "device" ]; then
        target_platform="-target ${arch}-apple-ios${MIN_IOS_VERSION}"
    else
        target_platform="-target ${arch}-apple-ios${MIN_IOS_VERSION}-simulator"
    fi

    # Get the ONNX Runtime static library path
    local ort_lib=""
    if [ "${platform}" == "device" ]; then
        ort_lib="${ORT_XCFRAMEWORK}/ios-arm64/onnxruntime.framework/onnxruntime"
    else
        ort_lib="${ORT_XCFRAMEWORK}/ios-arm64_x86_64-simulator/onnxruntime.framework/onnxruntime"
    fi

    # Compile each source file to object file
    OBJECT_FILES=()
    for src in "${SOURCE_FILES[@]}"; do
        filename=$(basename "${src}")
        objfile="${filename%.*}.o"
        echo "Compiling ${filename}..."

        if [[ "${src}" == *.c ]]; then
            # C file
            xcrun --sdk ${sdk} clang \
                ${target_platform} \
                -isysroot "${sdk_path}" \
                -fvisibility=hidden \
                -DTENVAD_EXPORTS \
                -I"${PROJECT_ROOT}/include" \
                -I"${PROJECT_ROOT}/src" \
                -I"${ORT_HEADERS}" \
                -O3 \
                -c "${src}" \
                -o "${objfile}"
        else
            # C++ file
            xcrun --sdk ${sdk} clang++ \
                ${target_platform} \
                -isysroot "${sdk_path}" \
                -std=c++14 \
                -stdlib=libc++ \
                -fvisibility=hidden \
                -fvisibility-inlines-hidden \
                -DTENVAD_EXPORTS \
                -I"${PROJECT_ROOT}/include" \
                -I"${PROJECT_ROOT}/src" \
                -I"${ORT_HEADERS}" \
                -O3 \
                -c "${src}" \
                -o "${objfile}"
        fi

        OBJECT_FILES+=("${objfile}")
    done

    # Link object files into a dynamic library, statically linking ONNX Runtime
    echo "Linking dynamic library (with static ONNX Runtime)..."

    xcrun --sdk ${sdk} clang++ \
        ${target_platform} \
        -isysroot "${sdk_path}" \
        -dynamiclib \
        -install_name "@rpath/ten_vad.framework/ten_vad" \
        -Wl,-headerpad_max_install_names \
        -lc++ \
        -framework Foundation \
        -framework CoreFoundation \
        -framework CoreML \
        -framework Accelerate \
        "${OBJECT_FILES[@]}" \
        "${ort_lib}" \
        -o ten_vad

    # Create framework structure
    echo "Creating framework structure..."
    local framework_dir="${build_subdir}/ten_vad.framework"
    rm -rf "${framework_dir}"
    mkdir -p "${framework_dir}/Headers"
    mkdir -p "${framework_dir}/Modules"

    # Copy the binary
    cp ten_vad "${framework_dir}/"

    # Copy headers
    cp "${PROJECT_ROOT}/include/ten_vad.h" "${framework_dir}/Headers/"

    # Create Info.plist
    cat > "${framework_dir}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>ten_vad</string>
	<key>CFBundleIdentifier</key>
	<string>com.agora.ten-vad-onnx</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>ten_vad</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>MinimumOSVersion</key>
	<string>13.0</string>
</dict>
</plist>
EOF

    # Create module.modulemap
    cat > "${framework_dir}/Modules/module.modulemap" << 'EOF'
framework module ten_vad {
  umbrella header "ten_vad.h"
  export *
  module * { export * }
}
EOF

    # Make the binary executable
    chmod +x "${framework_dir}/ten_vad"

    # Verify the framework
    echo "Verifying framework..."
    file "${framework_dir}/ten_vad"
    ls -lh "${framework_dir}/ten_vad"
    otool -L "${framework_dir}/ten_vad"

    cd "${BUILD_DIR}"
}

# Build for iOS device (arm64)
build_framework "device" "arm64" "iphoneos" "iOS Device"

# Build for iOS Simulator (arm64 - Apple Silicon)
build_framework "simulator" "arm64" "iphonesimulator" "iOS Simulator (Apple Silicon)"

# Create XCFramework
echo ""
echo "=========================================="
echo "Creating XCFramework..."
echo "=========================================="

XCFRAMEWORK_PATH="${BUILD_DIR}/ten_vad.xcframework"
rm -rf "${XCFRAMEWORK_PATH}"

xcodebuild -create-xcframework \
    -framework "${BUILD_DIR}/device-arm64/ten_vad.framework" \
    -framework "${BUILD_DIR}/simulator-arm64/ten_vad.framework" \
    -output "${XCFRAMEWORK_PATH}"

echo "XCFramework created successfully!"
echo "XCFramework location: ${XCFRAMEWORK_PATH}"

# Copy to output directory
echo ""
echo "Installing XCFramework to ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}/ten_vad.xcframework"
cp -R "${XCFRAMEWORK_PATH}" "${OUTPUT_DIR}/"

echo ""
echo "=========================================="
echo "✅ iOS XCFramework built successfully!"
echo "=========================================="
echo "Output: ${OUTPUT_DIR}/ten_vad.xcframework"
echo ""
echo "Framework details:"
echo "  - ONNX Runtime is STATICALLY LINKED (self-contained)"
echo "  - No separate ONNX Runtime framework needed at runtime"
echo "  - Size optimization (-O3)"
echo "  - Hidden visibility for reduced symbol table"
echo ""
echo "XCFramework supports:"
echo "  - iOS devices (arm64)"
echo "  - iOS Simulator on Apple Silicon (arm64)"
echo ""
echo "Note: Intel Mac simulators can run this using Rosetta 2"
echo ""
echo "Production apps can use this framework without adding ONNX Runtime via SPM"
