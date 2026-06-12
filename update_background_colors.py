#!/usr/bin/env python3
"""
统一更新所有页面的背景颜色
将硬编码的渐变颜色替换为使用 AppColors 统一配置
"""

import os
import re
from pathlib import Path

# 需要更新的文件列表
files_to_update = [
    'lib/widgets/scaffold.dart',
    'lib/xboard/router/routes.dart',
    'lib/xboard/features/user/pages/settings_page.dart',
    'lib/xboard/features/invite/pages/invite_page.dart',
    'lib/xboard/features/user/pages/wallet_page.dart',
    'lib/xboard/features/user/pages/user_center_page.dart',
    'lib/xboard/features/notice/pages/notice_list_page.dart',
    'lib/xboard/features/subscription/pages/xboard_home_page.dart',
    'lib/xboard/features/shared/pages/node_selector_page.dart',
    'lib/xboard/features/payment/pages/plan_purchase_page.dart',
    'lib/xboard/features/payment/pages/plans.dart',
    'lib/xboard/features/auth/pages/forgot_password_page.dart',
    'lib/xboard/features/auth/pages/login_page.dart',
    'lib/xboard/features/auth/pages/register_page.dart',
    'lib/xboard/features/ticket/pages/tickets_page.dart',
    'lib/xboard/features/ticket/pages/create_ticket_page.dart',
    'lib/xboard/features/traffic/pages/traffic_log_page.dart',
    'lib/xboard/features/order/pages/order_page.dart',
]

# 硬编码的渐变颜色模式
gradient_pattern = re.compile(
    r'gradient:\s*LinearGradient\(\s*'
    r'begin:\s*Alignment\.topLeft,\s*'
    r'end:\s*Alignment\.bottomRight,\s*'
    r'colors:\s*\[\s*'
    r'(?:const\s+)?Color\(0xFF1A0F2E\),?\s*//[^\n]*\n\s*'
    r'(?:const\s+)?Color\(0xFF0F1419\),?\s*//[^\n]*\n\s*'
    r'(?:const\s+)?Color\(0xFF0A1628\),?\s*//[^\n]*\n\s*'
    r'(?:const\s+)?Color\(0xFF0D1B2A\),?\s*//[^\n]*\n\s*'
    r'\],\s*'
    r'stops:\s*(?:const\s+)?\[0\.0,\s*0\.3,\s*0\.7,\s*1\.0\],?\s*'
    r'\)',
    re.MULTILINE
)

# 替换文本
replacement = 'gradient: AppColors.getBackgroundGradient()'

def needs_import(content):
    """检查文件是否需要添加 import"""
    return "import 'package:fl_clash/widgets/app_colors.dart';" not in content and \
           "import '../../../widgets/app_colors.dart';" not in content and \
           "AppColors" not in content

def add_import(content, file_path):
    """添加 AppColors 的 import 语句"""
    # 计算相对路径深度
    depth = file_path.count('/') - 1  # lib/ 不算
    if 'xboard' in file_path:
        depth = file_path.split('xboard/')[1].count('/') + 1
    
    # 构建相对路径
    relative_path = '../' * depth + 'widgets/app_colors.dart'
    import_statement = f"import '{relative_path}';\n"
    
    # 在最后一个 import 后添加
    import_pattern = re.compile(r"(import\s+['\"].*?['\"];?\n)")
    imports = list(import_pattern.finditer(content))
    
    if imports:
        last_import = imports[-1]
        insert_pos = last_import.end()
        content = content[:insert_pos] + import_statement + content[insert_pos:]
    else:
        # 如果没有找到 import，在文件开头添加
        content = import_statement + content
    
    return content

def update_file(file_path):
    """更新单个文件"""
    full_path = Path(file_path)
    
    if not full_path.exists():
        print(f"⚠️  文件不存在: {file_path}")
        return False
    
    try:
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # 替换渐变颜色
        content, count = gradient_pattern.subn(replacement, content)
        
        if count > 0:
            # 添加 import（如果需要）
            if needs_import(content):
                content = add_import(content, file_path)
            
            # 写回文件
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"✅ 已更新: {file_path} (替换了 {count} 处)")
            return True
        else:
            print(f"ℹ️  无需更新: {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ 更新失败: {file_path}")
        print(f"   错误: {str(e)}")
        return False

def main():
    """主函数"""
    print("=" * 60)
    print("开始统一更新所有页面的背景颜色")
    print("=" * 60)
    print()
    
    updated_count = 0
    failed_count = 0
    
    for file_path in files_to_update:
        if update_file(file_path):
            updated_count += 1
        else:
            if not Path(file_path).exists():
                failed_count += 1
    
    print()
    print("=" * 60)
    print(f"更新完成！")
    print(f"成功更新: {updated_count} 个文件")
    if failed_count > 0:
        print(f"失败/不存在: {failed_count} 个文件")
    print("=" * 60)

if __name__ == '__main__':
    main()
