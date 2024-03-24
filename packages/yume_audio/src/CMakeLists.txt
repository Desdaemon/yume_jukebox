# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(yume_audio_library VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror -Wpedantic")

include_directories(../include)
include_directories(${CMAKE_ANDROID_NDK}/sysroot/usr/include)

string(LENGTH "${CMAKE_SOURCE_DIR}/" SOURCE_PATH_SIZE)
add_definitions("-DSOURCE_PATH_SIZE=${SOURCE_PATH_SIZE}")

add_library(yume_audio SHARED
  "yume_audio.cpp"
)

find_package(oboe REQUIRED CONFIG)
target_link_libraries(yume_audio PRIVATE oboe::oboe)

set(TARGET_LIBS log android mediandk)
target_link_libraries(yume_audio PRIVATE ${TARGET_LIBS})

set_target_properties(yume_audio PROPERTIES
  PUBLIC_HEADER yume_audio.h
  OUTPUT_NAME "yume_audio"
)

target_compile_definitions(yume_audio PUBLIC DART_SHARED_LIB)
