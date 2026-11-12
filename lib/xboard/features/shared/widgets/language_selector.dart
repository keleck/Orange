import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // 查找当前语言
    final currentLanguage = supportedLanguages.firstWhere(
      (lang) => lang['code'] == currentLocale,
      orElse: () => supportedLanguages[0], // 默认使用简体中文
    );

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      tooltip: '切换语言 / Switch Language',
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
                  Text(
                    language['flag']!,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      language['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate,
              size: 17,
              color: Color(0xFF3B8EF0),
            ),
            const SizedBox(width: 7),
            Text(
              currentLanguage['name']!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B8EF0),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF3B8EF0),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}