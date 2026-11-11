import 'dart:ui';

import 'package:fl_clash/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK, NoticeModel;

/// 首页右上角铃铛点击后弹出的「系统公告」浮层。
///
/// 与整页的公告列表页（notice_list_page.dart）不同，这里是一个贴着铃铛下方的卡片式浮层：
/// 顶部「系统公告」标题，下面是公告条目列表，点击条目再看详情。
Future<void> showNoticePopup(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '系统公告',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => const _NoticePopupPanel(),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _NoticePopupPanel extends StatefulWidget {
  const _NoticePopupPanel();

  @override
  State<_NoticePopupPanel> createState() => _NoticePopupPanelState();
}

class _NoticePopupPanelState extends State<_NoticePopupPanel> {
  List<NoticeModel> _notices = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notices = await XBoardSDK.instance.notice.getNotices();
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = (media.size.width - 48).clamp(280.0, 420.0);
    final maxHeight = media.size.height * 0.62;
    final panelGradient = _panelGradient(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: media.padding.top + 62),
        child: SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  decoration: BoxDecoration(
                    gradient: panelGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const _PanelDivider(),
                      Flexible(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 与页面背景同一套色系（AppColors 深紫/深紫黑），
  /// 只用主题色轻轻提亮一层，保证浮层既融入主题又能和底下的内容区分开。
  LinearGradient _panelGradient(BuildContext context) =>
      noticePanelGradient(context);

  Widget _buildHeader() {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 12, 13),
      child: Row(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 19,
            color: primary,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              '系统公告',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          InkResponse(
            onTap: () => Navigator.of(context).maybePop(),
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '公告加载失败',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _load();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_notices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 30,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10),
            Text(
              '暂无公告',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _notices.length,
      separatorBuilder: (_, __) => const _PanelDivider(indent: 18, endIndent: 18),
      itemBuilder: (context, index) {
        return _NoticeRow(
          notice: _notices[index],
          onTap: () => _openDetail(_notices[index]),
        );
      },
    );
  }

  void _openDetail(NoticeModel notice) {
    showNoticeDetailDialog(context, notice);
  }
}

class _NoticeRow extends StatelessWidget {
  final NoticeModel notice;
  final VoidCallback onTap;

  const _NoticeRow({
    required this.notice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = _isUnread(notice);
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 10, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnread
                      ? primary.withValues(alpha: 0.9)
                      : Colors.transparent,
                  border: Border.all(
                    color: isUnread
                        ? primary
                        : Colors.white.withValues(alpha: 0.35),
                    width: 1.3,
                  ),
                ),
                child: isUnread
                    ? const Center(
                        child: SizedBox(
                          width: 4,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.3,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _plainText(notice.content),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.5),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatDate(notice.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.32),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const _PanelDivider({this.indent = 0, this.endIndent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}

/// 标签里带「弹窗」的公告视为需要主动弹出提醒的未读公告
bool _isUnread(NoticeModel notice) {
  final tags = notice.tags;
  if (tags == null || tags.isEmpty) return false;
  return tags.any(
    (tag) =>
        tag.toLowerCase().contains('弹窗') ||
        tag.toLowerCase().contains('popup'),
  );
}

/// 公告正文是后台富文本编辑器写的，经常整段夹带内联颜色（黄、金）、
/// 下划线和 `border-bottom` 之类的装饰，直接渲染会「一屏黄线」。
///
/// 这里做白名单式清理：只保留尺寸/对齐/字重这类不影响颜色的声明，
/// 颜色、背景、边框、下划线一律丢掉，并去掉 `<u>`/`<mark>`/`<font>` 这些
/// 自带装饰的标签（保留其中的文字），最终颜色完全由 style 参数决定。
String _sanitizeNoticeHtml(String html) {
  var result = html;

  // 先把图片占位保护起来，避免下面剥标签时被删掉
  final images = <String>[];
  result = result.replaceAllMapped(
    RegExp(r'<img\b[^>]*>', caseSensitive: false),
    (match) {
      images.add(match.group(0)!);
      return '[[NOTICE_IMG_${images.length - 1}]]';
    },
  );

  // 内联 style 走白名单，其余（color/background/border/text-decoration…）全部丢弃
  const keepKeys = {
    'width',
    'height',
    'max-width',
    'text-align',
    'font-weight',
    'font-style',
    'font-size',
  };
  result = result.replaceAllMapped(
    RegExp(r'''style\s*=\s*["']([^"']*)["']''', caseSensitive: false),
    (match) {
      final kept = <String>[];
      for (final declaration in match.group(1)!.split(';')) {
        final index = declaration.indexOf(':');
        if (index <= 0) continue;
        final key = declaration.substring(0, index).trim().toLowerCase();
        final value = declaration.substring(index + 1).trim();
        if (value.isEmpty) continue;
        if (keepKeys.contains(key)) {
          kept.add('$key:$value');
        }
      }
      return kept.isEmpty ? '' : 'style="${kept.join(';')}"';
    },
  );

  // 只保留结构性标签；<u>/<font>/<span>/<mark>/<a> 等带样式的标签一律剥掉只留文字
  const keepTags = {
    'p',
    'div',
    'br',
    'strong',
    'b',
    'li',
    'ul',
    'ol',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };
  result = result.replaceAllMapped(
    RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>'),
    (match) {
      final isClosing = match.group(1) == '/';
      final tag = match.group(2)!.toLowerCase();
      if (!keepTags.contains(tag)) return '';
      if (tag == 'br') return '<br>';
      return isClosing ? '</$tag>' : '<$tag>';
    },
  );

  // 还原图片，并限制宽度避免撑破弹窗
  for (var i = 0; i < images.length; i++) {
    final image = images[i]
        .replaceAll(RegExp(r'''style\s*=\s*["'][^"']*["']'''), '')
        .replaceFirst('<img', '<img style="max-width:100%"');
    result = result.replaceAll('[[NOTICE_IMG_$i]]', image);
  }

  return result;
}

/// 把公告 HTML 内容压成一行纯文本，用于列表里的摘要
String _plainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

String _formatDate(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) {
    if (difference.inHours == 0) {
      if (difference.inMinutes <= 0) return '刚刚';
      return '${difference.inMinutes}分钟前';
    }
    return '${difference.inHours}小时前';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}天前';
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 公告类卡片统一使用的渐变：以 AppColors 主题底色为基准，
/// 用主题色轻轻提亮一层，浮层和详情弹窗都走这一套，保证观感一致。
LinearGradient noticePanelGradient(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.alphaBlend(
        primary.withValues(alpha: 0.10),
        AppColors.gradientColor1,
      ),
      Color.alphaBlend(
        primary.withValues(alpha: 0.05),
        AppColors.gradientColor2,
      ),
      Color.alphaBlend(
        primary.withValues(alpha: 0.08),
        AppColors.gradientColor4,
      ),
    ],
  );
}

/// 公告详情弹窗（浮层点条目、首页自动弹窗都复用这一套 UI）。
///
/// [dismissible] 为 false 时点遮罩不会关闭，底部会显示「下一条 / 关闭」按钮，
/// 用于启动时依次推送的弹窗公告。
Future<void> showNoticeDetailDialog(
  BuildContext context,
  NoticeModel notice, {
  bool dismissible = true,
  VoidCallback? onNext,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  final showFooter = !dismissible || onNext != null;

  return showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) {
      final media = MediaQuery.of(dialogContext);
      return Center(
        child: Container(
          width: (media.size.width - 56).clamp(280.0, 400.0),
          constraints: BoxConstraints(maxHeight: media.size.height * 0.72),
          decoration: BoxDecoration(
            gradient: noticePanelGradient(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 10, 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _PanelDivider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(notice.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.38),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 兜底：即使 HTML 里残留了装饰样式，也强制不带下划线
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          decoration: TextDecoration.none,
                        ),
                        child: Html(
                          data: _sanitizeNoticeHtml(notice.content),
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(13.5),
                              lineHeight: const LineHeight(1.7),
                              color: Colors.white.withValues(alpha: 0.86),
                              textDecoration: TextDecoration.none,
                            ),
                            'p': Style(
                              margin: Margins(
                                top: Margin.zero(),
                                bottom: Margin(10),
                              ),
                              padding: HtmlPaddings.zero,
                            ),
                            'div': Style(
                              margin: Margins(
                                top: Margin.zero(),
                                bottom: Margin(6),
                              ),
                            ),
                            'a': Style(
                              color: primary,
                              textDecoration: TextDecoration.none,
                            ),
                            'u': Style(
                              textDecoration: TextDecoration.none,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            'strong': Style(color: Colors.white),
                            'b': Style(color: Colors.white),
                            'mark': Style(
                              backgroundColor: Colors.transparent,
                              color: Colors.white,
                              textDecoration: TextDecoration.none,
                            ),
                            'li': Style(
                              margin: Margins(
                                top: Margin.zero(),
                                bottom: Margin(4),
                              ),
                            ),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showFooter) ...[
                const _PanelDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onNext != null) ...[
                        _NoticeDialogButton(
                          label: '下一条',
                          filled: false,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onNext();
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                      _NoticeDialogButton(
                        label: '关闭',
                        filled: true,
                        onTap: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _NoticeDialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _NoticeDialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.75),
                  ],
                )
              : null,
          color: filled ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.85),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
