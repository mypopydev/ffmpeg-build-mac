#!/bin/bash

# Common functions and utilities for FFmpeg build scripts

# ============= Color Output =============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============= Logging Functions =============

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# ============= Path Functions =============

# Get script directory (the root of the project)
get_project_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")" && cd .. && pwd)"
}

# ============= Version Control Functions =============

# Load version configuration
load_versions() {
    local project_root="$1"
    local version_file="$project_root/config/versions.conf"

    if [ -f "$version_file" ]; then
        source "$version_file"
        log_info "Loaded version configuration: BUILD_MODE=$BUILD_MODE"
    else
        log_warning "Version config not found, using defaults"
        BUILD_MODE="latest"
    fi
}

# Check if a library needs to be rebuilt
# Returns 0 if rebuild needed, 1 if up to date
needs_rebuild() {
    local lib_name="$1"
    local source_dir="$2"
    local build_marker="$3"

    # If marker doesn't exist, rebuild needed
    if [ ! -f "$build_marker" ]; then
        return 0
    fi

    # Check if source directory has newer files than marker
    if [ -d "$source_dir" ]; then
        local newer_files=$(find "$source_dir" -newer "$build_marker" -type f 2>/dev/null | head -n 1)
        if [ -n "$newer_files" ]; then
            log_info "$lib_name: Source files changed, rebuild needed"
            return 0
        fi
    fi

    log_info "$lib_name: Up to date, skipping build"
    return 1
}

# Mark a library as successfully built
mark_built() {
    local lib_name="$1"
    local build_marker="$2"
    local version="$3"

    mkdir -p "$(dirname "$build_marker")"
    echo "Built on: $(date)" > "$build_marker"
    echo "Version: $version" >> "$build_marker"
    log_success "$lib_name: Build marker created"
}

# ============= Git Functions =============

# Clone or update a git repository with retry logic
git_clone_or_update() {
    local repo_url="$1"
    local target_dir="$2"
    local version="$3"
    local max_retries=3
    local retry_count=0

    if [ ! -d "$target_dir" ]; then
        log_info "Cloning $repo_url..."
        while [ $retry_count -lt $max_retries ]; do
            if git clone "$repo_url" "$target_dir"; then
                log_success "Clone successful"
                break
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retries ]; then
                    log_warning "Clone failed, retrying ($retry_count/$max_retries)..."
                    sleep 2
                else
                    log_error "Clone failed after $max_retries attempts"
                    return 1
                fi
            fi
        done
    else
        log_info "Repository exists, updating..."
        cd "$target_dir"
        git fetch --all || log_warning "Fetch failed, continuing with existing version"
    fi

    # Checkout specific version if not "latest"
    if [ "$version" != "latest" ]; then
        cd "$target_dir"
        log_info "Checking out version: $version"
        git checkout "$version" || {
            log_error "Failed to checkout $version"
            return 1
        }
    else
        cd "$target_dir"
        # Get the default branch name
        local default_branch=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
        if [ -n "$default_branch" ]; then
            git checkout "$default_branch" 2>/dev/null || git checkout master 2>/dev/null || git checkout main 2>/dev/null
            git pull 2>/dev/null || log_warning "Pull failed, using existing version"
        fi
    fi

    return 0
}

# ============= Build Functions =============

# Get number of CPU cores for parallel make
get_cpu_count() {
    if command -v nproc &> /dev/null; then
        nproc
    elif command -v sysctl &> /dev/null; then
        sysctl -n hw.ncpu
    else
        echo "4"  # Default fallback
    fi
}

# Run make with optimal job count
run_make() {
    local cpu_count=$(get_cpu_count)
    make -j"$cpu_count" "$@"
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Verify required tools are installed
check_required_tools() {
    local tools=("$@")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        return 1
    fi

    return 0
}

# ============= Directory Management =============

# Create build directories
setup_build_dirs() {
    local ffmpeg_build="$1"
    local ffmpeg_sources="$2"

    mkdir -p "$ffmpeg_sources"
    mkdir -p "$ffmpeg_build"/{bin,lib,include,share}
    mkdir -p "$ffmpeg_build/.build_markers"

    log_info "Build directories created"
}

# ============= Build State Functions =============

# Get build marker path for a library
get_build_marker() {
    local ffmpeg_build="$1"
    local lib_name="$2"
    echo "$ffmpeg_build/.build_markers/$lib_name.marker"
}

# Check if force rebuild is requested
is_force_rebuild() {
    [ "${FORCE_REBUILD:-0}" = "1" ]
}

# ============= Dependency Management =============

# Get dependencies for a library
# Returns space-separated list of dependencies
get_dependencies() {
    local lib_name="$1"

    case "$lib_name" in
        x264|x265|fdk-aac|lame|opus|libvpx|libaom|openh264|kvazaar|svtav1|dav1d|libplacebo)
            # These libraries have no dependencies
            echo ""
            ;;
        ffmpeg)
            # FFmpeg depends on all codec libraries and video processing libraries
            echo "x264 x265 fdk-aac lame opus libvpx libaom openh264 kvazaar svtav1 dav1d libplacebo"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check if all dependencies are built
check_dependencies() {
    local lib_name="$1"
    local ffmpeg_build="$2"
    local deps=$(get_dependencies "$lib_name")

    if [ -z "$deps" ]; then
        return 0
    fi

    for dep in $deps; do
        local marker=$(get_build_marker "$ffmpeg_build" "$dep")
        if [ ! -f "$marker" ]; then
            log_error "$lib_name: Dependency $dep not built yet"
            return 1
        fi
    done

    return 0
}

# ============= Cleanup Functions =============

# Clean build artifacts for a library
clean_library() {
    local lib_name="$1"
    local source_dir="$2"
    local ffmpeg_build="$3"

    log_info "Cleaning $lib_name..."

    if [ -d "$source_dir" ]; then
        cd "$source_dir"
        make clean 2>/dev/null || make distclean 2>/dev/null || true
    fi

    # Remove build marker
    local marker=$(get_build_marker "$ffmpeg_build" "$lib_name")
    rm -f "$marker"

    log_success "$lib_name cleaned"
}

# ============= Error Handling =============

# Trap errors and provide helpful messages
setup_error_handling() {
    set -e
    set -o pipefail

    trap 'error_handler $? $LINENO' ERR
}

error_handler() {
    local exit_code=$1
    local line_number=$2
    log_error "Build failed at line $line_number with exit code $exit_code"
    log_error "Check the logs for details"
    exit "$exit_code"
}

# ============= Progress Tracking =============

# Show build progress
show_progress() {
    local current="$1"
    local total="$2"
    local name="$3"

    echo -e "${MAGENTA}[$current/$total]${NC} $name"
}

# Export all functions
export -f log_info log_success log_warning log_error log_step
export -f get_project_root load_versions needs_rebuild mark_built
export -f git_clone_or_update get_cpu_count run_make
export -f command_exists check_required_tools setup_build_dirs
export -f get_build_marker is_force_rebuild
export -f get_dependencies check_dependencies clean_library
export -f setup_error_handling error_handler show_progress
