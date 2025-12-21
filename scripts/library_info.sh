#!/bin/bash

# Library Information Module
# Defines library metadata, dependencies, and configure flags

# Associative array for mapping library names to FFmpeg configure flags
declare -A LIB_CONFIG_FLAGS
LIB_CONFIG_FLAGS["x264"]="--enable-libx264"
LIB_CONFIG_FLAGS["x265"]="--enable-libx265"
LIB_CONFIG_FLAGS["fdk-aac"]="--enable-libfdk_aac"
LIB_CONFIG_FLAGS["lame"]="--enable-libmp3lame"
LIB_CONFIG_FLAGS["opus"]="--enable-libopus"
LIB_CONFIG_FLAGS["libvpx"]="--enable-libvpx"
LIB_CONFIG_FLAGS["libaom"]="--enable-libaom"
LIB_CONFIG_FLAGS["openh264"]="--enable-libopenh264"
LIB_CONFIG_FLAGS["kvazaar"]="--enable-libkvazaar"
LIB_CONFIG_FLAGS["svtav1"]="--enable-libsvtav1"
LIB_CONFIG_FLAGS["dav1d"]="--enable-libdav1d"
LIB_CONFIG_FLAGS["libplacebo"]="--enable-libplacebo"
# freetype is usually a system dependency but enabled in ffmpeg
LIB_CONFIG_FLAGS["freetype"]="--enable-libfreetype"

# Dependencies definition
# Format: LIB_DEPS["lib_name"]="dep1 dep2 ..."
declare -A LIB_DEPS
# FFmpeg depends on everything else that is enabled
# This is dynamic, so we might handle it specially, but for completeness:
# LIB_DEPS["ffmpeg"] is treated specially in the builder, 
# typically dependent on all other enabled libraries.

# Group definitions for build order
# Independent libraries (can be built in parallel)
declare -a GROUP_1_LIBS=(
    "x264"
    "x265"
    "fdk-aac"
    "lame"
    "opus"
    "libvpx"
    "libaom"
    "openh264"
    "kvazaar"
    "svtav1"
    "dav1d"
    "libplacebo"
)

# Helper function to get configure flag for a library
get_lib_config_flag() {
    local lib_name="$1"
    echo "${LIB_CONFIG_FLAGS[$lib_name]}"
}

# Helper function to get all available libraries
get_all_libraries() {
    echo "${GROUP_1_LIBS[@]}"
}
