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

# For Android builds from source, add extra header path
if(ANDROID)
    include_directories(${ORT_ROOT}/include/onnxruntime/core/session)
endif()
file(GLOB LIBRARY_SOURCES "${ROOT}/src/*.cc" "${ROOT}/src/*.c")
add_library(ten_vad SHARED ${LIBRARY_SOURCES})

# Platform-specific ONNX Runtime linking
if(ANDROID)
    # Android builds from source: library is in build/Android/${ANDROID_ABI}/
    target_link_libraries(ten_vad "${ORT_ROOT}/build/Android/${ANDROID_ABI}/libonnxruntime.so")
elseif(APPLE)
    link_directories(${ORT_ROOT}/lib)
    target_link_libraries(ten_vad "${ORT_ROOT}/lib/libonnxruntime.dylib")
    # Set rpath for macOS
    set_target_properties(ten_vad PROPERTIES
        INSTALL_RPATH "${ORT_ROOT}/lib"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
else()
    link_directories(${ORT_ROOT}/lib)
    target_link_libraries(ten_vad "${ORT_ROOT}/lib/libonnxruntime.so")
endif()

set(EXECUTABLE_SOURCES ${ROOT}/examples/main.c)
add_executable(ten_vad_demo ${EXECUTABLE_SOURCES})
target_link_libraries(ten_vad_demo ten_vad)