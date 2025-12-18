#!/bin/bash
# Darwin Userland Build Script
# Builds Darwin userland components for ARM64 (Raspberry Pi 3)
#
# Usage: ./build-userland.sh [component] [options]
# Components: all, libdispatch, libxpc, launchd, dyld, cf
# Options: --clean, --download-only, --verbose

set -e

# =============================================================================
# Configuration
# =============================================================================

# Versions (macOS 11.x / Big Sur compatible with XNU 7195.81.3)
LIBC_VERSION="${LIBC_VERSION:-1439.141.1}"
LIBDISPATCH_VERSION="${LIBDISPATCH_VERSION:-1271.120.2}"
LIBXPC_VERSION="${LIBXPC_VERSION:-1336.261.2}"
LAUNCHD_VERSION="${LAUNCHD_VERSION:-1336.261.2}"
DYLD_VERSION="${DYLD_VERSION:-832.7.3}"
CF_VERSION="${CF_VERSION:-1677.104}"
XNU_VERSION="${XNU_VERSION:-7195.81.3}"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCES_DIR="${SOURCES_DIR:-$ROOT_DIR/sources}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
SYSROOT_DIR="${SYSROOT_DIR:-$ROOT_DIR/sysroot}"

# Build settings
TARGET_ARCH="${TARGET_ARCH:-arm64}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script must be run on macOS"
        exit 1
    fi
}

check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode command line tools not found"
        log_info "Install with: xcode-select --install"
        exit 1
    fi
}

check_cmake() {
    if ! command -v cmake &> /dev/null; then
        log_warn "CMake not found - some components may not build"
        log_info "Install with: brew install cmake"
        return 1
    fi
    return 0
}

create_directories() {
    mkdir -p "$SOURCES_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$SYSROOT_DIR/usr/include"
    mkdir -p "$SYSROOT_DIR/usr/lib"
}

# =============================================================================
# Download Functions
# =============================================================================

download_apple_source() {
    local name=$1
    local version=$2
    local url="https://opensource.apple.com/tarballs/${name}/${name}-${version}.tar.gz"
    local dest="$SOURCES_DIR/${name}-${version}.tar.gz"
    
    if [[ -f "$dest" ]]; then
        log_info "$name-$version already downloaded"
        return 0
    fi
    
    log_info "Downloading $name-$version..."
    if curl -fSL -o "$dest" "$url" 2>/dev/null; then
        log_success "Downloaded $name-$version"
        return 0
    else
        log_warn "Failed to download $name-$version from Apple Open Source"
        return 1
    fi
}

download_all_sources() {
    log_info "Downloading all Apple Open Source tarballs..."
    
    download_apple_source "xnu" "$XNU_VERSION" || true
    download_apple_source "Libc" "$LIBC_VERSION" || true
    download_apple_source "libdispatch" "$LIBDISPATCH_VERSION" || true
    download_apple_source "libxpc" "$LIBXPC_VERSION" || true
    download_apple_source "launchd" "$LAUNCHD_VERSION" || true
    download_apple_source "dyld" "$DYLD_VERSION" || true
    download_apple_source "CF" "$CF_VERSION" || true
    
    log_success "Downloads complete"
}

extract_source() {
    local name=$1
    local version=$2
    local tarball="$SOURCES_DIR/${name}-${version}.tar.gz"
    local dest="$SOURCES_DIR/${name}-${version}"
    
    if [[ -d "$dest" ]]; then
        log_info "$name-$version already extracted"
        return 0
    fi
    
    if [[ ! -f "$tarball" ]]; then
        log_error "Tarball not found: $tarball"
        return 1
    fi
    
    log_info "Extracting $name-$version..."
    tar xzf "$tarball" -C "$SOURCES_DIR"
    log_success "Extracted $name-$version"
}

# =============================================================================
# Build Functions
# =============================================================================

build_libdispatch() {
    log_info "Building libdispatch (Grand Central Dispatch)..."
    
    local src_dir="$SOURCES_DIR/swift-corelibs-libdispatch"
    local build_dir="$BUILD_DIR/libdispatch"
    
    # Prefer Swift open-source version for portability
    if [[ ! -d "$src_dir" ]]; then
        log_info "Cloning swift-corelibs-libdispatch..."
        git clone --depth 1 https://github.com/apple/swift-corelibs-libdispatch.git "$src_dir"
    fi
    
    if ! check_cmake; then
        log_error "CMake required for libdispatch build"
        return 1
    fi
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Configuring libdispatch..."
    cmake "$src_dir" \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_OSX_ARCHITECTURES="$TARGET_ARCH" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$SYSROOT_DIR/usr"
    
    log_info "Building libdispatch..."
    make -j"$JOBS"
    
    log_info "Installing libdispatch..."
    make install
    
    log_success "libdispatch build complete"
}

build_corefoundation() {
    log_info "Building CoreFoundation..."
    
    local src_dir="$SOURCES_DIR/swift-corelibs-foundation"
    local build_dir="$BUILD_DIR/corefoundation"
    
    # Use Swift open-source version
    if [[ ! -d "$src_dir" ]]; then
        log_info "Cloning swift-corelibs-foundation..."
        git clone --depth 1 https://github.com/apple/swift-corelibs-foundation.git "$src_dir"
    fi
    
    local cf_src="$src_dir/Sources/CoreFoundation"
    
    if [[ -f "$cf_src/CMakeLists.txt" ]]; then
        if check_cmake; then
            mkdir -p "$build_dir"
            cd "$build_dir"
            
            cmake "$cf_src" \
                -DCMAKE_C_COMPILER=clang \
                -DCMAKE_OSX_ARCHITECTURES="$TARGET_ARCH" \
                -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_PREFIX_PATH="$SYSROOT_DIR/usr" \
                -DCF_DEPLOYMENT_SWIFT=OFF || true
            
            make -j"$JOBS" || log_warn "CoreFoundation build had errors"
        fi
    else
        log_warn "CoreFoundation requires Swift build system"
        log_info "Copying headers only..."
        mkdir -p "$SYSROOT_DIR/usr/include/CoreFoundation"
        find "$cf_src" -name "*.h" -exec cp {} "$SYSROOT_DIR/usr/include/CoreFoundation/" \; 2>/dev/null || true
    fi
    
    log_success "CoreFoundation setup complete"
}

build_launchd() {
    log_info "Building launchd..."
    
    extract_source "launchd" "$LAUNCHD_VERSION" || {
        log_error "launchd source not available"
        return 1
    }
    
    local src_dir="$SOURCES_DIR/launchd-$LAUNCHD_VERSION"
    cd "$src_dir"
    
    # Check for build system
    if ls *.xcodeproj 1> /dev/null 2>&1; then
        log_info "Found Xcode project, attempting build..."
        
        xcodebuild -list || true
        
        xcodebuild -project *.xcodeproj \
            -alltargets \
            -configuration Release \
            ARCHS="$TARGET_ARCH" \
            VALID_ARCHS="$TARGET_ARCH" \
            SDKROOT=macosx \
            ONLY_ACTIVE_ARCH=NO \
            DSTROOT="$SYSROOT_DIR" \
            2>&1 || log_warn "launchd build completed with errors (expected - may need additional dependencies)"
    elif [[ -f Makefile ]]; then
        log_info "Found Makefile, attempting build..."
        make ARCH="$TARGET_ARCH" DSTROOT="$SYSROOT_DIR" || log_warn "Make build had errors"
    else
        log_error "No build system found for launchd"
        return 1
    fi
    
    log_success "launchd build attempt complete"
}

build_dyld() {
    log_info "Building dyld..."
    
    extract_source "dyld" "$DYLD_VERSION" || {
        log_error "dyld source not available"
        return 1
    }
    
    local src_dir="$SOURCES_DIR/dyld-$DYLD_VERSION"
    cd "$src_dir"
    
    if ls *.xcodeproj 1> /dev/null 2>&1; then
        log_info "Found Xcode project, attempting build..."
        
        xcodebuild -list || true
        
        xcodebuild -project dyld.xcodeproj \
            -scheme dyld \
            -configuration Release \
            ARCHS="$TARGET_ARCH" \
            SDKROOT=macosx \
            DSTROOT="$SYSROOT_DIR" \
            2>&1 || log_warn "dyld build completed with errors (expected)"
    else
        log_error "No Xcode project found for dyld"
        return 1
    fi
    
    log_success "dyld build attempt complete"
}

build_all() {
    log_info "Building all Darwin userland components..."
    
    download_all_sources
    
    # Build in dependency order
    build_libdispatch || log_warn "libdispatch build failed"
    build_corefoundation || log_warn "CoreFoundation build failed"
    build_launchd || log_warn "launchd build failed"
    build_dyld || log_warn "dyld build failed"
    
    log_success "Build process complete"
    log_info "Sysroot location: $SYSROOT_DIR"
}

clean_all() {
    log_info "Cleaning build directories..."
    rm -rf "$BUILD_DIR"
    rm -rf "$SYSROOT_DIR"
    log_success "Clean complete"
}

# =============================================================================
# Main
# =============================================================================

usage() {
    cat << EOF
Darwin Userland Build Script

Usage: $0 [component] [options]

Components:
    all             Build all components (default)
    libdispatch     Build libdispatch (GCD)
    cf              Build CoreFoundation
    launchd         Build launchd
    dyld            Build dyld

Options:
    --download      Download sources only
    --clean         Clean build directories
    --verbose       Enable verbose output
    --help          Show this help message

Environment Variables:
    SOURCES_DIR     Source download directory (default: ./sources)
    BUILD_DIR       Build output directory (default: ./build)
    SYSROOT_DIR     Install sysroot directory (default: ./sysroot)
    TARGET_ARCH     Target architecture (default: arm64)
    JOBS            Parallel jobs for make (default: auto)

Examples:
    $0                      # Build all components
    $0 libdispatch          # Build only libdispatch
    $0 --download           # Download sources only
    $0 --clean              # Clean build directories
EOF
}

main() {
    local component="all"
    local download_only=false
    local clean=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            all|libdispatch|cf|launchd|dyld)
                component=$1
                shift
                ;;
            --download)
                download_only=true
                shift
                ;;
            --clean)
                clean=true
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check environment
    check_macos
    check_xcode
    create_directories
    
    # Handle clean
    if $clean; then
        clean_all
        exit 0
    fi
    
    # Handle download only
    if $download_only; then
        download_all_sources
        exit 0
    fi
    
    # Build component
    case $component in
        all)
            build_all
            ;;
        libdispatch)
            download_all_sources
            build_libdispatch
            ;;
        cf)
            download_all_sources
            build_libdispatch  # dependency
            build_corefoundation
            ;;
        launchd)
            download_all_sources
            build_libdispatch  # dependency
            build_launchd
            ;;
        dyld)
            download_all_sources
            build_dyld
            ;;
    esac
    
    log_info "Done!"
}

main "$@"
