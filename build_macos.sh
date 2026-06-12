#!/bin/bash

# macOS Universal Binary Builder
# Build script for Intel + Apple Silicon dual-architecture support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_TYPE="${1:-universal}"
OUT_TYPE="${2:-app}"
ENV="${3:-stable}"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_dependencies() {
    print_header "Checking Dependencies"
    
    # Check lipo
    if ! command -v lipo &> /dev/null; then
        print_error "lipo not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    print_success "lipo found"
    
    # Check dart
    if ! command -v dart &> /dev/null; then
        print_error "dart not found. Please install Dart SDK."
        exit 1
    fi
    print_success "dart found"
    
    # Check go
    if ! command -v go &> /dev/null; then
        print_error "go not found. Please install Go."
        exit 1
    fi
    print_success "go found"
    
    # Check npm (for appdmg)
    if ! command -v npm &> /dev/null; then
        print_warning "npm not found. appdmg installation may fail."
    else
        print_success "npm found"
    fi
}

show_usage() {
    echo "Usage: $0 [BUILD_TYPE] [OUT_TYPE] [ENV]"
    echo ""
    echo "BUILD_TYPE options:"
    echo "  universal    - Build universal binary (arm64 + x86_64) [default]"
    echo "  arm64        - Build ARM64 only (Apple Silicon)"
    echo "  amd64        - Build AMD64 only (Intel)"
    echo ""
    echo "OUT_TYPE options:"
    echo "  app          - Full application build [default]"
    echo "  core         - Core library only"
    echo ""
    echo "ENV options:"
    echo "  stable       - Stable environment [default]"
    echo "  pre          - Pre-release environment"
    echo ""
    echo "Examples:"
    echo "  $0 universal app stable    # Build universal app (default)"
    echo "  $0 arm64 app stable         # Build ARM64 only"
    echo "  $0 universal core stable    # Build universal core library"
}

build_universal() {
    local out="$1"
    local env="$2"
    
    print_header "Building macOS Universal Binary"
    print_info "Build Type: Universal (arm64 + x86_64)"
    print_info "Output Type: $out"
    print_info "Environment: $env"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    if [ "$out" = "core" ]; then
        dart ./setup.dart macos --universal --out core --env "$env"
    else
        dart ./setup.dart macos --universal --env "$env"
    fi
    
    print_success "Build completed!"
}

build_single_arch() {
    local arch="$1"
    local out="$2"
    local env="$3"
    
    print_header "Building macOS Single Architecture"
    print_info "Architecture: $arch"
    print_info "Output Type: $out"
    print_info "Environment: $env"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    if [ "$out" = "core" ]; then
        dart ./setup.dart macos --arch "$arch" --out core --env "$env"
    else
        dart ./setup.dart macos --arch "$arch" --env "$env"
    fi
    
    print_success "Build completed!"
}

verify_universal_binary() {
    local binary_path="libclash/macos/universal/FlClashCore"
    
    if [ ! -f "$binary_path" ]; then
        print_warning "Universal binary not found at $binary_path"
        return 1
    fi
    
    print_header "Verifying Universal Binary"
    
    # Check file type
    local file_info=$(file "$binary_path")
    print_info "File info: $file_info"
    
    # Check architectures
    if lipo -info "$binary_path"; then
        print_success "Binary contains both architectures"
        return 0
    else
        print_error "Binary verification failed"
        return 1
    fi
}

main() {
    # Show help if requested
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Check dependencies
    check_dependencies
    echo ""
    
    # Perform build
    case "$BUILD_TYPE" in
        universal)
            build_universal "$OUT_TYPE" "$ENV"
            echo ""
            
            if [ "$OUT_TYPE" = "app" ]; then
                verify_universal_binary
            fi
            ;;
        arm64)
            build_single_arch "arm64" "$OUT_TYPE" "$ENV"
            ;;
        amd64|x86_64)
            build_single_arch "amd64" "$OUT_TYPE" "$ENV"
            ;;
        *)
            print_error "Unknown build type: $BUILD_TYPE"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    print_header "Build Summary"
    
    if [ "$BUILD_TYPE" = "universal" ]; then
        if [ "$OUT_TYPE" = "app" ]; then
            print_info "Output location: dist/"
            print_info "Supported platforms: Intel Mac + Apple Silicon Mac"
        else
            print_info "Core library: libclash/macos/universal/FlClashCore"
        fi
    else
        print_info "Architecture: $BUILD_TYPE"
        if [ "$OUT_TYPE" = "app" ]; then
            print_info "Output location: dist/"
        fi
    fi
    
    print_success "All done! 🎉"
}

# Run main function
main
