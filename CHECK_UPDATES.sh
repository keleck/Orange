#!/bin/bash

echo "======================================"
echo "通知公告颜色更新 - 验证脚本"
echo "======================================"
echo ""

echo "✅ 检查修改的文件..."
echo ""

files=(
  "lib/xboard/features/shared/widgets/notice_banner.dart"
  "lib/xboard/features/notice/pages/notice_list_page.dart"
  "lib/xboard/features/subscription/pages/xboard_home_page.dart"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    count=$(grep -c "Color(0xFF2A1F3E)" "$file")
    if [ $count -gt 0 ]; then
      echo "✅ $file - 已更新 (找到 $count 处新颜色)"
    else
      echo "❌ $file - 未更新"
    fi
  else
    echo "❌ $file - 文件不存在"
  fi
done

echo ""
echo "======================================"
echo "检查完成！"
echo "======================================"
echo ""
echo "如果所有文件都显示 ✅，请重启应用查看效果："
echo ""
echo "  方法1: 在运行的应用终端按 Shift+R (热重启)"
echo "  方法2: flutter run (完全重新运行)"
echo "  方法3: flutter clean && flutter run (清理后运行)"
echo ""
