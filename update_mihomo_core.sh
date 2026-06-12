#!/bin/bash

# Mihomo 内核更新脚本
# 更新到 v1.19.24 版本，支持 VLESS Reality + XHTTP

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 目标版本
TARGET_VERSION="v1.19.24"
MIHOMO_REPO="https://github.com/MetaCubeX/mihomo.git"

print_header "Mihomo 内核更新到 ${TARGET_VERSION}"
echo ""
print_info "新功能: VLESS Reality + XHTTP 支持"
echo ""

# 检查是否在项目根目录
if [ ! -d "core/Clash.Meta" ]; then
    print_error "请在项目根目录运行此脚本"
    exit 1
fi

# 进入 Clash.Meta 子模块目录
cd core/Clash.Meta

print_info "当前目录: $(pwd)"
echo ""

# 显示当前版本信息
print_header "当前版本信息"
CURRENT_COMMIT=$(git log -1 --oneline)
print_info "当前提交: ${CURRENT_COMMIT}"
echo ""

# 检查是否有未提交的更改
if ! git diff-index --quiet HEAD --; then
    print_warning "检测到未提交的更改"
    echo ""
    git status --short
    echo ""
    read -p "是否继续？这将暂存当前更改 (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "操作已取消"
        exit 0
    fi
    git stash push -m "Auto stash before mihomo update to ${TARGET_VERSION}"
    print_success "已暂存当前更改"
    echo ""
fi

# 添加 mihomo 官方仓库作为远程源
print_header "配置远程仓库"
if git remote | grep -q "^mihomo$"; then
    print_info "mihomo 远程源已存在，更新 URL"
    git remote set-url mihomo "${MIHOMO_REPO}"
else
    print_info "添加 mihomo 官方远程源"
    git remote add mihomo "${MIHOMO_REPO}"
fi
print_success "远程源配置完成"
echo ""

# 拉取 mihomo 官方仓库
print_header "拉取 Mihomo 官方仓库"
git fetch mihomo --tags
print_success "拉取完成"
echo ""

# 检查目标版本是否存在
if ! git rev-parse "${TARGET_VERSION}" >/dev/null 2>&1; then
    print_error "版本 ${TARGET_VERSION} 不存在"
    print_info "可用的最新版本:"
    git tag -l "v1.*" | tail -5
    exit 1
fi

# 显示版本信息
print_header "目标版本信息"
git log -1 --oneline "${TARGET_VERSION}"
echo ""
git show "${TARGET_VERSION}:go.mod" | grep "^module"
echo ""

# 创建备份分支
BACKUP_BRANCH="backup-before-${TARGET_VERSION}-$(date +%Y%m%d-%H%M%S)"
print_info "创建备份分支: ${BACKUP_BRANCH}"
git branch "${BACKUP_BRANCH}"
print_success "备份分支已创建"
echo ""

# 询问合并策略
print_header "选择更新策略"
echo "1) 合并 (merge) - 保留 FlClash 的修改，合并新功能"
echo "2) 变基 (rebase) - 将 FlClash 的修改应用到新版本之上"
echo "3) 仅查看差异 (diff) - 不进行更新"
echo ""
read -p "请选择 (1/2/3): " -n 1 -r
echo ""

case $REPLY in
    1)
        print_header "执行合并操作"
        print_info "合并 ${TARGET_VERSION} 到当前分支"
        echo ""
        
        if git merge "${TARGET_VERSION}" --no-edit -m "Merge mihomo ${TARGET_VERSION} - Add VLESS Reality + XHTTP support"; then
            print_success "合并成功！"
        else
            print_warning "合并遇到冲突，需要手动解决"
            print_info "冲突文件:"
            git diff --name-only --diff-filter=U
            echo ""
            print_info "解决冲突后运行:"
            echo "  git add ."
            echo "  git commit -m 'Resolve merge conflicts for ${TARGET_VERSION}'"
            exit 1
        fi
        ;;
    2)
        print_header "执行变基操作"
        print_info "将当前分支变基到 ${TARGET_VERSION}"
        echo ""
        
        if git rebase "${TARGET_VERSION}"; then
            print_success "变基成功！"
        else
            print_warning "变基遇到冲突，需要手动解决"
            print_info "解决冲突后运行:"
            echo "  git add ."
            echo "  git rebase --continue"
            echo ""
            print_info "或者放弃变基:"
            echo "  git rebase --abort"
            exit 1
        fi
        ;;
    3)
        print_header "显示差异"
        git log --oneline HEAD.."${TARGET_VERSION}" | head -20
        echo ""
        print_info "查看完整差异:"
        echo "  cd core/Clash.Meta"
        echo "  git diff HEAD..${TARGET_VERSION}"
        exit 0
        ;;
    *)
        print_error "无效的选择"
        exit 1
        ;;
esac

echo ""
print_header "更新后的版本信息"
git log -1 --oneline
echo ""

# 检查 go.mod 中的模块名称
print_info "检查 go.mod 模块名称"
MODULE_NAME=$(grep "^module" go.mod | awk '{print $2}')
print_info "模块名称: ${MODULE_NAME}"
echo ""

# 返回项目根目录
cd ../..

print_header "更新完成！"
echo ""
print_success "Mihomo 内核已更新到 ${TARGET_VERSION}"
print_success "新增功能: VLESS Reality + XHTTP 支持"
echo ""

print_header "后续步骤"
echo "1. 测试内核功能:"
echo "   cd core/Clash.Meta"
echo "   go build"
echo ""
echo "2. 重新构建应用:"
echo "   make android_arm64        # Android ARM64"
echo "   make macos_universal      # macOS 通用版本"
echo ""
echo "3. 如果遇到问题，恢复到备份:"
echo "   cd core/Clash.Meta"
echo "   git checkout ${BACKUP_BRANCH}"
echo ""
echo "4. 查看更新日志:"
echo "   https://github.com/MetaCubeX/mihomo/releases/tag/${TARGET_VERSION}"
echo ""

print_info "备份分支: ${BACKUP_BRANCH}"
print_info "可以随时恢复到更新前的状态"
