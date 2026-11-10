import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/xboard/features/shared/services/service_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _cardSurface = Color(0xFF141226);
const _sheetSurface = Color(0xFF0F0E1D);

/// 卡片上展示的数量
const _cardServiceCount = 2;

Color _statusColor(ServiceProbeStatus status) {
  switch (status) {
    case ServiceProbeStatus.available:
      return _green;
    case ServiceProbeStatus.restricted:
    case ServiceProbeStatus.disallowedIsp:
    case ServiceProbeStatus.blocked:
    case ServiceProbeStatus.unsupportedRegion:
    case ServiceProbeStatus.originalsOnly:
    case ServiceProbeStatus.comingSoon:
      return _amber;
    case ServiceProbeStatus.unavailable:
    case ServiceProbeStatus.timeout:
    case ServiceProbeStatus.failed:
      return _red;
  }
}

String _statusText(ServiceCheck? check, {required bool loading}) {
  if (loading) {
    return '检测中';
  }
  if (check == null) {
    return '待检测';
  }
  if (check.isOk) {
    return check.delay != null ? '${check.delay} ms' : check.status.label;
  }
  return check.status.label;
}

Color _statusTextColor(ServiceCheck? check, {required bool loading}) {
  if (loading) {
    return Colors.white.withValues(alpha: 0.5);
  }
  if (check == null) {
    return Colors.white.withValues(alpha: 0.4);
  }
  if (check.isOk) {
    return Colors.white.withValues(alpha: 0.85);
  }
  return _statusColor(check.status);
}

String countryFlagEmoji(String? code) {
  if (code == null || code.length != 2) return '';
  final upper = code.toUpperCase();
  final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  if (first < 0x1F1E6 || second < 0x1F1E6) return '';
  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// 服务状态卡片：展示已启用服务的前两项，点击打开完整列表
class ServiceStatusCard extends StatefulWidget {
  const ServiceStatusCard({
    super.key,
    required this.proxyName,
    this.nodeName,
  });

  /// 用于探测的节点 / 策略组名称
  final String proxyName;

  /// 当前选中的节点名。
  ///
  /// 只用于感知切换：策略组名不会随选中的节点变化，靠它才能在用户
  /// 换了节点之后立刻重测，而不是等进详情页才更新。
  final String? nodeName;

  @override
  State<ServiceStatusCard> createState() => _ServiceStatusCardState();
}

class _ServiceStatusCardState extends State<ServiceStatusCard> {
  Map<ServiceTarget, ServiceCheck> _checks = {};
  List<ServiceTarget> _enabled = ServiceTarget.values;
  bool _probing = false;

  /// 探测进行中又切了节点时记下来，等这一轮结束再补测一次。
  bool _pendingProbe = false;

  List<ServiceTarget> get _targets =>
      _enabled.take(_cardServiceCount).toList();

  String get _storeKey => '${widget.proxyName}|${widget.nodeName ?? ''}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void didUpdateWidget(ServiceStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proxyName != widget.proxyName ||
        oldWidget.nodeName != widget.nodeName) {
      _bootstrap();
    }
  }

  /// 进入页面 / 切换节点：绑定缓存，缺哪几项才补测哪几项。
  Future<void> _bootstrap() async {
    ServiceStatusStore.bind(_storeKey);
    await _syncEnabled();
    final missing = _targets
        .where((target) => !_checks.containsKey(target))
        .toList();
    if (missing.isNotEmpty) {
      await _probe(missing);
    }
  }

  /// 只同步勾选配置与已有结果，不触发探测。
  Future<void> _syncEnabled() async {
    final ids = await ServiceStatusPrefs.load();
    if (!mounted) return;
    setState(() {
      _enabled = ServiceTarget.values
          .where((target) => ids.contains(target.id))
          .toList();
      _checks = Map.of(ServiceStatusStore.checks);
    });
  }

  Future<void> _probe(List<ServiceTarget> targets) async {
    if (_probing) {
      _pendingProbe = true;
      return;
    }
    if (targets.isEmpty) {
      return;
    }
    setState(() {
      _probing = true;
      for (final target in targets) {
        _checks.remove(target);
      }
    });
    var result = <ServiceTarget, ServiceCheck>{};
    try {
      result = await checkServices(
        proxyName: widget.proxyName,
        targets: targets,
      );
    } catch (e) {
      // 探测本身出错也必须复位，否则界面会永久停在「检测中」。
      commonPrint.log('服务探测失败: $e');
    }
    ServiceStatusStore.merge(result);
    if (!mounted) return;
    setState(() {
      _checks = Map.of(ServiceStatusStore.checks);
      _probing = false;
    });
    if (_pendingProbe) {
      _pendingProbe = false;
      await _bootstrap();
    }
  }

  Widget _buildVerdict() {
    if (_targets.isEmpty) {
      return _Verdict(
        label: '未启用',
        color: Colors.white.withValues(alpha: 0.55),
      );
    }
    if (_probing) {
      return _Verdict(
        label: '检测中',
        color: Colors.white.withValues(alpha: 0.55),
      );
    }
    final done = _targets.where((t) => _checks.containsKey(t)).toList();
    if (done.isEmpty) {
      return _Verdict(
        label: '待检测',
        color: Colors.white.withValues(alpha: 0.55),
      );
    }
    final abnormal = done.where((t) => _checks[t]?.isOk != true).length;
    if (abnormal > 0) {
      return _Verdict(label: '$abnormal 项异常', color: _amber);
    }
    if (done.length < _targets.length) {
      return _Verdict(
        label: '${done.length}/${_targets.length} 已测',
        color: _amber,
      );
    }
    return const _Verdict(label: '全部正常', color: _green);
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      // 用根导航器，避免弹层被外层 shell 的底部导航栏遮住
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServiceStatusSheet(
        proxyName: widget.proxyName,
        nodeName: widget.nodeName,
      ),
    );
    // 详情页里可能改过勾选，回卡片只同步配置与已有结果，不重测
    if (mounted) {
      await _syncEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openSheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                const Text(
                  '服务状态',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                _buildVerdict(),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_targets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '未选择需要检测的服务，点击此处配置',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < _targets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _buildCell(_targets[i])),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(ServiceTarget target) {
    final check = _checks[target];
    final loading = _probing && check == null;
    final label = _statusText(check, loading: loading);
    final color = _statusTextColor(check, loading: loading);
    final dotColor = loading
        ? null
        : (check == null
              ? Colors.white.withValues(alpha: 0.3)
              : (check.isOk ? _green : _red));

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ServiceIconBadge(
            icon: target.icon,
            size: 26,
            radius: 8,
            dotColor: dotColor,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 完整服务状态列表
class ServiceStatusSheet extends StatefulWidget {
  const ServiceStatusSheet({
    super.key,
    required this.proxyName,
    this.nodeName,
  });

  final String proxyName;

  /// 与卡片共用同一份缓存 key，没切节点时复用已有结果
  final String? nodeName;

  @override
  State<ServiceStatusSheet> createState() => _ServiceStatusSheetState();
}

class _ServiceStatusSheetState extends State<ServiceStatusSheet> {
  Map<ServiceTarget, ServiceCheck> _checks = {};
  List<ServiceTarget> _enabled = ServiceTarget.values;
  IpInfo? _ipInfo;
  bool _probing = false;
  bool _ipLoading = false;

  String get _storeKey => '${widget.proxyName}|${widget.nodeName ?? ''}';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 首次进入：复用缓存，只补测还没有结果的服务；都测过就什么都不做。
  Future<void> _bootstrap() async {
    ServiceStatusStore.bind(_storeKey);
    final ids = await ServiceStatusPrefs.load();
    if (!mounted) return;
    setState(() {
      _enabled = ServiceTarget.values
          .where((target) => ids.contains(target.id))
          .toList();
      _checks = Map.of(ServiceStatusStore.checks);
      _ipInfo = ServiceStatusStore.ipInfo;
    });
    final missing = _enabled
        .where((target) => !_checks.containsKey(target))
        .toList();
    if (missing.isNotEmpty) {
      await _probe(missing, clear: false);
    }
    if (!ServiceStatusStore.ipLoaded) {
      unawaited(_loadIp());
    }
  }

  /// 手动刷新（↻ 或下拉）：全部重测。
  Future<void> _refresh() async {
    unawaited(_loadIp(force: true));
    await _probe(_enabled, clear: true);
  }

  Future<void> _probe(
    List<ServiceTarget> targets, {
    required bool clear,
  }) async {
    if (_probing || targets.isEmpty) return;
    setState(() {
      _probing = true;
      if (clear) {
        _checks = {};
        for (final target in targets) {
          ServiceStatusStore.checks.remove(target);
        }
      } else {
        for (final target in targets) {
          _checks.remove(target);
        }
      }
    });
    var result = <ServiceTarget, ServiceCheck>{};
    try {
      result = await checkServices(
        proxyName: widget.proxyName,
        targets: targets,
      );
    } catch (e) {
      commonPrint.log('服务探测失败: $e');
    }
    ServiceStatusStore.merge(result);
    if (!mounted) return;
    setState(() {
      _checks = Map.of(ServiceStatusStore.checks);
      _probing = false;
    });
  }

  /// 出口 IP 由内核走当前节点取，因此国旗来自节点落地归属地而不是本机。
  Future<void> _loadIp({bool force = false}) async {
    if (_ipLoading) return;
    if (!force && ServiceStatusStore.ipLoaded) {
      setState(() => _ipInfo = ServiceStatusStore.ipInfo);
      return;
    }
    setState(() => _ipLoading = true);
    final info = await lookupOutboundIp(proxyName: widget.proxyName);
    ServiceStatusStore.ipInfo = info;
    ServiceStatusStore.ipLoaded = true;
    if (!mounted) return;
    setState(() {
      _ipInfo = info;
      _ipLoading = false;
    });
  }

  Future<void> _openManager() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServiceManagerSheet(enabled: _enabled),
    );
    if (!mounted) return;
    final ids = await ServiceStatusPrefs.load();
    if (!mounted) return;
    // 只同步勾选，不重测；已有结果全部保留
    setState(() {
      _enabled = ServiceTarget.values
          .where((target) => ids.contains(target.id))
          .toList();
      _checks = Map.of(ServiceStatusStore.checks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      height: media.size.height * 0.85,
      decoration: const BoxDecoration(
        color: _sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '服务状态',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openManager,
                  tooltip: '管理服务',
                  icon: Icon(
                    Icons.tune,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                IconButton(
                  onPressed: _probing ? null : _refresh,
                  tooltip: '重新检测',
                  icon: _probing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.refresh,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                ),
              ],
            ),
          ),
          _buildIpHeader(media),
          Expanded(
            child: _enabled.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 12 + media.padding.bottom,
                      ),
                      itemCount: _enabled.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 60,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      itemBuilder: (_, index) => _buildRow(_enabled[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpHeader(MediaQueryData media) {
    final info = _ipInfo;
    final flag = countryFlagEmoji(info?.countryCode);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.public,
            size: 16,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 8),
          Text(
            '出口 IP',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          if (_ipLoading && info == null)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            )
          else ...[
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
            ],
            Text(
              info?.ip ?? '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: info == null
                    ? Colors.white.withValues(alpha: 0.4)
                    : _green,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '未启用任何服务',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _openManager,
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(ServiceTarget target) {
    final check = _checks[target];
    final loading = _probing && check == null;
    final label = _statusText(check, loading: loading);
    final color = _statusTextColor(check, loading: loading);
    final dotColor = loading
        ? null
        : (check == null
              ? Colors.white.withValues(alpha: 0.3)
              : (check.isOk ? _green : _red));
    // Google / GitHub 只判连通性、TikTok 的页面解析也可能拿不到地区，
    // 这类服务用出口 IP 的归属地兜底，保证每行都有旗帜。
    final region = check?.region ?? _ipInfo?.countryCode;
    final flag = countryFlagEmoji(region);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          ServiceIconBadge(
            icon: target.icon,
            size: 42,
            radius: 12,
            dotColor: dotColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (flag.isNotEmpty) ...[
                      Text(flag, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          region!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ] else
                      Flexible(
                        child: Text(
                          _ipInfo?.ip ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: _ipInfo == null
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 管理服务：勾选需要检测/显示的服务
class ServiceManagerSheet extends StatefulWidget {
  const ServiceManagerSheet({
    super.key,
    required this.enabled,
  });

  final List<ServiceTarget> enabled;

  @override
  State<ServiceManagerSheet> createState() => _ServiceManagerSheetState();
}

class _ServiceManagerSheetState extends State<ServiceManagerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.enabled.map((target) => target.id).toSet();
  }

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      _selected = value
          ? ServiceTarget.values.map((target) => target.id).toSet()
          : <String>{};
    });
  }

  Future<void> _save() async {
    await ServiceStatusPrefs.save(_selected);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final allSelected = _selected.length == ServiceTarget.values.length;
    return Container(
      height: media.size.height * 0.75,
      decoration: const BoxDecoration(
        color: _sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                const Text(
                  '管理服务',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selected.length}/${ServiceTarget.values.length}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _toggleAll(!allSelected),
                  child: Text(allSelected ? '全不选' : '全选'),
                ),
                TextButton(
                  onPressed: _save,
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: 12 + media.padding.bottom),
              itemCount: ServiceTarget.values.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 60,
                color: Colors.white.withValues(alpha: 0.07),
              ),
              itemBuilder: (_, index) {
                final target = ServiceTarget.values[index];
                final checked = _selected.contains(target.id);
                return InkWell(
                  onTap: () => _toggle(target.id, !checked),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        ServiceIconBadge(
                          icon: target.icon,
                          size: 34,
                          radius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            target.label,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Checkbox(
                          value: checked,
                          onChanged: (value) => _toggle(target.id, value ?? false),
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
    );
  }
}

/// 服务图标 + 右下角状态点
class ServiceIconBadge extends StatelessWidget {
  const ServiceIconBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.radius,
    this.dotColor,
  });

  final String icon;
  final double size;
  final double radius;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final dot = size / 4.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: SvgPicture.asset(
              'assets/images/services/$icon.svg',
              width: size * 0.55,
              height: size * 0.55,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.85),
                BlendMode.srcIn,
              ),
            ),
          ),
          if (dotColor != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: _cardSurface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
