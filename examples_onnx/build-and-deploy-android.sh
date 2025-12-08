#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
set -eo pipefail

# Check for required environment variables
if [ -z "$ORT_ROOT" ]; then
    echo "Error: ORT_ROOT environment variable not set"
    echo "Please set it to your ONNX Runtime path, e.g.:"
    echo "  export ORT_ROOT=/path/to/onnxruntime"
    exit 1
fi

# Customize the arch and toolchain
arch=arm64-v8a
toolchain=aarch64-linux-android-clang

# arch=armeabi-v7a
# toolchain=arm-linux-android-clang

build_dir=cpp/build-android/$arch
rm -rf $build_dir
mkdir -p $build_dir
cd $build_dir

# Step 1: Build the demo with ONNX Runtime
cmake ../../../ \
  -DANDROID_ABI=${arch} \
  -DANDROID_TOOLCHAIN_NAME=$toolchain \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DORT_ROOT=${ORT_ROOT} \
  -G "Unix Makefiles"

cmake --build . --config Release


# Step 2: Run the demo
adb push ../../../../examples/s0724-s0730.wav /data/local/tmp/
adb push ../../../../src/onnx_model /data/local/tmp/
adb push libten_vad.so /data/local/tmp/libten_vad.so &&
  adb push ${ORT_ROOT}/build/Android/${arch}/libonnxruntime.so /data/local/tmp/libonnxruntime.so &&
  adb push ten_vad_demo /data/local/tmp/ &&
  adb shell "cd /data/local/tmp && chmod +x ten_vad_demo && \
LD_LIBRARY_PATH=/data/local/tmp ./ten_vad_demo ./s0724-s0730.wav ./out.txt && \
exit 0"

adb pull /data/local/tmp/out.txt ./
cd ../../../
