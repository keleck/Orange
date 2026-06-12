#!/bin/bash

# 一键部署脚本 - 提交、推送、构建、发布

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════╗
║   Flutter 全端客户端一键部署工具            ║
╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# 1. 显示当前状态
echo -e "${BLUE}[1/6] 检查仓库状态...${NC}"
git status --short

# 2. 提交更改
echo -e "\n${BLUE}[2/6] 提交更改...${NC}"
echo -e "${YELLOW}输入提交信息 (默认: 全端构建更新):${NC}"
read -p "> " commit_msg
commit_msg=${commit_msg:-"feat: 全端构建更新"}

git add .
git commit -m "$commit_msg" || echo "没有新的更改需要提交"

# 3. 推送到远程
echo -e "\n${BLUE}[3/6] 推送到远程仓库...${NC}"
current_branch=$(git branch --show-current)
git push -u origin "$current_branch"

# 4. 询问是否创建发布
echo -e "\n${YELLOW}是否创建发布版本并触发构建? (y/N)${NC}"
read -p "> " create_release

if [ "$create_release" = "y" ] || [ "$create_release" = "Y" ]; then
    # 5. 读取版本号
    echo -e "\n${BLUE}[4/6] 准备发布版本...${NC}"
    current_version=$(grep "^version:" pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
    echo -e "当前版本: ${GREEN}$current_version${NC}"
    
    echo -e "${YELLOW}输入新版本号 (留空使用当前版本):${NC}"
    read -p "> " new_version
    new_version=${new_version:-$current_version}
    
    tag_name="v$new_version"
    
    # 6. 创建并推送标签
    echo -e "\n${BLUE}[5/6] 创建发布标签...${NC}"
    echo -e "${YELLOW}输入发布说明:${NC}"
    read -p "> " release_notes
    release_notes=${release_notes:-"Release $new_version"}
    
    git tag -a "$tag_name" -m "$release_notes"
    git push origin "$tag_name"
    
    echo -e "\n${GREEN}✓ 发布标签已创建: $tag_name${NC}"
    echo -e "${GREEN}✓ GitHub Actions 将自动开始构建所有平台${NC}"
    
    # 显示 Actions 链接
    remote_url=$(git remote get-url origin)
    if [[ $remote_url == *"github.com"* ]]; then
        repo_path=$(echo $remote_url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
        echo -e "\n${BLUE}查看构建进度:${NC}"
        echo -e "https://github.com/$repo_path/actions"
    fi
else
    echo -e "\n${YELLOW}跳过发布，仅推送代码${NC}"
fi

# 7. 询问是否本地构建
echo -e "\n${YELLOW}是否在本地构建? (y/N)${NC}"
read -p "> " local_build

if [ "$local_build" = "y" ] || [ "$local_build" = "Y" ]; then
    echo -e "\n${BLUE}[6/6] 本地构建...${NC}"
    echo -e "${YELLOW}选择构建平台:${NC}"
    echo "1) Android"
    echo "2) iOS"
    echo "3) macOS"
    echo "4) Windows"
    echo "5) Linux"
    echo "6) 所有平台"
    read -p "> " platform_choice
    
    case $platform_choice in
        1) ./build_all_platforms.sh android ;;
        2) ./build_all_platforms.sh ios ;;
        3) ./build_all_platforms.sh macos ;;
        4) ./build_all_platforms.sh windows ;;
        5) ./build_all_platforms.sh linux ;;
        6) ./build_all_platforms.sh all ;;
        *) echo "无效选择" ;;
    esac
fi

echo -e "\n${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════╗
║            🎉 部署完成！                     ║
╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}"
