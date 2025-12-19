#!/bin/bash
#
# Copyright © 2025 Agora
# This file is part of TEN Framework, an open source project.
# Licensed under the Apache License, Version 2.0, with certain conditions.
# Refer to the "LICENSE" file in the root directory for more information.
#
# Build script for TEN VAD macOS framework with statically linked ONNX Runtime
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
    echo "     bash build-macos.sh"
    exit 1
fi

if [ ! -d "$ORT_POD_PATH" ]; then
    echo "Error: ONNX Runtime pod archive not found at $ORT_POD_PATH"
    echo "Please verify the path and try again"
    exit 1
fi

ORT_HEADERS="${ORT_POD_PATH}/Headers"
ORT_FRAMEWORK="${ORT_POD_PATH}/onnxruntime.xcframework/macos-arm64_x86_64/onnxruntime.framework"

if [ ! -d "$ORT_FRAMEWORK" ]; then
    echo "Error: ONNX Runtime macOS framework not found at $ORT_FRAMEWORK"
    exit 1
fi

echo "Using ONNX Runtime from: $ORT_POD_PATH"

# Build settings
BUILD_DIR="${PROJECT_ROOT}/build/macOS-temp"
OUTPUT_DIR="${PROJECT_ROOT}/lib/macOS"
MIN_MACOS_VERSION="11.0"

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

# Function to build framework for a specific architecture
build_framework() {
    local arch=$1
    local arch_name=$2

    echo ""
    echo "=========================================="
    echo "Building for macOS ${arch_name}..."
    echo "=========================================="

    local build_subdir="${BUILD_DIR}/${arch}"
    mkdir -p "${build_subdir}"
    cd "${build_subdir}"

    local target="-target ${arch}-apple-macos${MIN_MACOS_VERSION}"

    # Get the ONNX Runtime static library
    local ort_lib="${ORT_FRAMEWORK}/Versions/A/onnxruntime"

    # Compile each source file to object file
    OBJECT_FILES=()
    for src in "${SOURCE_FILES[@]}"; do
        filename=$(basename "${src}")
        objfile="${filename%.*}.o"
        echo "Compiling ${filename}..."

        if [[ "${src}" == *.c ]]; then
            # C file
            clang \
                ${target} \
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
            clang++ \
                ${target} \
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

    clang++ \
        ${target} \
        -dynamiclib \
        -install_name "@rpath/ten_vad.framework/Versions/A/ten_vad" \
        -Wl,-headerpad_max_install_names \
        -lc++ \
        -framework Foundation \
        -framework CoreFoundation \
        -framework CoreML \
        -framework Accelerate \
        "${OBJECT_FILES[@]}" \
        "${ort_lib}" \
        -o ten_vad

    echo "Built for ${arch_name}"
    ls -lh ten_vad

    cd "${BUILD_DIR}"
}

# Build for both architectures
build_framework "arm64" "Apple Silicon"
build_framework "x86_64" "Intel"

# Create universal binary
echo ""
echo "=========================================="
echo "Creating universal binary..."
echo "=========================================="

mkdir -p "${BUILD_DIR}/universal"
lipo -create \
    "${BUILD_DIR}/arm64/ten_vad" \
    "${BUILD_DIR}/x86_64/ten_vad" \
    -output "${BUILD_DIR}/universal/ten_vad"

echo "Universal binary created:"
lipo -info "${BUILD_DIR}/universal/ten_vad"
ls -lh "${BUILD_DIR}/universal/ten_vad"

# Create framework structure
echo ""
echo "=========================================="
echo "Creating framework structure..."
echo "=========================================="

FRAMEWORK_DIR="${BUILD_DIR}/ten_vad.framework"
rm -rf "${FRAMEWORK_DIR}"
mkdir -p "${FRAMEWORK_DIR}/Versions/A/Headers"
mkdir -p "${FRAMEWORK_DIR}/Versions/A/Resources"

# Copy the universal binary
cp "${BUILD_DIR}/universal/ten_vad" "${FRAMEWORK_DIR}/Versions/A/"

# Copy headers
cp "${PROJECT_ROOT}/include/ten_vad.h" "${FRAMEWORK_DIR}/Versions/A/Headers/"

# Create Info.plist
cat > "${FRAMEWORK_DIR}/Versions/A/Resources/Info.plist" << 'EOF'
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
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
</dict>
</plist>
EOF

# Create symbolic links
cd "${FRAMEWORK_DIR}/Versions"
ln -sf A Current
cd "${FRAMEWORK_DIR}"
ln -sf Versions/Current/Headers Headers
ln -sf Versions/Current/Resources Resources
ln -sf Versions/Current/ten_vad ten_vad

# Make the binary executable
chmod +x "${FRAMEWORK_DIR}/Versions/A/ten_vad"

# Verify the framework
echo "Verifying framework..."
file "${FRAMEWORK_DIR}/ten_vad"
otool -L "${FRAMEWORK_DIR}/ten_vad"

# Copy to output directory
echo ""
echo "Installing framework to ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}/ten_vad.framework"
cp -R "${FRAMEWORK_DIR}" "${OUTPUT_DIR}/"

echo ""
echo "=========================================="
echo "✅ macOS framework built successfully!"
echo "=========================================="
echo "Output: ${OUTPUT_DIR}/ten_vad.framework"
echo ""
echo "Framework details:"
echo "  - ONNX Runtime is STATICALLY LINKED (self-contained)"
echo "  - No separate ONNX Runtime framework needed at runtime"
echo "  - Universal binary (arm64 + x86_64)"
echo "  - Size optimization (-O3)"
echo "  - Hidden visibility for reduced symbol table"
echo ""
echo "Production apps can use this framework without adding ONNX Runtime separately"
