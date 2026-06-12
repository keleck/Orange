#!/usr/bin/env python3
"""
批量修改项目版本号的脚本
支持 Flutter、Android、iOS 等多个平台的版本号更新
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import Tuple, List


class VersionUpdater:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.changes = []

    def update_pubspec(self, version: str) -> bool:
        """更新 pubspec.yaml 中的版本号"""
        pubspec_file = self.project_root / "pubspec.yaml"
        
        if not pubspec_file.exists():
            print(f"❌ 找不到 {pubspec_file}")
            return False
        
        with open(pubspec_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 更新 version: X.Y.Z+BuildNumber
        old_version = re.search(r'^version:\s*([\d.+]+)', content, re.MULTILINE)
        if old_version:
            old_ver = old_version.group(1)
            # 保留 build number 部分 (+ 后面的部分)
            if '+' in old_ver:
                build_num = old_ver.split('+')[1]
                new_version_str = f"{version}+{build_num}"
            else:
                new_version_str = version
            
            new_content = re.sub(
                r'^version:\s*[\d.+]+',
                f'version: {new_version_str}',
                content,
                flags=re.MULTILINE
            )
            
            with open(pubspec_file, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            self.changes.append(f"✅ 更新 pubspec.yaml: {old_ver} -> {new_version_str}")
            return True
        else:
            print(f"⚠️  无法找到 pubspec.yaml 中的 version")
            return False

    def update_android_version_code(self, version_code: int) -> bool:
        """更新 Android 版本号 (versionCode)"""
        # Android 通常从 pubspec.yaml 读取版本信息
        # 但如果需要直接修改，可以在这里实现
        print(f"💡 Android versionCode 由 Flutter 自动生成，无需手动修改")
        return True

    def update_ios_plist(self, version: str) -> bool:
        """更新 iOS Info.plist 中的版本号"""
        ios_dir = self.project_root / "ios"
        
        # 查找 Info.plist 文件
        plist_files = list(ios_dir.rglob("Info.plist"))
        
        if not plist_files:
            print(f"⚠️  找不到 iOS Info.plist 文件")
            return False
        
        for plist_file in plist_files:
            with open(plist_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 更新 CFBundleShortVersionString
            if 'CFBundleShortVersionString' in content:
                # 简单的字符串替换 (假设 plist 是 XML 格式)
                old_version = re.search(
                    r'<key>CFBundleShortVersionString</key>\s*<string>([\d.]+)</string>',
                    content
                )
                if old_version:
                    old_ver = old_version.group(1)
                    new_content = re.sub(
                        r'(<key>CFBundleShortVersionString</key>\s*<string>)[\d.]+(<\/string>)',
                        f'\\1{version}\\2',
                        content
                    )
                    
                    with open(plist_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    
                    self.changes.append(f"✅ 更新 {plist_file.relative_to(self.project_root)}: {old_ver} -> {version}")
        
        return True

    def update_macos_plist(self, version: str) -> bool:
        """更新 macOS Info.plist 中的版本号"""
        macos_dir = self.project_root / "macos"
        
        # 查找 Info.plist 文件
        plist_files = list(macos_dir.rglob("Info.plist"))
        
        if not plist_files:
            return True  # 可能没有 macOS 支持
        
        for plist_file in plist_files:
            with open(plist_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'CFBundleShortVersionString' in content:
                old_version = re.search(
                    r'<key>CFBundleShortVersionString</key>\s*<string>([\d.]+)</string>',
                    content
                )
                if old_version:
                    old_ver = old_version.group(1)
                    new_content = re.sub(
                        r'(<key>CFBundleShortVersionString</key>\s*<string>)[\d.]+(<\/string>)',
                        f'\\1{version}\\2',
                        content
                    )
                    
                    with open(plist_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    
                    self.changes.append(f"✅ 更新 {plist_file.relative_to(self.project_root)}: {old_ver} -> {version}")
        
        return True

    def update_windows_rc(self, version: str) -> bool:
        """更新 Windows .rc 文件中的版本号"""
        windows_dir = self.project_root / "windows"
        rc_files = list(windows_dir.rglob("*.rc"))
        
        if not rc_files:
            return True  # 可能没有 Windows 支持
        
        # 解析版本为 major, minor, patch, build
        version_parts = version.split('.')
        if len(version_parts) < 3:
            print(f"⚠️  版本号格式不支持 Windows (.rc): {version}")
            return False
        
        # Windows 版本格式: major,minor,patch,build
        windows_version = ','.join(version_parts[:4])
        
        for rc_file in rc_files:
            with open(rc_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 更新 FILEVERSION 和 PRODUCTVERSION
            old_version = re.search(r'FILEVERSION\s+([\d,]+)', content)
            if old_version:
                old_ver = old_version.group(1)
                new_content = re.sub(
                    r'FILEVERSION\s+[\d,]+',
                    f'FILEVERSION {windows_version}',
                    content
                )
                new_content = re.sub(
                    r'PRODUCTVERSION\s+[\d,]+',
                    f'PRODUCTVERSION {windows_version}',
                    new_content
                )
                
                with open(rc_file, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                
                self.changes.append(f"✅ 更新 {rc_file.relative_to(self.project_root)}: {old_ver} -> {windows_version}")
        
        return True

    def update_linux_appdata(self, version: str) -> bool:
        """更新 Linux appdata.xml 中的版本号"""
        linux_dir = self.project_root / "linux"
        
        # 查找 AppData 文件
        appdata_files = list(linux_dir.rglob("*.appdata.xml"))
        
        if not appdata_files:
            return True  # 可能没有 Linux 支持
        
        for appdata_file in appdata_files:
            with open(appdata_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if '<release' in content:
                # 添加新的版本 release 标签
                release_pattern = r'(<release[^>]*>[\s\S]*?</release>)'
                match = re.search(release_pattern, content)
                
                if match:
                    print(f"💡 Linux appdata.xml 需要手动添加 release 标签: {version}")
        
        return True

    def update_all(self, version: str) -> bool:
        """更新所有支持的平台的版本号"""
        print(f"\n🚀 开始更新版本号到: {version}\n")
        
        success = True
        success &= self.update_pubspec(version)
        success &= self.update_android_version_code(int(version.replace('.', '')))
        success &= self.update_ios_plist(version)
        success &= self.update_macos_plist(version)
        success &= self.update_windows_rc(version)
        success &= self.update_linux_appdata(version)
        
        return success

    def print_summary(self):
        """打印变更总结"""
        print("\n" + "="*60)
        print("📋 变更总结:")
        print("="*60)
        for change in self.changes:
            print(change)
        print("="*60 + "\n")


def parse_version(version_str: str) -> Tuple[str, bool]:
    """解析和验证版本号格式"""
    # 支持格式: 1.2.3 或 1.2.3+123
    pattern = r'^(\d+\.\d+\.\d+)(\+\d+)?$'
    match = re.match(pattern, version_str)
    
    if not match:
        return None, False
    
    return version_str, True


def main():
    parser = argparse.ArgumentParser(
        description='批量修改项目版本号',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 更新版本号为 2.7.0
  python3 update_version.py 2.7.0
  
  # 更新版本号为 2.7.0+2025091201
  python3 update_version.py 2.7.0+2025091201
  
  # 指定项目根目录
  python3 update_version.py -p /path/to/project 2.7.0
        """
    )
    
    parser.add_argument('version', help='新的版本号 (格式: X.Y.Z 或 X.Y.Z+Build)')
    parser.add_argument('-p', '--path', default='.', help='项目根目录 (默认: 当前目录)')
    
    args = parser.parse_args()
    
    # 验证版本号格式
    version, is_valid = parse_version(args.version)
    if not is_valid:
        print(f"❌ 版本号格式错误: {args.version}")
        print("   支持的格式: X.Y.Z 或 X.Y.Z+BuildNumber")
        sys.exit(1)
    
    # 检查项目目录
    project_root = Path(args.path).resolve()
    if not project_root.exists():
        print(f"❌ 项目目录不存在: {project_root}")
        sys.exit(1)
    
    if not (project_root / "pubspec.yaml").exists():
        print(f"❌ 找不到 pubspec.yaml，请确认项目根目录正确")
        sys.exit(1)
    
    # 创建更新器并执行更新
    updater = VersionUpdater(str(project_root))
    success = updater.update_all(version)
    updater.print_summary()
    
    if not success:
        sys.exit(1)
    
    print("✨ 版本号更新完成!")


if __name__ == "__main__":
    main()
