# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.13)

set(TARGET_NAME media_kit_native_event_loop)

project(${TARGET_NAME}_library VERSION 1.0.0 LANGUAGES CXX)

function(media_kit_configure_target target)
  target_compile_features(${target} PRIVATE cxx_std_17)

  set_target_properties(
    ${target} PROPERTIES
    PUBLIC_HEADER "${TARGET_NAME}.h"
    OUTPUT_NAME "${TARGET_NAME}"
  )

  target_compile_definitions(${target} PUBLIC DART_SHARED_LIB)
endfunction()

if(WIN32)
  if(MEDIA_KIT_LIBS_AVAILABLE)
    add_library(${TARGET_NAME} SHARED "${TARGET_NAME}.cc")
    media_kit_configure_target(${TARGET_NAME})
  else()
    message(NOTICE "media_kit: WARNING: package:media_kit_libs_*** not found.")
  endif()

elseif(ANDROID)
  add_library(${TARGET_NAME} SHARED "${TARGET_NAME}.cc")

  target_link_libraries(
    ${TARGET_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../libmpv/src/main/jniLibs/${ANDROID_ABI}/libmpv.so"
  )

  target_link_options(
    ${TARGET_NAME} PRIVATE
    "-Wl,-z,max-page-size=16384"
  )

  media_kit_configure_target(${TARGET_NAME})

elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  if(MEDIA_KIT_LIBS_AVAILABLE)
    add_library(${TARGET_NAME} SHARED "${TARGET_NAME}.cc")
    media_kit_configure_target(${TARGET_NAME})
  else()
    message(NOTICE "media_kit: WARNING: package:media_kit_libs_*** not found.")
  endif()
endif()
