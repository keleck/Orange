#!/usr/bin/env python3
"""批量更新所有页面的背景颜色"""

import re
from pathlib import Path

# 文件列表
files = [
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

def update_file(filepath):
    """更新单个文件"""
    path = Path(filepath)
    if not path.exists():
        print(f"❌ 文件不存在: {filepath}")
        return False
    
    content = path.read_text(encoding='utf-8')
    original = content
    
    # 1. 添加 import（如果需要）
    if 'app_colors.dart' not in content and 'AppColors' not in content:
        # 找到最后一个 import
        import_pattern = r"(import\s+['\"].*?['\"];?\n)"
        imports = list(re.finditer(import_pattern, content))
        if imports:
            last_import_end = imports[-1].end()
            content = (content[:last_import_end] + 
                      "import 'package:fl_clash/widgets/app_colors.dart';\n" +
                      content[last_import_end:])
    
    # 2. 替换渐变背景 - 匹配多种格式
    patterns = [
        # 格式1: const BoxDecoration
        (r'const\s+BoxDecoration\(\s*gradient:\s*LinearGradient\(\s*'
         r'begin:\s*Alignment\.topLeft,\s*'
         r'end:\s*Alignment\.bottomRight,\s*'
         r'colors:\s*\[\s*'
         r'Color\(0xFF1A0F2E\),?\s*//[^\n]*\n\s*'
         r'Color\(0xFF0F1419\),?\s*//[^\n]*\n\s*'
         r'Color\(0xFF0A1628\),?\s*//[^\n]*\n\s*'
         r'Color\(0xFF0D1B2A\),?\s*//[^\n]*\n\s*'
         r'\],\s*'
         r'stops:\s*\[0\.0,\s*0\.3,\s*0\.7,\s*1\.0\],?\s*'
         r'\),?\s*\)',
         'AppColors.getBackgroundDecoration()'),
        
        # 格式2: BoxDecoration (without const)
        (r'BoxDecoration\(\s*gradient:\s*LinearGradient\(\s*'
         r'begin:\s*Alignment\.topLeft,\s*'
         r'end:\s*Alignment\.bottomRight,\s*'
         r'colors:\s*\[\s*'
         r'Color\(0xFF1A0F2E\),?\s*//[^\n]*\n\s*'
         r'Color\(0xFF0F1419\),?\s*//[^\n]*\n\s*'
         r'Color\(0xFF0A1628\),?\s*//[^\n]*\n\s*'
         r'Color\(0xFF0D1B2A\),?\s*//[^\n]*\n\s*'
         r'\],\s*'
         r'stops:\s*\[0\.0,\s*0\.3,\s*0\.7,\s*1\.0\],?\s*'
         r'\),?\s*\)',
         'AppColors.getBackgroundDecoration()'),
    ]
    
    count = 0
    for pattern, replacement in patterns:
        content, n = re.subn(pattern, replacement, content, flags=re.MULTILINE)
        count += n
    
    if content != original:
        path.write_text(content, encoding='utf-8')
        print(f"✅ 已更新: {filepath} (替换了 {count} 处)")
        return True
    else:
        print(f"ℹ️  无需更新: {filepath}")
        return False

def main():
    print("=" * 70)
    print("开始批量更新背景颜色")
    print("=" * 70)
    
    updated = 0
    for filepath in files:
        if update_file(filepath):
            updated += 1
    
    print("=" * 70)
    print(f"完成！成功更新 {updated}/{len(files)} 个文件")
    print("=" * 70)

if __name__ == '__main__':
    main()
