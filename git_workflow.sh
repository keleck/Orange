#!/bin/bash

# Git 工作流管理脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助
show_help() {
    cat << EOF
Git 工作流管理脚本

使用方法: $0 [命令]

命令:
    status          - 查看仓库状态
    commit          - 提交所有更改
    push            - 推送到远程仓库
    release         - 创建发布标签
    sync            - 同步子模块
    clean           - 清理未跟踪的文件
    init            - 初始化 Git 仓库和子模块
    
示例:
    $0 status       # 查看状态
    $0 commit       # 提交所有更改
    $0 release      # 创建发布版本
    
EOF
}

# 查看状态
git_status() {
    log_info "=== Git 仓库状态 ==="
    git status
    
    log_info "\n=== 子模块状态 ==="
    git submodule status || log_warning "没有子模块或子模块未初始化"
    
    log_info "\n=== 当前分支 ==="
    git branch -v
    
    log_info "\n=== 远程状态 ==="
    git remote -v
}

# 提交更改
git_commit() {
    log_info "开始提交流程..."
    
    # 检查是否有更改
    if git diff-index --quiet HEAD --; then
        log_warning "没有需要提交的更改"
        return
    fi
    
    # 显示将要提交的文件
    log_info "将提交以下更改:"
    git status --short
    
    # 询问提交信息
    echo -e "\n${YELLOW}请输入提交信息 (按 Enter 使用默认信息):${NC}"
    read -p "提交信息: " commit_msg
    
    if [ -z "$commit_msg" ]; then
        commit_msg="feat: 添加全端构建支持和 Git 工作流"
    fi
    
    # 添加所有更改
    log_info "添加文件到暂存区..."
    git add .
    
    # 提交
    log_info "提交更改..."
    git commit -m "$commit_msg"
    
    log_success "提交完成！"
    log_info "提交信息: $commit_msg"
}

# 推送到远程
git_push() {
    log_info "推送到远程仓库..."
    
    # 获取当前分支
    current_branch=$(git branch --show-current)
    
    log_info "当前分支: $current_branch"
    
    # 检查是否有远程仓库
    if ! git remote | grep -q "origin"; then
        log_error "未配置远程仓库 'origin'"
        log_info "使用以下命令添加远程仓库:"
        log_info "  git remote add origin <repository-url>"
        exit 1
    fi
    
    # 推送
    log_info "推送分支 $current_branch 到 origin..."
    git push -u origin "$current_branch"
    
    log_success "推送完成！"
}

# 创建发布标签
git_release() {
    log_info "创建发布版本..."
    
    # 读取当前版本
    if [ -f "pubspec.yaml" ]; then
        current_version=$(grep "^version:" pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
        log_info "当前版本: $current_version"
    else
        current_version="2.7.0"
    fi
    
    # 询问版本号
    echo -e "\n${YELLOW}请输入新版本号 (当前: $current_version):${NC}"
    read -p "版本号 (留空使用当前版本): " new_version
    
    if [ -z "$new_version" ]; then
        new_version=$current_version
    fi
    
    tag_name="v$new_version"
    
    # 检查标签是否已存在
    if git tag | grep -q "^$tag_name$"; then
        log_error "标签 $tag_name 已存在！"
        exit 1
    fi
    
    # 询问发布说明
    echo -e "\n${YELLOW}请输入发布说明:${NC}"
    read -p "发布说明: " release_notes
    
    if [ -z "$release_notes" ]; then
        release_notes="Release $new_version with multi-platform support"
    fi
    
    # 创建标签
    log_info "创建标签 $tag_name..."
    git tag -a "$tag_name" -m "$release_notes"
    
    # 推送标签
    log_info "推送标签到远程..."
    git push origin "$tag_name"
    
    log_success "发布标签创建完成！"
    log_info "标签: $tag_name"
    log_info "说明: $release_notes"
    log_info "\nGitHub Actions 将自动开始构建所有平台..."
}

# 同步子模块
git_sync_submodules() {
    log_info "同步子模块..."
    
    if [ ! -f ".gitmodules" ]; then
        log_warning "项目没有子模块"
        return
    fi
    
    # 初始化子模块
    log_info "初始化子模块..."
    git submodule init
    
    # 同步子模块 URL
    log_info "同步子模块 URL..."
    git submodule sync
    
    # 更新子模块
    log_info "更新子模块..."
    git submodule update --init --recursive
    
    # 更新到最新
    echo -e "\n${YELLOW}是否将子模块更新到最新版本? (y/N)${NC}"
    read -p "选择: " update_latest
    
    if [ "$update_latest" = "y" ] || [ "$update_latest" = "Y" ]; then
        log_info "更新子模块到最新版本..."
        git submodule update --remote --recursive
    fi
    
    log_success "子模块同步完成！"
}

# 清理未跟踪文件
git_clean() {
    log_warning "这将删除所有未跟踪的文件和目录！"
    log_info "未跟踪的文件:"
    git clean -fd --dry-run
    
    echo -e "\n${YELLOW}确认删除? (y/N)${NC}"
    read -p "选择: " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        git clean -fd
        log_success "清理完成！"
    else
        log_info "已取消"
    fi
}

# 初始化仓库
git_init() {
    log_info "初始化 Git 仓库..."
    
    # 检查是否已是 Git 仓库
    if [ -d ".git" ]; then
        log_info "已经是 Git 仓库"
    else
        git init
        log_success "Git 仓库初始化完成"
    fi
    
    # 初始化子模块
    if [ -f ".gitmodules" ]; then
        git_sync_submodules
    fi
    
    log_info "\n添加远程仓库:"
    log_info "  git remote add origin <repository-url>"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case $1 in
        status)
            git_status
            ;;
        commit)
            git_commit
            ;;
        push)
            git_push
            ;;
        release)
            git_release
            ;;
        sync)
            git_sync_submodules
            ;;
        clean)
            git_clean
            ;;
        init)
            git_init
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
