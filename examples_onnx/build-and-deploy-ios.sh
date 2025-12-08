#!/bin/bash
#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
set -eo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check for required XCFramework
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEN_VAD_XCFRAMEWORK="${PROJECT_ROOT}/lib/iOS/ten_vad.xcframework"

if [ ! -d "$TEN_VAD_XCFRAMEWORK" ]; then
    echo "Error: ten_vad.xcframework not found"
    echo "Please build the iOS framework first by running:"
    echo "  cd ${PROJECT_ROOT}/scripts"
    echo "  bash build-ios.sh"
    exit 1
fi

# Customize the arch (only arm64 supported for iOS devices)
arch=arm64

build_dir=cpp/build-ios/$arch
rm -rf $build_dir
mkdir -p $build_dir
cd $build_dir

# Generate Xcode project with pre-built XCFramework
echo "[Info] Generating Xcode project for iOS"
cmake ../../../ \
  -DIOS=TRUE \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -G Xcode

echo ""
echo "=========================================="
echo "✅ Xcode project generated successfully!"
echo "=========================================="
echo ""
echo "Project location:"
echo "  $SCRIPT_DIR/$build_dir/ten_vad.xcodeproj"
echo ""
echo "Next steps:"
echo "  1. Open the project in Xcode:"
echo "     open $SCRIPT_DIR/$build_dir/ten_vad.xcodeproj"
echo ""
echo "  2. Select 'ten_vad_demo' target"
echo "  3. Configure code signing (Team & Bundle ID)"
echo "  4. Select your iOS device"
echo "  5. Build and run (Cmd+R)"
echo ""

cd "$SCRIPT_DIR"
