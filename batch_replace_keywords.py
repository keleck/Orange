#!/usr/bin/env python3
"""
批量修改关键词脚本（Python 版本）
使用方法:
    python3 batch_replace_keywords.py -c 梦想云 地平线 -e mxycloud horizon
    python3 batch_replace_keywords.py -c 梦想云 地平线 -e mxycloud horizon --dry-run
"""

import os
import sys
import argparse
import re
from pathlib import Path
from typing import List, Tuple


# 需要修改的文件列表
DEFAULT_FILES = [
    "setup.dart",
    "lib/common/constant.dart",
    "windows/CMakeLists.txt",
    "distribute_options.yaml",
    "windows/packaging/exe/make_config.yaml",
    "windows/runner/main.cpp",
    "windows/runner/Runner.rc",
    "android/app/src/debug/AndroidManifest.xml",
    "android/app/src/main/AndroidManifest.xml",
    "android/app/src/main/res/values/strings.xml",
    "macos/Runner/Configs/AppInfo.xcconfig",
    "macos/packaging/dmg/make_config.yaml",
]


def escape_special_chars(text: str) -> str:
    """转义特殊字符用于正则表达式"""
    return re.escape(text)


def replace_in_file(
    file_path: str,
    replacements: List[Tuple[str, str]],
    dry_run: bool = False
) -> Tuple[bool, int]:
    """
    在文件中进行替换
    返回: (成功与否, 替换次数)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        total_replacements = 0
        
        for old, new in replacements:
            # 对于简单的替换使用 replace 而不是正则表达式
            count = content.count(old)
            if count > 0:
                content = content.replace(old, new)
                total_replacements += count
        
        if total_replacements > 0 and not dry_run:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
        
        return True, total_replacements
    except Exception as e:
        print(f"错误 {file_path}: {e}", file=sys.stderr)
        return False, 0


def main():
    parser = argparse.ArgumentParser(
        description='批量修改项目关键词',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  # 修改中英文关键词
  python3 %(prog)s -c 梦想云 地平线 -e mxycloud horizon
  
  # 只修改中文
  python3 %(prog)s -c 梦想云 地平线
  
  # 只修改英文
  python3 %(prog)s -e mxycloud horizon
  
  # 测试模式（不实际修改）
  python3 %(prog)s -c 梦想云 地平线 -e mxycloud horizon --dry-run
  
  # 指定文件列表
  python3 %(prog)s -c 梦想云 地平线 -e mxycloud horizon -f setup.dart config.json
        '''
    )
    
    parser.add_argument(
        '-c', '--chinese',
        nargs=2,
        metavar=('OLD', 'NEW'),
        help='中文关键词: 旧值 新值'
    )
    parser.add_argument(
        '-e', '--english',
        nargs=2,
        metavar=('OLD', 'NEW'),
        help='英文关键词: 旧值 新值'
    )
    parser.add_argument(
        '-f', '--files',
        nargs='+',
        help='指定要修改的文件列表（相对路径）'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='测试模式，显示要修改的内容但不实际修改'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='显示默认文件列表'
    )
    
    args = parser.parse_args()
    
    # 显示默认文件列表
    if args.list:
        print("默认文件列表:")
        for i, f in enumerate(DEFAULT_FILES, 1):
            print(f"  {i}. {f}")
        return 0
    
    # 检查至少有一个替换参数
    if not args.chinese and not args.english:
        parser.print_help()
        sys.exit(1)
    
    # 构建替换列表
    replacements = []
    if args.chinese:
        replacements.append((args.chinese[0], args.chinese[1]))
    if args.english:
        replacements.append((args.english[0], args.english[1]))
    
    # 确定要处理的文件
    files_to_process = args.files if args.files else DEFAULT_FILES
    
    print("=" * 60)
    print("批量修改关键词")
    print("=" * 60)
    
    if args.dry_run:
        print("⚠️  测试模式 - 不会实际修改文件")
    
    print("\n替换规则:")
    for old, new in replacements:
        print(f"  {old} → {new}")
    
    print(f"\n要处理的文件数: {len(files_to_process)}")
    
    print("\n处理中...\n")
    
    total_files_modified = 0
    total_replacements = 0
    
    for file_path in files_to_process:
        if not os.path.exists(file_path):
            print(f"⚠️  文件不存在: {file_path}")
            continue
        
        success, count = replace_in_file(file_path, replacements, args.dry_run)
        
        if success:
            if count > 0:
                mode = "[模拟]" if args.dry_run else ""
                print(f"✓ {mode} {file_path} ({count} 处修改)")
                total_files_modified += 1
                total_replacements += count
            else:
                print(f"- {file_path} (无需修改)")
        else:
            print(f"✗ {file_path} (处理失败)")
    
    print("\n" + "=" * 60)
    print(f"修改完成!")
    print(f"  总文件数: {total_files_modified}")
    print(f"  总替换数: {total_replacements}")
    
    if args.dry_run:
        print("\n💡 提示: 这是测试模式，没有实际修改文件")
        print("   移除 --dry-run 参数来执行实际修改")
    
    print("=" * 60)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
