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
  LinearGradient _panelGradient(BuildContext context) {
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
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        return Center(
          child: Container(
            width: (media.size.width - 56).clamp(280.0, 400.0),
            constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
            decoration: BoxDecoration(
              gradient: _panelGradient(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDate(notice.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Html(
                          data: _sanitizeNoticeHtml(notice.content),
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(13.5),
                              lineHeight: const LineHeight(1.7),
                              color: Colors.white.withValues(alpha: 0.86),
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
                            // 公告正文里大量 <u>/<font> 强调，统一成浅白下划线，
                            // 不再沿用内容里内联的黄色等花哨颜色
                            'u': Style(
                              color: Colors.white.withValues(alpha: 0.9),
                              textDecorationColor:
                                  Colors.white.withValues(alpha: 0.45),
                            ),
                            'strong': Style(color: Colors.white),
                            'b': Style(color: Colors.white),
                            'mark': Style(
                              backgroundColor: Colors.transparent,
                              color: Colors.white,
                            ),
                            'li': Style(
                              margin: Margins(
                                top: Margin.zero(),
                                bottom: Margin(4),
                              ),
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatDate(notice.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.32),
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

/// 公告正文是后台富文本编辑器写的，经常夹带内联颜色（黄、金等）和 `<font color>`，
/// 直接渲染会显得很花。这里统一剥掉颜色/背景/文字装饰相关的内联样式，
/// 让文字颜色完全由上面 style 里的主题色决定。
String _sanitizeNoticeHtml(String html) {
  var result = html;

  // <font ...> 只保留内容，丢掉 color/face/size 属性
  result = result.replaceAll(
    RegExp(r'<font\b[^>]*>', caseSensitive: false),
    '<span>',
  );
  result = result.replaceAll(
    RegExp(r'</font\s*>', caseSensitive: false),
    '</span>',
  );

  // 剥掉内联 style 中的颜色、背景、文字装饰声明
  result = result.replaceAllMapped(
    RegExp(r'''style\s*=\s*["']([^"']*)["']''', caseSensitive: false),
    (match) {
      final declarations = match.group(1)!.split(';');
      final kept = declarations
          .where((declaration) {
            final key = declaration.split(':').first.trim().toLowerCase();
            if (key.isEmpty) return false;
            return !key.contains('color') &&
                !key.contains('background') &&
                !key.contains('text-decoration');
          })
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(';');
      return kept.isEmpty ? '' : 'style="$kept"';
    },
  );

  // <mark> 高亮底色去掉，避免整段变成色块
  result = result.replaceAll(
    RegExp(r'</?mark\b[^>]*>', caseSensitive: false),
    '',
  );

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
