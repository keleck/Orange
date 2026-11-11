import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  static const _types = <_RuleType>[
    _RuleType('域名后缀', 'DOMAIN-SUFFIX', 'example.com'),
    _RuleType('域名', 'DOMAIN', 'www.example.com'),
    _RuleType('域名关键字', 'DOMAIN-KEYWORD', 'example'),
    _RuleType('IP 段', 'IP-CIDR', '192.168.0.0/16'),
  ];

  static const _targets = <_RuleTarget>[
    _RuleTarget('代理', 'PROXY'),
    _RuleTarget('直连', 'DIRECT'),
    _RuleTarget('拒绝', 'REJECT'),
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

  List<String> get _rules =>
      ref.read(patchClashConfigProvider).customRules;

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

    if (_type.token == 'IP-CIDR' && !value.contains('/')) {
      XBoardNotification.showError('IP 段格式应为 192.168.0.0/16');
      return;
    }

    final rule = _type.token == 'IP-CIDR'
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
      XBoardNotification.showError('请输入 http(s) 开头的规则集地址');
      return;
    }

    final rule = 'RULE-SET,$url,${_resolveTarget(_target)}';
    await _appendRules([rule]);
    _remoteController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _showBulkImport() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text(
          '批量导入规则',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '每行一条，格式：类型,内容,目标\n例如：DOMAIN-SUFFIX,example.com,DIRECT',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 7,
              minLines: 5,
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DOMAIN-SUFFIX,google.com,PROXY\nDOMAIN-KEYWORD,ad,REJECT',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              '导入',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return;

    final lines = text
        .split(RegExp(r'[\n;]'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final current = _rules;
    final valid = <String>[];
    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length < 3) continue;
      if (parts[1].trim().isEmpty) continue;
      if (current.contains(line) || valid.contains(line)) continue;
      valid.add(line);
    }

    if (valid.isEmpty) {
      XBoardNotification.showError('没有可导入的有效规则');
      return;
    }

    await _appendRules(valid);
  }

  Future<void> _appendRules(List<String> newRules) async {
    final current = _rules;
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(
            customRules: [...current, ...newRules],
          ),
        );
    XBoardNotification.showSuccess('规则已添加');
    _applyConfig();
  }

  Future<void> _removeRule(String rule) async {
    final current = _rules;
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(
            customRules: current.where((item) => item != rule).toList(),
          ),
        );
    XBoardNotification.showSuccess('规则已删除');
    _applyConfig();
  }

  Future<void> _clearAll() async {
    ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(customRules: const []),
        );
    XBoardNotification.showSuccess('已清空自定义规则');
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
                            '已添加规则',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${rules.length} 条',
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
                              '清空',
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
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _showBulkImport,
                        child: Text(
                          '批量导入规则',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.4),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
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
          const Text(
            '自定义分流规则',
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
                child: _DropdownField<_RuleType>(
                  value: _type,
                  items: _types,
                  labelOf: (item) => item.label,
                  icon: Icons.language_rounded,
                  onChanged: (value) => setState(() => _type = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DropdownField<_RuleTarget>(
                  value: _target,
                  items: _targets,
                  labelOf: (item) => item.label,
                  icon: Icons.vpn_key_rounded,
                  onChanged: (value) => setState(() => _target = value),
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
          const Text(
            '远程规则 URL',
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
                    color: primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '添加',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: primary,
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
    if (token == 'RULE-SET') return '远程规则';
    return token;
  }

  String _targetLabel(String token) {
    for (final target in _targets) {
      if (target.token == token) return target.label;
    }
    if (token == 'DIRECT') return '直连';
    if (token == 'REJECT') return '拒绝';
    return '代理';
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

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final IconData icon;
  final ValueChanged<T> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: const Color(0xFF1C1B33),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          style: const TextStyle(
            fontSize: 13.5,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          labelOf(item),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ),
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
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.55),
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

  const _RuleType(this.label, this.token, this.hint);
}

class _RuleTarget {
  final String label;
  final String token;

  const _RuleTarget(this.label, this.token);
}
