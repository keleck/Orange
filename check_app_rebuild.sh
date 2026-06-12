#!/bin/bash

# 检查应用是否已重新构建以支持 XHTTP

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_header "应用构建状态检查"

echo ""
print_info "检查内核是否已更新并支持 XHTTP..."
echo ""

# 检查内核版本
cd core/Clash.Meta
CURRENT_COMMIT=$(git log -1 --oneline)
echo "当前内核版本: $CURRENT_COMMIT"
echo ""

# 检查 XHTTP 支持
if [ -d "transport/xhttp" ]; then
    print_success "内核包含 XHTTP 支持"
    echo ""
    print_info "XHTTP 文件列表:"
    ls -la transport/xhttp/ | grep "\.go$" | awk '{print "  - " $9}'
    echo ""
else
    print_error "内核不包含 XHTTP 支持"
    echo ""
    print_warning "请先更新内核:"
    echo "  ./update_mihomo_core.sh"
    exit 1
fi

cd ../..

# 检查构建产物
print_header "检查构建产物"
echo ""

BUILD_NEEDED=false

# 检查 Android 构建
if [ -d "libclash/android" ]; then
    print_info "检查 Android 构建..."
    
    # 检查构建时间
    if [ -f "libclash/android/arm64-v8a/libclash.so" ]; then
        BUILD_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" libclash/android/arm64-v8a/libclash.so 2>/dev/null || stat -c "%y" libclash/android/arm64-v8a/libclash.so 2>/dev/null | cut -d'.' -f1)
        CORE_UPDATE_TIME=$(cd core/Clash.Meta && git log -1 --format="%ci" | cut -d' ' -f1,2)
        
        echo "  构建时间: $BUILD_TIME"
        echo "  内核更新: $CORE_UPDATE_TIME"
        echo ""
        
        # 简单比较（这里只是提示，不是精确比较）
        print_warning "请确认构建时间晚于内核更新时间"
        BUILD_NEEDED=true
    else
        print_warning "未找到 Android 构建产物"
        BUILD_NEEDED=true
    fi
else
    print_info "未找到 Android 构建目录"
fi

echo ""

# 检查 macOS 构建
if [ -d "libclash/macos" ]; then
    print_info "检查 macOS 构建..."
    
    if [ -f "libclash/macos/universal/FlClashCore" ]; then
        BUILD_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" libclash/macos/universal/FlClashCore 2>/dev/null || echo "未知")
        echo "  构建时间: $BUILD_TIME"
        print_warning "请确认构建时间晚于内核更新时间"
        BUILD_NEEDED=true
    else
        print_warning "未找到 macOS 构建产物"
        BUILD_NEEDED=true
    fi
else
    print_info "未找到 macOS 构建目录"
fi

echo ""

# 给出建议
print_header "构建建议"
echo ""

if [ "$BUILD_NEEDED" = true ]; then
    print_warning "检测到可能需要重新构建应用"
    echo ""
    echo "📋 重新构建步骤:"
    echo ""
    echo "1. 清理旧的构建产物:"
    echo "   rm -rf libclash/ build/"
    echo ""
    echo "2. 重新构建应用:"
    echo ""
    echo "   # Android"
    echo "   make android_arm64"
    echo ""
    echo "   # macOS"
    echo "   make macos_universal"
    echo ""
    echo "   # Windows"
    echo "   dart ./setup.dart windows"
    echo ""
    echo "   # Linux"
    echo "   dart ./setup.dart linux"
    echo ""
fi

print_header "配置建议"
echo ""

print_info "由于第三方客户端可以使用该配置，建议:"
echo ""
echo "1️⃣ 确保应用已重新构建（使用更新后的内核）"
echo ""
echo "2️⃣ 尝试以下配置（按顺序）:"
echo ""
echo "   配置 A: 完全相同（需要应用支持）"
echo "   ---"
echo "   network: xhttp"
echo "   flow: ''"
echo "   # 不添加 xhttp-opts"
echo ""
echo "   配置 B: 添加默认 xhttp-opts"
echo "   ---"
echo "   network: xhttp"
echo "   flow: ''"
echo "   xhttp-opts:"
echo "     host: 131.143.242.253"
echo "     path: /"
echo ""
echo "   配置 C: 添加 flow 参数"
echo "   ---"
echo "   network: xhttp"
echo "   flow: xtls-rprx-vision"
echo "   xhttp-opts:"
echo "     host: 131.143.242.253"
echo "     path: /"
echo ""

print_header "关键检查点"
echo ""

echo "✓ 检查清单:"
echo ""
echo "  [ ] 内核已更新到 v1.19.24"
echo "  [ ] 内核包含 XHTTP 支持"
echo "  [ ] 应用已重新构建"
echo "  [ ] 构建时间晚于内核更新"
echo "  [ ] 配置已更新"
echo ""

print_info "如果所有检查都通过但仍然超时，可能是:"
echo "  1. 应用的 XHTTP 实现与第三方客户端不同"
echo "  2. 需要特定的配置参数"
echo "  3. 需要查看应用的详细日志"
echo ""

print_header "下一步"
echo ""

if [ "$BUILD_NEEDED" = true ]; then
    print_warning "强烈建议: 重新构建应用"
    echo ""
    echo "命令: make android_arm64  # 或你的目标平台"
else
    print_success "构建产物存在，但请确认是最新的"
fi

echo ""
print_info "配置文件已生成: hk_node_working_config.yaml"
print_info "包含 6 种不同的配置变体供测试"