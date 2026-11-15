import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';

/// 自定义分流规则页面
///
/// 支持两类规则：
/// 1. 本地规则：域名后缀 / 域名 / 域名关键字 / IP 段 + 目标策略（代理/直连/拒绝）
/// 2. 远程规则：远程规则集 URL（RULE-SET）
class CustomRulesPage extends ConsumerStatefulWidget {
  const CustomRulesPage({super.key});

  @override
  ConsumerState<CustomRulesPage> createState() => _CustomRulesPageState();
}

class _CustomRulesPageState extends ConsumerState<CustomRulesPage> {
  static List<_RuleType> get _types => <_RuleType>[
        _RuleType(
          appLocalizations.xboardDomainSuffix,
          'DOMAIN-SUFFIX',
          'example.com',
          Icons.language_rounded,
        ),
        _RuleType(
          appLocalizations.xboardExactDomain,
          'DOMAIN',
          'www.example.com',
          Icons.my_location_rounded,
        ),
        _RuleType(
          appLocalizations.xboardDomainKeyword,
          'DOMAIN-KEYWORD',
          'example',
          Icons.text_fields_rounded,
        ),
        _RuleType(
          appLocalizations.xboardIpv4Cidr,
          'IP-CIDR',
          '192.168.0.0/16',
          Icons.router_outlined,
        ),
        _RuleType(
          appLocalizations.xboardIpv6Cidr,
          'IP-CIDR6',
          '2001:db8::/32',
          Icons.settings_ethernet_rounded,
        ),
        _RuleType(
          appLocalizations.xboardCountryRegion,
          'GEOIP',
          'CN',
          Icons.public_rounded,
        ),
      ];

  static List<_RuleTarget> get _targets => <_RuleTarget>[
        _RuleTarget(appLocalizations.proxies, 'PROXY', Icons.vpn_key_rounded),
        _RuleTarget(appLocalizations.direct, 'DIRECT', Icons.link_off_rounded),
        _RuleTarget(
            appLocalizations.xboardRejectAction, 'REJECT', Icons.block_rounded),
      ];

  final _ruleController = TextEditingController();
  final _remoteController = TextEditingController();

  _RuleType _type = _types.first;
  _RuleTarget _target = _targets.first;

  @override
  void dispose() {
    _ruleController.dispose();
    _remoteController.dispose();
    super.dispose();
  }

  List<String> get _rules => ref.read(patchClashConfigProvider).customRules;

  /// 代理目标使用当前配置里的第一个策略组名，取不到时退回 PROXY
  String _resolveTarget(_RuleTarget target) {
    if (target.token != 'PROXY') return target.token;
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) return 'PROXY';
    return groups.first.name;
  }

  Future<void> _addRule() async {
    final value = _ruleController.text.trim();
    if (value.isEmpty) return;

    final isIpRule = _type.token == 'IP-CIDR' || _type.token == 'IP-CIDR6';
    if (isIpRule && !value.contains('/')) {
      XBoardNotification.showError(
        _type.token == 'IP-CIDR6'
            ? appLocalizations.xboardIpv6CidrHint
            : appLocalizations.xboardIpv4CidrHint,
      );
      return;
    }

    final rule = isIpRule
        ? '${_type.token},$value,${_resolveTarget(_target)},no-resolve'
        : '${_type.token},$value,${_resolveTarget(_target)}';

    await _appendRules([rule]);
    _ruleController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _addRemoteRule() async {
    final url = _remoteController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      XBoardNotification.showError(appLocalizations.xboardRuleSetUrlHint);
      return;
    }

    final rule = 'RULE-SET,$url,${_resolveTarget(_target)}';
    await _appendRules([rule]);
    _remoteController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _appendRules(List<String> newRules) async {
    final current = _rules;
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(
            customRules: [...current, ...newRules],
          ),
        );
    XBoardNotification.showSuccess(appLocalizations.xboardRuleAdded);
    _applyConfig();
  }

  Future<void> _removeRule(String rule) async {
    final current = _rules;
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(
            customRules: current.where((item) => item != rule).toList(),
          ),
        );
    XBoardNotification.showSuccess(appLocalizations.xboardRuleDeleted);
    _applyConfig();
  }

  Future<void> _clearAll() async {
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(customRules: const []),
        );
    XBoardNotification.showSuccess(appLocalizations.xboardRulesCleared);
    _applyConfig();
  }

  void _applyConfig() {
    if (globalState.isStart) {
      globalState.appController.setupClashConfigDebounce();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(
      patchClashConfigProvider.select((state) => state.customRules),
    );
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: AppColors.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: [
                    _buildRuleComposer(primary),
                    const SizedBox(height: 14),
                    _buildRemoteComposer(primary),
                    if (rules.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Text(
                            appLocalizations.xboardRulesAdded,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${rules.length} ${appLocalizations.xboardRulesUnit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.35),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _clearAll,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              appLocalizations.xboardClearAll,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.redAccent.withValues(alpha: 0.8),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...rules.map((rule) => _buildRuleItem(rule, primary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            appLocalizations.xboardCustomRoutingRules,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleComposer(Color primary) {
    return _Panel(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: _type.label,
                  icon: _type.icon,
                  onTap: () async {
                    final picked = await showOptionSheet<_RuleType>(
                      context: context,
                      title: AppLocalizations.of(context).xboardMatchType,
                      items: _types
                          .map(
                            (item) => _PickerOption<_RuleType>(
                              value: item,
                              label: item.label,
                              icon: item.icon,
                            ),
                          )
                          .toList(),
                      selected: _type,
                    );
                    if (picked != null) {
                      setState(() => _type = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerField(
                  label: _target.label,
                  icon: _target.icon,
                  onTap: () async {
                    final picked = await showOptionSheet<_RuleTarget>(
                      context: context,
                      title: AppLocalizations.of(context).xboardTargetPolicy,
                      items: _targets
                          .map(
                            (item) => _PickerOption<_RuleTarget>(
                              value: item,
                              label: item.label,
                              icon: item.icon,
                            ),
                          )
                          .toList(),
                      selected: _target,
                    );
                    if (picked != null) {
                      setState(() => _target = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  controller: _ruleController,
                  hint: _type.hint,
                  onSubmitted: (_) => _addRule(),
                ),
              ),
              const SizedBox(width: 10),
              _AddButton(
                color: primary,
                onTap: _addRule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteComposer(Color primary) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLocalizations.xboardRemoteRuleUrl,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  controller: _remoteController,
                  hint: 'https://example.com/rules.yaml',
                  onSubmitted: (_) => _addRemoteRule(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addRemoteRule,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    appLocalizations.add,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule, Color primary) {
    final parts = rule.split(',');
    final type = parts.isNotEmpty ? parts[0] : '';
    final value = parts.length > 1 ? parts[1] : '';
    final target = parts.length > 2 ? parts[2] : '';
    final isRemote = type == 'RULE-SET';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isRemote ? Icons.cloud_download_outlined : Icons.rule_rounded,
              size: 15,
              color: primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_typeLabel(type)} · ${_targetLabel(target)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.38),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeRule(rule),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.redAccent.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String token) {
    for (final type in _types) {
      if (type.token == token) return type.label;
    }
    if (token == 'RULE-SET') return appLocalizations.xboardRemoteRules;
    return token;
  }

  String _targetLabel(String token) {
    for (final target in _targets) {
      if (target.token == token) return target.label;
    }
    if (token == 'DIRECT') return appLocalizations.direct;
    if (token == 'REJECT') return appLocalizations.xboardRejectAction;
    return appLocalizations.proxies;
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: child,
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 13.5,
          color: Colors.white,
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _AddButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.72)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RuleType {
  final String label;
  final String token;
  final String hint;
  final IconData icon;

  const _RuleType(this.label, this.token, this.hint, this.icon);
}

class _RuleTarget {
  final String label;
  final String token;
  final IconData icon;

  const _RuleTarget(this.label, this.token, this.icon);
}

/// 点击后从底部弹出选项面板的字段（替代原来的 DropdownButton）
class _PickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerOption<T> {
  final T value;
  final String label;
  final IconData icon;

  const _PickerOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// 从底部弹出的单选面板：标题 + 图标 + 文案 + 选中勾
Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<_PickerOption<T>> items,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _OptionSheet<T>(
      title: title,
      items: items,
      selected: selected,
    ),
  );
}

class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final List<_PickerOption<T>> items;
  final T selected;

  const _OptionSheet({
    required this.title,
    required this.items,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.72),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              primary.withValues(alpha: 0.10),
              const Color(0xFF1B2030),
            ),
            const Color(0xFF14161F),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item.value == selected;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(item.value),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 21,
                            color: isSelected
                                ? primary
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? primary
                                    : Colors.white.withValues(alpha: 0.9),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
