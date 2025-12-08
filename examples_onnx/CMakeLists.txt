#
#  Copyright © 2025 Agora
#  This file is part of TEN Framework, an open source project.
#  Licensed under the Apache License, Version 2.0, with certain conditions.
#  Refer to the "LICENSE" file in the root directory for more information.
#
# CMakeList for TEN VAD C++ demo with ONNX Runtime
cmake_minimum_required(VERSION 3.10)
get_filename_component(ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../ ABSOLUTE)

project(ten_vad)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_BUILD_TYPE Release)
add_compile_options(-Wno-write-strings -Wno-unused-result)
include_directories(${ROOT}/src)
include_directories(${ROOT}/include)
include_directories(${ORT_ROOT}/include)

# Build library from source for all platforms except iOS
# iOS uses pre-built xcframeworks
if(ANDROID)
    # Android builds from source, add extra header path
    include_directories(${ORT_ROOT}/include/onnxruntime/core/session)

    file(GLOB LIBRARY_SOURCES "${ROOT}/src/*.cc" "${ROOT}/src/*.c")
    add_library(ten_vad SHARED ${LIBRARY_SOURCES})

    # Android: library is in build/Android/${ANDROID_ABI}/
    target_link_libraries(ten_vad "${ORT_ROOT}/build/Android/${ANDROID_ABI}/libonnxruntime.so")
elseif(APPLE)
    if(IOS)
        # iOS: use pre-built xcframework
        set(TEN_VAD_XCFRAMEWORK "${ROOT}/lib/iOS/ten_vad.xcframework")
    else()
        # macOS: build from source
        file(GLOB LIBRARY_SOURCES "${ROOT}/src/*.cc" "${ROOT}/src/*.c")
        add_library(ten_vad SHARED ${LIBRARY_SOURCES})

        link_directories(${ORT_ROOT}/lib)
        target_link_libraries(ten_vad "${ORT_ROOT}/lib/libonnxruntime.dylib")
        # Set rpath for macOS
        set_target_properties(ten_vad PROPERTIES
            INSTALL_RPATH "${ORT_ROOT}/lib"
            BUILD_WITH_INSTALL_RPATH TRUE
        )
    endif()
else()
    # Linux and other platforms
    file(GLOB LIBRARY_SOURCES "${ROOT}/src/*.cc" "${ROOT}/src/*.c")
    add_library(ten_vad SHARED ${LIBRARY_SOURCES})

    link_directories(${ORT_ROOT}/lib)
    target_link_libraries(ten_vad "${ORT_ROOT}/lib/libonnxruntime.so")
endif()

# Build demo executable
set(EXECUTABLE_SOURCES ${ROOT}/examples/main.c)
if(IOS)
    add_executable(ten_vad_demo MACOSX_BUNDLE ${EXECUTABLE_SOURCES})
    target_link_libraries(ten_vad_demo "${TEN_VAD_XCFRAMEWORK}" "-framework CoreFoundation")
    set_target_properties(ten_vad_demo PROPERTIES
        MACOSX_BUNDLE_BUNDLE_NAME "TEN VAD ONNX Demo"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.agora.ten-vad-onnx-demo"
        MACOSX_BUNDLE_INFO_STRING "TEN VAD ONNX Demo Application"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Manual"
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks @loader_path/Frameworks"
        XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS "${ROOT}/lib/iOS"
        XCODE_EMBED_FRAMEWORKS "${TEN_VAD_XCFRAMEWORK}"
        XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY TRUE
        XCODE_ATTRIBUTE_COPY_PHASE_STRIP "NO"
        RESOURCE "${ROOT}/src/onnx_model"
    )

    # Copy ONNX model to app bundle
    add_custom_command(TARGET ten_vad_demo POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:ten_vad_demo>/onnx_model"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${ROOT}/src/onnx_model/ten-vad.onnx"
            "$<TARGET_FILE_DIR:ten_vad_demo>/onnx_model/"
        COMMENT "Copying ONNX model into app bundle"
    )
else()
    add_executable(ten_vad_demo ${EXECUTABLE_SOURCES})
    target_link_libraries(ten_vad_demo ten_vad)
endif()