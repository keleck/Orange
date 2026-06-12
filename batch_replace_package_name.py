#!/usr/bin/env python3
"""
批量修改包名脚本
将 com.follow.DreamCloud 修改为 com.follow.horizon

使用方法:
    python3 batch_replace_package_name.py
    python3 batch_replace_package_name.py --dry-run
    python3 batch_replace_package_name.py -o "com.follow.DreamCloud" -n "com.follow.horizon"
"""

import os
import sys
import argparse
from pathlib import Path
from typing import List, Tuple


class PackageNameReplacer:
    """包名批量替换工具"""
    
    # 默认需要修改的文件和目录
    DEFAULT_FILES = [
        "lib/common/constant.dart",
        "linux/CMakeLists.txt",
        "android/app/build.gradle.kts",
        "android/app/src/main/AndroidManifest.xml",
    ]
    
    # 需要递归搜索的目录
    DEFAULT_DIRS = [
        "android/app/src/main/kotlin",
    ]
    
    def __init__(self, old_name: str, new_name: str, dry_run: bool = False):
        """
        初始化替换工具
        
        Args:
            old_name: 旧包名
            new_name: 新包名
            dry_run: 是否为测试模式
        """
        self.old_name = old_name
        self.new_name = new_name
        self.dry_run = dry_run
        self.total_files_modified = 0
        self.total_replacements = 0
        self.processed_files = []
    
    def replace_in_file(self, file_path: str) -> Tuple[int, bool]:
        """
        在单个文件中进行替换
        
        Args:
            file_path: 文件路径
            
        Returns:
            (替换次数, 成功与否)
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 计算替换次数
            count = content.count(self.old_name)
            
            if count > 0:
                content = content.replace(self.old_name, self.new_name)
                
                if not self.dry_run:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                
                return count, True
            
            return 0, True
        
        except Exception as e:
            print(f"  ✗ 错误: {e}", file=sys.stderr)
            return 0, False
    
    def process_file(self, file_path: str) -> bool:
        """处理单个文件"""
        if not os.path.exists(file_path):
            print(f"⚠️  文件不存在: {file_path}")
            return False
        
        count, success = self.replace_in_file(file_path)
        
        if success:
            if count > 0:
                mode = "[模拟]" if self.dry_run else ""
                print(f"✓ {mode} {file_path} ({count} 处修改)")
                self.total_files_modified += 1
                self.total_replacements += count
                self.processed_files.append((file_path, count))
            else:
                print(f"- {file_path} (无需修改)")
            return True
        else:
            print(f"✗ {file_path} (处理失败)")
            return False
    
    def process_directory(self, dir_path: str, extensions: List[str] = None) -> None:
        """
        递归处理目录中的文件
        
        Args:
            dir_path: 目录路径
            extensions: 文件扩展名列表（如 ['.kt', '.java']）
        """
        if not os.path.exists(dir_path):
            print(f"⚠️  目录不存在: {dir_path}")
            return
        
        if extensions is None:
            extensions = ['.kt', '.java', '.dart', '.gradle', '.xml', '.txt', '.kts']
        
        for root, dirs, files in os.walk(dir_path):
            for file in files:
                file_path = os.path.join(root, file)
                
                # 检查文件扩展名
                if any(file.endswith(ext) for ext in extensions):
                    self.process_file(file_path)
    
    def run(self, files: List[str] = None, dirs: List[str] = None) -> int:
        """
        执行替换
        
        Args:
            files: 要处理的文件列表
            dirs: 要处理的目录列表
            
        Returns:
            返回码
        """
        if files is None:
            files = self.DEFAULT_FILES
        if dirs is None:
            dirs = self.DEFAULT_DIRS
        
        print("=" * 70)
        print("批量修改包名")
        print("=" * 70)
        
        if self.dry_run:
            print("⚠️  测试模式 - 不会实际修改文件")
        
        print(f"\n替换规则:")
        print(f"  {self.old_name}")
        print(f"        ↓")
        print(f"  {self.new_name}")
        
        print(f"\n处理文件...")
        
        # 处理指定的文件
        for file_path in files:
            self.process_file(file_path)
        
        # 处理指定的目录
        print(f"\n扫描目录...")
        for dir_path in dirs:
            self.process_directory(dir_path)
        
        # 打印统计信息
        print("\n" + "=" * 70)
        print("处理完成!")
        print(f"  处理文件数: {self.total_files_modified}")
        print(f"  总替换数: {self.total_replacements}")
        
        if self.total_files_modified > 0:
            print("\n详细信息:")
            for file_path, count in self.processed_files:
                print(f"  - {file_path}: {count} 处")
        
        if self.dry_run:
            print("\n💡 提示: 这是测试模式，没有实际修改文件")
            print("   移除 --dry-run 参数来执行实际修改")
        
        print("=" * 70)
        
        return 0 if self.total_replacements > 0 else 1


def main():
    parser = argparse.ArgumentParser(
        description='批量修改包名',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  # 默认替换 com.follow.DreamCloud → com.follow.horizon
  python3 %(prog)s
  
  # 测试模式（不实际修改）
  python3 %(prog)s --dry-run
  
  # 自定义包名替换
  python3 %(prog)s -o "com.old.package" -n "com.new.package"
  
  # 指定文件
  python3 %(prog)s -f file1.kt file2.kt file3.xml
  
  # 指定目录
  python3 %(prog)s -d src/ android/
  
  # 结合文件和目录
  python3 %(prog)s -f setup.dart config.json -d android/app/src/
        '''
    )
    
    parser.add_argument(
        '-o', '--old',
        default='com.follow.DreamCloud',
        help='旧包名 (默认: com.follow.DreamCloud)'
    )
    parser.add_argument(
        '-n', '--new',
        default='com.follow.horizon',
        help='新包名 (默认: com.follow.horizon)'
    )
    parser.add_argument(
        '-f', '--files',
        nargs='+',
        help='指定要修改的文件列表'
    )
    parser.add_argument(
        '-d', '--dirs',
        nargs='+',
        help='指定要扫描的目录列表'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='测试模式，显示要修改的内容但不实际修改'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='显示默认文件和目录列表'
    )
    
    args = parser.parse_args()
    
    # 显示默认列表
    if args.list:
        print("默认文件列表:")
        for i, f in enumerate(PackageNameReplacer.DEFAULT_FILES, 1):
            print(f"  {i}. {f}")
        
        print("\n默认目录列表:")
        for i, d in enumerate(PackageNameReplacer.DEFAULT_DIRS, 1):
            print(f"  {i}. {d}")
        return 0
    
    # 创建替换工具
    replacer = PackageNameReplacer(
        old_name=args.old,
        new_name=args.new,
        dry_run=args.dry_run
    )
    
    # 确定要处理的文件和目录
    files = args.files if args.files else None
    dirs = args.dirs if args.dirs else None
    
    # 执行替换
    return replacer.run(files=files, dirs=dirs)


if __name__ == '__main__':
    sys.exit(main())
