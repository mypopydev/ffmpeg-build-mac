#!/bin/bash

# Library Information Module
# Defines library metadata, dependencies, and configure flags

# Helper function to get configure flag for a library
# Replaces associative array for Bash 3.2 compatibility
get_lib_config_flag() {
    local lib_name="$1"
    case "$lib_name" in
        "x264")       echo "--enable-libx264" ;;
        "x265")       echo "--enable-libx265" ;;
        "fdk-aac")    echo "--enable-libfdk_aac" ;;
        "lame")       echo "--enable-libmp3lame" ;;
        "opus")       echo "--enable-libopus" ;;
        "libvpx")     echo "--enable-libvpx" ;;
        "libaom")     echo "--enable-libaom" ;;
        "openh264")   echo "--enable-libopenh264" ;;
        "kvazaar")    echo "--enable-libkvazaar" ;;
        "svtav1")     echo "--enable-libsvtav1" ;;
        "dav1d")      echo "--enable-libdav1d" ;;
        "libplacebo") echo "--enable-libplacebo" ;;
        "freetype")   echo "--enable-libfreetype" ;;
        "vvenc")      echo "--enable-libvvenc" ;;
        *)            echo "" ;;
    esac
}

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
    "vvenc"
)

# Helper function to get all available libraries
get_all_libraries() {
    echo "${GROUP_1_LIBS[@]}"
}
