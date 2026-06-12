import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';

class PlanDescriptionWidget extends StatelessWidget {
  final String content;
  const PlanDescriptionWidget({
    super.key,
    required this.content,
  });
  
  /// 检查内容是否为HTML格式
  bool _isHtmlContent(String content) {
    return content.contains(RegExp(r'<[^>]+>', multiLine: true));
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final isHtml = _isHtmlContent(content);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: isHtml
          ? Html(
              data: content,
              style: {
                'body': Style(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: FontSize(14),
                  lineHeight: LineHeight(1.5),
                ),
                'p': Style(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: FontSize(14),
                  lineHeight: LineHeight(1.5),
                  margin: Margins.symmetric(vertical: 8),
                ),
                'h1': Style(
                  color: colorScheme.onSurface,
                  fontSize: FontSize(20),
                  fontWeight: FontWeight.bold,
                ),
                'h2': Style(
                  color: colorScheme.onSurface,
                  fontSize: FontSize(18),
                  fontWeight: FontWeight.bold,
                ),
                'h3': Style(
                  color: colorScheme.onSurface,
                  fontSize: FontSize(16),
                  fontWeight: FontWeight.bold,
                ),
                'strong': Style(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                'em': Style(
                  fontStyle: FontStyle.italic,
                ),
                'li': Style(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: FontSize(14),
                  margin: Margins.symmetric(vertical: 4),
                ),
                'ul': Style(
                  margin: Margins.symmetric(vertical: 8),
                ),
                'ol': Style(
                  margin: Margins.symmetric(vertical: 8),
                ),
              },
            )
          : MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: WrapAlignment.center,
              ),
            ),
    );
  }
}
