import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'zh_CN', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'en', 'name': 'English', 'flag': '🌐'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final appSetting = ref.watch(appSettingProvider);
    final currentLocale = appSetting.locale;

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      padding: EdgeInsets.zero,
      // 跟随当前主题的页面背景，深色下不再出现偏紫的默认容器色
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      tooltip: AppLocalizations.of(context).xboardSwitchLanguage,
      onSelected: (String languageCode) {
        ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(locale: languageCode),
            );
      },
      itemBuilder: (BuildContext context) {
        return supportedLanguages.map<PopupMenuEntry<String>>(
          (Map<String, String> language) {
            final isSelected = language['code'] == currentLocale;
            return PopupMenuItem<String>(
              value: language['code'],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      language['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                ],
              ),
            );
          },
        ).toList();
      },
      // 用 child 而不是 icon：icon 会被塞进 IconButton（48x48 最小尺寸 + 内边距），
      // 胶囊会显得偏大偏空
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate,
              size: 17,
              color: Color(0xFF3B8EF0),
            ),
            SizedBox(width: 1),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF3B8EF0),
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}
