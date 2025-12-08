#!/bin/bash
#
# Copyright © 2025 Agora
# This file is part of TEN Framework, an open source project.
# Licensed under the Apache License, Version 2.0, with certain conditions.
# Refer to the "LICENSE" file in the root directory for more information.
#
# Build script for TEN VAD Android library with 16KB page size support

set -e

# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ONNX Runtime paths
if [ -z "$ORT_ROOT" ]; then
    echo "Error: ORT_ROOT environment variable not set"
    echo ""
    echo "Please set ORT_ROOT to your ONNX Runtime build directory, e.g.:"
    echo "  export ORT_ROOT=/path/to/onnxruntime"
    echo "  bash build-android.sh"
    echo ""
    echo "ONNX Runtime should be built for Android with libraries at:"
    echo "  \$ORT_ROOT/build/Android/arm64-v8a/libonnxruntime.so"
    echo "  \$ORT_ROOT/build/Android/armeabi-v7a/libonnxruntime.so"
    exit 1
fi

ORT_HEADERS="${ORT_ROOT}/include/onnxruntime/core/session"

# Android NDK path (customize if needed)
NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_NDK}"
if [ -z "$NDK_ROOT" ]; then
    echo "Error: ANDROID_NDK_ROOT or ANDROID_NDK environment variable not set"
    echo "Please set it to your Android NDK path, e.g.:"
    echo "  export ANDROID_NDK_ROOT=/path/to/android-ndk"
    exit 1
fi

# API level
API_LEVEL=21

# Source and header files
SRC_DIR="${PROJECT_ROOT}/src"
INCLUDE_DIR="${PROJECT_ROOT}/include"

# Source files to compile
CC_SOURCES=(
    "${SRC_DIR}/aed.cc"
    "${SRC_DIR}/biquad.cc"
    "${SRC_DIR}/fscvrt.cc"
    "${SRC_DIR}/pitch_est.cc"
    "${SRC_DIR}/stft.cc"
    "${SRC_DIR}/ten_vad.cc"
)
C_SOURCES=(
    "${SRC_DIR}/fftw.c"
)

# Compiler flags - optimized for size
COMMON_CFLAGS="-fPIC -Oz -DANDROID -DTENVAD_EXPORTS -flto -ffunction-sections -fdata-sections -fvisibility=hidden"
COMMON_CXXFLAGS="${COMMON_CFLAGS} -std=c++14 -fvisibility-inlines-hidden"
INCLUDE_FLAGS="-I${INCLUDE_DIR} -I${SRC_DIR} -I${ORT_ROOT}/include -I${ORT_HEADERS}"

# Linker flags with 16KB page size support and aggressive size optimization
COMMON_LDFLAGS="-shared -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -flto -Wl,--gc-sections -Wl,--strip-all"

# Function to build for a specific architecture
build_for_arch() {
    local ARCH=$1
    local ABI=$2
    local TOOLCHAIN_PREFIX=$3

    echo "======================================"
    echo "Building for ${ABI} (dynamic linking)..."
    echo "======================================"

    # Set up toolchain
    TOOLCHAIN="${NDK_ROOT}/toolchains/llvm/prebuilt/darwin-x86_64"
    CC="${TOOLCHAIN}/bin/${TOOLCHAIN_PREFIX}${API_LEVEL}-clang"
    CXX="${TOOLCHAIN}/bin/${TOOLCHAIN_PREFIX}${API_LEVEL}-clang++"

    # Check if compiler exists
    if [ ! -f "$CC" ]; then
        echo "Error: Compiler not found at $CC"
        exit 1
    fi

    # Build directory for this architecture
    BUILD_DIR="${PROJECT_ROOT}/build/Android/${ABI}"
    mkdir -p "${BUILD_DIR}"

    # ONNX Runtime library for this architecture
    ORT_LIB="${ORT_ROOT}/build/Android/${ABI}/libonnxruntime.so"
    if [ ! -f "$ORT_LIB" ]; then
        echo "Error: ONNX Runtime library not found at $ORT_LIB"
        exit 1
    fi

    # Compile C++ sources
    echo "Compiling C++ sources..."
    CXX_OBJECTS=()
    for src in "${CC_SOURCES[@]}"; do
        obj="${BUILD_DIR}/$(basename ${src%.cc}.o)"
        echo "  Compiling $(basename $src)..."
        "${CXX}" ${COMMON_CXXFLAGS} ${INCLUDE_FLAGS} -c "$src" -o "$obj"
        CXX_OBJECTS+=("$obj")
    done

    # Compile C sources
    echo "Compiling C sources..."
    C_OBJECTS=()
    for src in "${C_SOURCES[@]}"; do
        obj="${BUILD_DIR}/$(basename ${src%.c}.o)"
        echo "  Compiling $(basename $src)..."
        "${CC}" ${COMMON_CFLAGS} ${INCLUDE_FLAGS} -c "$src" -o "$obj"
        C_OBJECTS+=("$obj")
    done

    # Link dynamically with ONNX Runtime
    echo "Linking libten_vad.so with ONNX Runtime (LTO enabled)..."
    "${CXX}" ${COMMON_LDFLAGS} \
        "${CXX_OBJECTS[@]}" "${C_OBJECTS[@]}" \
        "${ORT_LIB}" \
        -o "${BUILD_DIR}/libten_vad.so"

    echo "Successfully built libten_vad.so for ${ABI}"
    echo "Output: ${BUILD_DIR}/libten_vad.so"
    ls -lh "${BUILD_DIR}/libten_vad.so"
    echo ""
}

# Build for arm64-v8a
build_for_arch "arm64" "arm64-v8a" "aarch64-linux-android"

# Build for armeabi-v7a
build_for_arch "arm" "armeabi-v7a" "armv7a-linux-androideabi"

echo "======================================"
echo "Build completed successfully!"
echo "======================================"
echo "Libraries built at:"
echo "  - ${PROJECT_ROOT}/build/Android/arm64-v8a/libten_vad.so"
echo "  - ${PROJECT_ROOT}/build/Android/armeabi-v7a/libten_vad.so"
echo ""
echo "Optimizations applied:"
echo "  - ONNX Runtime dynamically linked (requires libonnxruntime.so at runtime)"
echo "  - 16KB page size support (-Wl,-z,max-page-size=16384)"
echo "  - Link Time Optimization (LTO) for size reduction"
echo "  - Dead code elimination (--gc-sections)"
echo "  - Size optimization (-Oz)"
echo "  - All symbols stripped (--strip-all)"
echo "  - Hidden visibility for reduced symbol table"
