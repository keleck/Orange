#!/bin/bash

# 全端客户端构建脚本
# 支持 Android, iOS, macOS, Windows, Linux

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 显示使用帮助
show_help() {
    cat << EOF
使用方法: $0 [选项] [平台]

平台选项:
    android     - 构建 Android APK 和 AAB
    ios         - 构建 iOS IPA (需要 macOS)
    macos       - 构建 macOS DMG (需要 macOS)
    windows     - 构建 Windows EXE
    linux       - 构建 Linux AppImage/DEB
    all         - 构建所有平台 (默认)
    
其他选项:
    -h, --help  - 显示此帮助信息
    -c, --clean - 构建前清理缓存
    -r, --release - 仅构建 Release 版本 (默认同时构建 Debug 和 Release)
    
示例:
    $0 android              # 仅构建 Android
    $0 -c macos             # 清理后构建 macOS
    $0 -r all               # 构建所有平台的 Release 版本
    
EOF
}

# 检查 Flutter 环境
check_flutter() {
    log_info "检查 Flutter 环境..."
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装或不在 PATH 中"
        exit 1
    fi
    
    flutter --version
    log_success "Flutter 环境检查通过"
}

# 清理构建缓存
clean_build() {
    log_info "清理构建缓存..."
    flutter clean
    rm -rf build/
    rm -rf dist/
    log_success "清理完成"
}

# 获取依赖
get_dependencies() {
    log_info "获取项目依赖..."
    flutter pub get
    log_success "依赖获取完成"
}

# 构建 Android
build_android() {
    log_info "开始构建 Android..."
    
    # 构建 APK
    log_info "构建 Android APK (arm64-v8a)..."
    flutter build apk --release --target-platform android-arm64 --split-per-abi
    
    log_info "构建 Android APK (armeabi-v7a)..."
    flutter build apk --release --target-platform android-arm --split-per-abi
    
    log_info "构建 Android APK (x86_64)..."
    flutter build apk --release --target-platform android-x64 --split-per-abi
    
    # 构建 AAB (Google Play)
    log_info "构建 Android App Bundle (AAB)..."
    flutter build appbundle --release
    
    # 移动构建产物
    mkdir -p dist/android
    cp build/app/outputs/flutter-apk/*.apk dist/android/ 2>/dev/null || true
    cp build/app/outputs/bundle/release/*.aab dist/android/ 2>/dev/null || true
    
    log_success "Android 构建完成！"
    log_info "APK 位置: dist/android/"
}

# 构建 iOS
build_ios() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "iOS 构建需要在 macOS 上进行，跳过..."
        return
    fi
    
    log_info "开始构建 iOS..."
    
    # 构建 iOS
    flutter build ios --release --no-codesign
    
    # 如果配置了证书，可以构建 IPA
    if [ -f "ios/exportOptions.plist" ]; then
        log_info "构建 iOS IPA..."
        flutter build ipa --release
        
        mkdir -p dist/ios
        cp build/ios/ipa/*.ipa dist/ios/ 2>/dev/null || true
    else
        log_warning "未找到 exportOptions.plist，跳过 IPA 打包"
    fi
    
    log_success "iOS 构建完成！"
}

# 构建 macOS
build_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "macOS 构建需要在 macOS 上进行，跳过..."
        return
    fi
    
    log_info "开始构建 macOS..."
    
    # 构建 macOS 应用
    flutter build macos --release
    
    # 创建 DMG (如果有 flutter_distributor)
    if grep -q "flutter_distributor" pubspec.yaml; then
        log_info "使用 flutter_distributor 打包 macOS DMG..."
        flutter_distributor package --platform macos --targets dmg
        
        mkdir -p dist/macos
        cp dist/*/*.dmg dist/macos/ 2>/dev/null || true
    else
        log_warning "未安装 flutter_distributor，仅构建 .app 文件"
        mkdir -p dist/macos
        cp -r build/macos/Build/Products/Release/*.app dist/macos/
    fi
    
    log_success "macOS 构建完成！"
    log_info "应用位置: dist/macos/"
}

# 构建 Windows
build_windows() {
    log_info "开始构建 Windows..."
    
    # 构建 Windows 可执行文件
    flutter build windows --release
    
    # 如果有 flutter_distributor，打包为 EXE 安装包
    if grep -q "flutter_distributor" pubspec.yaml; then
        log_info "使用 flutter_distributor 打包 Windows EXE..."
        flutter_distributor package --platform windows --targets exe
        
        mkdir -p dist/windows
        cp dist/*/*.exe dist/windows/ 2>/dev/null || true
    else
        log_warning "未安装 flutter_distributor，仅构建应用文件"
        mkdir -p dist/windows
        cp -r build/windows/x64/runner/Release/* dist/windows/
    fi
    
    log_success "Windows 构建完成！"
    log_info "应用位置: dist/windows/"
}

# 构建 Linux
build_linux() {
    if [[ "$OSTYPE" != "linux-gnu"* ]] && [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "Linux 构建通常需要在 Linux 上进行，跳过..."
        return
    fi
    
    log_info "开始构建 Linux..."
    
    # 构建 Linux 应用
    flutter build linux --release
    
    # 如果有 flutter_distributor，打包为 AppImage/DEB
    if grep -q "flutter_distributor" pubspec.yaml; then
        log_info "使用 flutter_distributor 打包 Linux AppImage/DEB..."
        flutter_distributor package --platform linux --targets appimage,deb
        
        mkdir -p dist/linux
        cp dist/*/*.{AppImage,deb} dist/linux/ 2>/dev/null || true
    else
        log_warning "未安装 flutter_distributor，仅构建应用文件"
        mkdir -p dist/linux
        cp -r build/linux/x64/release/bundle/* dist/linux/
    fi
    
    log_success "Linux 构建完成！"
    log_info "应用位置: dist/linux/"
}

# 构建所有平台
build_all() {
    log_info "开始构建所有平台..."
    
    build_android
    build_ios
    build_macos
    build_windows
    build_linux
    
    log_success "所有平台构建完成！"
}

# 显示构建结果
show_results() {
    log_info "=========================================="
    log_info "构建产物位置:"
    log_info "=========================================="
    
    if [ -d "dist" ]; then
        find dist -type f \( -name "*.apk" -o -name "*.aab" -o -name "*.ipa" -o -name "*.dmg" -o -name "*.exe" -o -name "*.AppImage" -o -name "*.deb" \) -exec ls -lh {} \;
    fi
    
    log_info "=========================================="
}

# 主函数
main() {
    local CLEAN=false
    local PLATFORM="all"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                CLEAN=true
                shift
                ;;
            -r|--release)
                log_info "Release 模式已是默认模式"
                shift
                ;;
            android|ios|macos|windows|linux|all)
                PLATFORM=$1
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "=========================================="
    log_info "Flutter 全端构建脚本"
    log_info "=========================================="
    
    # 检查环境
    check_flutter
    
    # 清理（如果需要）
    if [ "$CLEAN" = true ]; then
        clean_build
    fi
    
    # 获取依赖
    get_dependencies
    
    # 根据平台参数构建
    case $PLATFORM in
        android)
            build_android
            ;;
        ios)
            build_ios
            ;;
        macos)
            build_macos
            ;;
        windows)
            build_windows
            ;;
        linux)
            build_linux
            ;;
        all)
            build_all
            ;;
    esac
    
    # 显示结果
    show_results
    
    log_success "=========================================="
    log_success "构建流程完成！"
    log_success "=========================================="
}

# 运行主函数
main "$@"
