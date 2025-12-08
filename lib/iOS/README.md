# TEN VAD iOS XCFramework

This directory contains the pre-built XCFrameworks for iOS.

## Contents

- `ten_vad.xcframework` - TEN VAD library (voice activity detection) with ONNX Runtime statically linked

## Requirements

**IMPORTANT:**

1. The framework has ONNX Runtime 1.20.0 statically linked - **no external ONNX Runtime dependency required**
2. The framework requires the ONNX model file to be included in your app bundle.

### Model File Location

The framework expects to find the model at:
```
YourApp.app/onnx_model/ten-vad.onnx
```

### How to Include the Model

The model file is located at: `../../src/onnx_model/ten-vad.onnx`

#### Option 1: Xcode Project

1. Drag `ten-vad.onnx` into your Xcode project
2. Create a folder reference named `onnx_model` in your project
3. Ensure the file is added to your app target in "Build Phases" → "Copy Bundle Resources"

#### Option 2: Swift Package Manager

Add the model as a resource in your Package.swift:

```swift
.target(
    name: "YourTarget",
    dependencies: [],
    resources: [
        .copy("Resources/onnx_model/ten-vad.onnx")
    ]
)
```

Then copy it to the app bundle at runtime or use a build phase.

#### Option 3: CMake (like the demo)

```cmake
add_custom_command(TARGET YourApp POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:YourApp>/onnx_model"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${PATH_TO_MODEL}/ten-vad.onnx"
        "$<TARGET_FILE_DIR:YourApp>/onnx_model/"
)
```

## Usage

See `../../examples_onnx/` for a complete working example.

### Basic Integration

1. Add `ten_vad.xcframework` to your Xcode project
   - Drag it into your project
   - Select "Embed & Sign"
   - **No need to add ONNX Runtime** - it's already statically linked inside

2. Include the ONNX model as described above

3. **IMPORTANT:** Change the current directory to your app bundle before using the library

4. Use the C API from `ten_vad.h`

**Swift Example:**
```swift
import Foundation

// IMPORTANT: Change to app bundle directory first
if let bundlePath = Bundle.main.bundlePath {
    FileManager.default.changeCurrentDirectoryPath(bundlePath)
}

// Now use the VAD library
var handle: UnsafeMutableRawPointer? = nil
let threshold: Float = 0.5
let hopSize: Int32 = 256

ten_vad_create(&handle, hopSize, threshold)

// Process audio
var audio = [Int16](repeating: 0, count: 256)
var prob: Float = 0.0
var flag: Int32 = 0
ten_vad_process(handle, &audio, hopSize, &prob, &flag)

ten_vad_destroy(&handle)
```

**Objective-C Example:**
```objc
#import <Foundation/Foundation.h>
#include <ten_vad.h>

// IMPORTANT: Change to app bundle directory first
NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
[[NSFileManager defaultManager] changeCurrentDirectoryPath:bundlePath];

// Now use the VAD library
void* handle = NULL;
float threshold = 0.5f;
int hop_size = 256;

ten_vad_create(&handle, hop_size, threshold);

// Process audio
int16_t audio[256];
float prob;
int32_t flag;
ten_vad_process(handle, audio, 256, &prob, &flag);

ten_vad_destroy(&handle);
```

**Why change the directory?**
The library loads the ONNX model using a relative path `onnx_model/ten-vad.onnx`. iOS apps launch with the current directory set to `/`, so you must change to the app bundle directory for the relative path to work correctly.

## Platforms Supported

- iOS devices (arm64)
- iOS Simulator on Apple Silicon (arm64)
- Intel Mac simulators can use Rosetta 2

## Dependencies

**For production apps:**
- Add `ten_vad.xcframework` to your project
- **No external dependencies needed** - ONNX Runtime is statically linked
- Do NOT add `onnxruntime.xcframework` or ONNX Runtime via SPM

**For the demo app:**
- The demo app uses the self-contained `ten_vad.xcframework`
- The static build makes conflicts with app-level ONNX Runtime impossible

## Building from Source

To rebuild the framework with static ONNX Runtime:

1. Download ONNX Runtime pod archive (version 1.20.0):
   ```bash
   curl -L -o onnxruntime-1.20.0.zip "https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.20.0.zip"
   unzip onnxruntime-1.20.0.zip -d pod-archive-onnxruntime-c-1.20.0
   ```

2. Build the framework:
   ```bash
   export ORT_POD_PATH=/path/to/pod-archive-onnxruntime-c-1.20.0
   cd scripts
   bash build-ios.sh
   ```
