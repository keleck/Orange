import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/shared/widgets/app_icon_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/cache.dart';
import 'package:fl_clash/xboard/features/user/providers/campus_hosts_provider.dart';
import 'package:fl_clash/xboard/features/user/pages/custom_rules_page.dart';
import 'package:fl_clash/xboard/features/user/pages/access_control_page.dart';
import 'package:fl_clash/xboard/features/user/widgets/settings_card.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/widgets/app_switch.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _ipv6Enabled = false;
  bool _lanProxyEnabled = false;
  bool _ipv6Loading = false;
  bool _lanProxyLoading = false;
  bool _isInitialized = false;
  bool _campusHostsLoading = false;
  bool _geoUpdating = false;
  Future<_GeoInfo>? _geoInfoFuture;
  late TextEditingController _importRulesController;

  @override
  void initState() {
    super.initState();
    _importRulesController = TextEditingController();
    _geoInfoFuture = _loadGeoInfo();
    _loadSettings();
  }

  @override
  void dispose() {
    _importRulesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      // 从本地Clash配置读取IPv6和局域网代理设置
      final clashConfig = ref.read(patchClashConfigProvider);
      if (mounted) {
        setState(() {
          _ipv6Enabled = clashConfig.ipv6;
          // 本地配置的 allow-lan 为 true 表示 "关闭"，因此这里取反
          _lanProxyEnabled = !clashConfig.allowLan;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  Future<void> _updateIPv6Setting(bool value) async {
    setState(() => _ipv6Loading = true);
    try {
      // 更新本地Clash配置
      ref.read(patchClashConfigProvider.notifier).updateState(
            (state) => state.copyWith(ipv6: value),
          );

      if (mounted) {
        setState(() => _ipv6Enabled = value);
        XBoardNotification.showSuccess(value
            ? appLocalizations.xboardIpv6Enabled
            : appLocalizations.xboardIpv6Disabled);
      }
    } catch (e) {
      if (mounted) {
        // 恢复之前的状态
        ref.read(patchClashConfigProvider.notifier).updateState(
              (state) => state.copyWith(ipv6: !value),
            );
        setState(() => _ipv6Enabled = !value);
        XBoardNotification.showError('设置失败: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _ipv6Loading = false);
      }
    }
  }

  Future<void> _updateLanProxySetting(bool value) async {
    setState(() => _lanProxyLoading = true);
    try {
      // 更新本地Clash配置（逻辑反转：true关闭，false开启）
      ref.read(patchClashConfigProvider.notifier).updateState(
            (state) => state.copyWith(allowLan: !value),
          );

      if (mounted) {
        setState(() => _lanProxyEnabled = value);
        XBoardNotification.showSuccess(value
            ? appLocalizations.xboardLanProxyEnabled
            : appLocalizations.xboardLanProxyDisabled);
      }
    } catch (e) {
      if (mounted) {
        // 恢复之前的状态
        ref.read(patchClashConfigProvider.notifier).updateState(
              (state) => state.copyWith(allowLan: value),
            );
        setState(() => _lanProxyEnabled = !value);
        XBoardNotification.showError('设置失败: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _lanProxyLoading = false);
      }
    }
  }

  Future<void> _removeCustomRule(String rule) async {
    try {
      final currentRules = ref.read(patchClashConfigProvider).customRules;
      final updatedRules = currentRules.where((r) => r != rule).toList();

      ref.read(patchClashConfigProvider.notifier).updateState(
            (state) => state.copyWith(customRules: updatedRules),
          );

      XBoardNotification.showSuccess(appLocalizations.xboardRuleDeleted);

      // 重新应用 Clash 配置使规则生效
      await _applyConfig();
    } catch (e) {
      XBoardNotification.showError('删除失败: ${e.toString()}');
    }
  }

  Future<void> _clearAllRules() async {
    try {
      ref.read(patchClashConfigProvider.notifier).updateState(
            (state) => state.copyWith(customRules: []),
          );

      XBoardNotification.showSuccess(appLocalizations.xboardAllRulesCleared);

      // 重新应用 Clash 配置
      await _applyConfig();
    } catch (e) {
      XBoardNotification.showError('清除失败: ${e.toString()}');
    }
  }

  Future<void> _importRules(String rulesText) async {
    try {
      if (rulesText.trim().isEmpty) {
        XBoardNotification.showError(appLocalizations.xboardEnterRules);
        return;
      }

      // 解析规则：按换行符或分号分隔
      final lines = rulesText
          .split(RegExp(r'[\n;]'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        XBoardNotification.showError(appLocalizations.xboardNoValidRules);
        return;
      }

      final groups = ref.read(groupsProvider);
      final currentRules = ref.read(patchClashConfigProvider).customRules;
      int successCount = 0;
      int skipCount = 0;
      final invalidRules = <String>[];

      final newRules = <String>[];

      for (final line in lines) {
        final parts = line.split(',');

        // 检查规则格式
        if (parts.length < 3) {
          invalidRules.add('$line (格式错误)');
          continue;
        }

        final ruleType = parts[0].trim();
        final ruleContent = parts[1].trim();
        final destination = parts[2].trim(); // 只取第3个部分作为目标，忽略其他参数如 no-resolve

        if (destination.isEmpty) {
          invalidRules.add('$line (缺少目标)');
          continue;
        }

        // 验证目标是否存在（代理组或节点）
        bool targetExists = false;

        // 检查是否是代理组
        if (groups.any((g) => g.name == destination)) {
          targetExists = true;
        } else {
          // 检查是否是节点
          for (var group in groups) {
            if (group.all case final proxies) {
              if (proxies.any((p) => p.name == destination)) {
                targetExists = true;
                break;
              }
            }
          }
        }

        if (!targetExists) {
          invalidRules.add('$line (目标不存在)');
          continue;
        }

        // 检查重复
        if (currentRules.contains(line) || newRules.contains(line)) {
          skipCount++;
          continue;
        }

        newRules.add(line);
        successCount++;
      }

      if (newRules.isEmpty && invalidRules.isEmpty && skipCount == 0) {
        XBoardNotification.showError(appLocalizations.xboardNoValidRules);
        return;
      }

      // 添加新规则
      if (newRules.isNotEmpty) {
        ref.read(patchClashConfigProvider.notifier).updateState(
              (state) => state.copyWith(
                customRules: [...currentRules, ...newRules],
              ),
            );
      }

      // 显示导入结果
      String message = '成功导入 $successCount 条规则';
      if (skipCount > 0) message += '，跳过 $skipCount 条重复规则';
      if (invalidRules.isNotEmpty) {
        message += '\n\n无效规则 (${invalidRules.length}):\n';
        message += invalidRules.take(5).join('\n');
        if (invalidRules.length > 5) {
          message += '\n...等 ${invalidRules.length - 5} 条';
        }
      }

      _importRulesController.clear();

      if (successCount > 0) {
        XBoardNotification.showSuccess(message);
        await _applyConfig();
        _importRulesController.clear();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        XBoardNotification.showError(message);
      }
    } catch (e) {
      XBoardNotification.showError('导入失败: ${e.toString()}');
    }
  }

  void _showImportDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface(context, 0.15),
                    AppColors.surface(context, 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.glassBorder(context),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (AppColors.isDark(context) ? Colors.black.withValues(alpha: 0.2) : const Color(0x1412203A)),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.glassBorder(context),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.upload_file,
                                color: Colors.blue.shade300,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              appLocalizations.xboardBulkImportRules,
                              style: TextStyle(
                                color: AppColors.fg(context),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: AppColors.fg(context).withOpacity(0.6),
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 内容
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue.shade300,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    appLocalizations.xboardRuleFormatHint,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade200,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            appLocalizations.xboardRuleExamples,
                            style: TextStyle(
                              color: AppColors.fg(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (AppColors.isDark(context) ? Colors.black.withValues(alpha: 0.2) : const Color(0x1412203A)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.glassBorder(context),
                              ),
                            ),
                            child: Text(
                              'DOMAIN,example.com,proxy-group-name\nDOMAIN-KEYWORD,youtube,node-name\nIP-CIDR,192.168.0.0/16,DIRECT\nGEOIP,CN,DIRECT',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.fg(context).withOpacity(0.7),
                                fontFamily: 'monospace',
                                height: 1.6,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            appLocalizations.xboardPasteRulesHint,
                            style: TextStyle(
                              color: AppColors.fg(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _importRulesController,
                            maxLines: 10,
                            minLines: 6,
                            style: TextStyle(
                              color: AppColors.fg(context),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)
                                  .xboardRulesPerLineHint,
                              hintStyle: TextStyle(
                                color: AppColors.fg(context).withOpacity(0.4),
                              ),
                              filled: true,
                              fillColor: AppColors.surface(context, 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder(context),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder(context),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade300,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: Colors.green.shade300,
                              ),
                              SizedBox(width: 6),
                              Text(
                                appLocalizations.xboardRuleSeparatorHint,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade300,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 按钮栏
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.glassBorder(context),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                AppColors.fg(context).withOpacity(0.7),
                          ),
                          child: Text(AppLocalizations.of(context).cancel),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _importRules(_importRulesController.text);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cloud_upload,
                                          size: 16,
                                          color: AppColors.fg(context),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          appLocalizations.import,
                                          style: TextStyle(
                                            color: AppColors.fg(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
        ),
      ),
    );
  }

  Future<void> _applyConfig() async {
    try {
      // 显示当前规则列表（用于调试）
      final currentRules = ref.read(patchClashConfigProvider).customRules;
      commonPrint.log('当前自定义规则: $currentRules');

      if (globalState.isStart) {
        // 如果 Clash 已启动，重新应用配置
        XBoardNotification.showInfo(appLocalizations.xboardApplyingClashConfig);
        globalState.appController.setupClashConfigDebounce();
        // 等待一下确保配置已应用
        await Future.delayed(const Duration(seconds: 2));
        XBoardNotification.showSuccess(appLocalizations.xboardConfigUpdated);
      } else {
        XBoardNotification.showInfo(
            appLocalizations.xboardClashNotRunningRulesPending);
      }
    } catch (e) {
      commonPrint.log('应用规则配置失败: $e');
      XBoardNotification.showError('应用失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: AppColors.backgroundDecoration(context),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: Text(AppLocalizations.of(context).settings),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          // 可滚动内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 100), // 底部增加 padding 避免被导航栏遮挡
              children: [
                _buildSectionHeader(
                    context, appLocalizations.xboardBasicSettings,
                    icon: Icons.tune_rounded),
                const SizedBox(height: 14),
                _buildIPv6Section(context),
                const SizedBox(height: 10),
                _buildLanProxySection(context),
                const SizedBox(height: 10),
                _buildProxyUpdateSection(context),
                const SizedBox(height: 10),
                _buildGeoDatabaseSection(context),
                const SizedBox(height: 10),
                _buildClearCacheEntry(context),
                const SizedBox(height: 10),
                _buildCampusHostsSection(context),
                if (Platform.isAndroid) ...[
                  SizedBox(height: 10),
                  _buildAccessControlEntry(context),
                ],
                SizedBox(height: 28),
                _buildSectionHeader(
                  context,
                  appLocalizations.xboardRulesAndRouting,
                  icon: Icons.alt_route_rounded,
                ),
                const SizedBox(height: 14),
                _buildCustomRulesEntry(context),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.fg(context)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildIPv6Section(BuildContext context) {
    return SettingsCard(
      icon: Icons.lan_outlined,
      accentColor: AppIconColors.teal,
      title: AppLocalizations.of(context).xboardIpv6Support,
      subtitle: AppLocalizations.of(context).xboardIpv6Hint,
      trailing: _ipv6Loading
          ? const _CardLoading()
          : AppSwitch(
              value: _ipv6Enabled,
              onChanged: _updateIPv6Setting,
            ),
    );
  }

  Widget _buildLanProxySection(BuildContext context) {
    return SettingsCard(
      icon: Icons.wifi_tethering_rounded,
      accentColor: AppIconColors.blue,
      title: AppLocalizations.of(context).allowLan,
      subtitle: AppLocalizations.of(context).xboardAllowLanDevices,
      trailing: _lanProxyLoading
          ? const _CardLoading()
          : AppSwitch(
              value: _lanProxyEnabled,
              onChanged: _updateLanProxySetting,
            ),
    );
  }

  /// 通过代理更新订阅：开启后拉取订阅时会尝试用本地节点（上次连接的节点）代理
  Widget _buildProxyUpdateSection(BuildContext context) {
    final enabled = ref.watch(
      appSettingProvider.select((state) => state.proxyUpdateSubscription),
    );
    return SettingsCard(
      icon: Icons.cloud_sync_outlined,
      accentColor: AppIconColors.blue,
      title: AppLocalizations.of(context).xboardUpdateSubscriptionViaProxy,
      subtitle: AppLocalizations.of(context).xboardUpdateViaLastNode,
      trailing: AppSwitch(
        value: enabled,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(proxyUpdateSubscription: value),
              );
          XBoardNotification.showSuccess(
            value
                ? appLocalizations.xboardUpdateViaProxyOn
                : appLocalizations.xboardUpdateViaProxyOff,
          );
        },
      ),
    );
  }

  /// 地理数据库：展示本地 geoip.metadb 的日期与体积，并支持一键更新
  Widget _buildGeoDatabaseSection(BuildContext context) {
    return FutureBuilder<_GeoInfo>(
      future: _geoInfoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final detail = info == null
            ? appLocalizations.xboardReading
            : info.exists
                ? '${info.dateText}   ${info.sizeText}'
                : appLocalizations.xboardNotDownloaded;
        return SettingsCard(
          icon: Icons.public_rounded,
          accentColor: AppIconColors.blue,
          title: AppLocalizations.of(context).xboardGeoDatabase,
          subtitle: AppLocalizations.of(context).xboardGeoDatabaseHint,
          child: Column(
            children: [
              SettingsInfoBar(text: detail),
              const SizedBox(height: 12),
              SettingsOutlineButton(
                icon: Icons.download_rounded,
                label: AppLocalizations.of(context).xboardUpdateGeoDatabase,
                loading: _geoUpdating,
                onTap: _updateGeoDatabase,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 自定义分流规则入口
  Widget _buildCustomRulesEntry(BuildContext context) {
    final count = ref.watch(
      patchClashConfigProvider.select((state) => state.customRules.length),
    );
    return SettingsCard(
      icon: Icons.rule_folder_outlined,
      accentColor: AppIconColors.purple,
      title: AppLocalizations.of(context).xboardCustomRoutingRules,
      subtitle:
          count > 0 ? '已配置 $count 条规则' : appLocalizations.xboardAddRulesHint,
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.fg(context).withValues(alpha: 0.3),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomRulesPage()),
        );
      },
    );
  }

  /// 应用访问控制（仅 Android 生效）
  Widget _buildAccessControlEntry(BuildContext context) {
    return SettingsCard(
      icon: Icons.apps_rounded,
      accentColor: AppIconColors.purple,
      title: AppLocalizations.of(context).appAccessControl,
      subtitle: AppLocalizations.of(context).xboardSelectAppsHint,
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.fg(context).withValues(alpha: 0.3),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccessControlPage()),
        );
      },
    );
  }

  Future<_GeoInfo> _loadGeoInfo() async {
    try {
      final home = await appPath.homeDirPath;
      final file = File(p.join(home, mmdbFileName));
      if (!await file.exists()) {
        return const _GeoInfo(exists: false);
      }
      return _GeoInfo(
        exists: true,
        size: await file.length(),
        modified: await file.lastModified(),
      );
    } catch (_) {
      return const _GeoInfo(exists: false);
    }
  }

  Future<void> _updateGeoDatabase() async {
    setState(() => _geoUpdating = true);
    try {
      final message = await clashCore.updateGeoData(
        UpdateGeoDataParams(
          geoName: mmdbFileName,
          geoType: 'MMDB',
        ),
      );
      if (message.isNotEmpty) throw message;
      XBoardNotification.showSuccess(appLocalizations.xboardGeoDatabaseUpdated);
      if (mounted) {
        setState(() => _geoInfoFuture = _loadGeoInfo());
      }
    } catch (e) {
      XBoardNotification.showError('更新失败: $e');
    } finally {
      if (mounted) {
        setState(() => _geoUpdating = false);
      }
    }
  }

  /// 清理缓存入口（放在校园网 Hosts 上方）
  Widget _buildClearCacheEntry(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    return SettingsCard(
      icon: Icons.cleaning_services_rounded,
      accentColor: AppIconColors.orange,
      title: appLocalizations.xboardClearCache,
      subtitle: appLocalizations.xboardClearCacheHint,
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.fg(context).withValues(alpha: 0.3),
      ),
      onTap: _confirmClearCache,
    );
  }

  /// 二次确认后再清，避免误触把缓存连登录态一起清了
  Future<void> _confirmClearCache() async {
    final appLocalizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.panel(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appLocalizations.xboardClearCacheDialogTitle,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg(dialogContext),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                appLocalizations.xboardClearCacheDialogBody,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.fg(dialogContext).withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(
                      appLocalizations.xboardCancel,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            AppColors.fg(dialogContext).withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      appLocalizations.xboardClearCacheAction,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _performClearCache();
  }

  Future<void> _performClearCache() async {
    final appLocalizations = AppLocalizations.of(context);
    try {
      await AppCacheService.clear();
      if (!mounted) {
        return;
      }
      XBoardNotification.showSuccess(appLocalizations.xboardClearCacheDone);
      final restarted = await AppCacheService.restart();
      if (!restarted && mounted) {
        // Android 不支持自重启，退化成提示
        XBoardNotification.showSuccess(
          appLocalizations.xboardClearCacheRestartHint,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      XBoardNotification.showError(
        '${appLocalizations.xboardClearCacheFailed}: $e',
      );
    }
  }

  Widget _buildCampusHostsSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final campusHostsAsync = ref.watch(campusHostsProvider);

        return campusHostsAsync.when(
          data: (hosts) {
            if (hosts.isEmpty) {
              return const SizedBox.shrink();
            }

            // 直接从当前配置中检查是否已启用
            final isEnabled = isCampusHostsEnabled(ref, hosts);

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(context, 0.1),
                    border: Border.all(
                      color: AppColors.glassBorder(context),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appLocalizations.xboardCampusHosts,
                                  style: TextStyle(
                                    color: AppColors.fg(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${hosts.length} 条穿透规则',
                                  style: TextStyle(
                                    color:
                                        AppColors.fg(context).withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSwitch(
                            value: isEnabled,
                            activeColor: Colors.green.shade600,
                            onChanged: _campusHostsLoading
                                ? null
                                : (value) async {
                                    setState(() => _campusHostsLoading = true);
                                    try {
                                      if (value) {
                                        await applyCampusHosts(ref, hosts);
                                        XBoardNotification.showSuccess(
                                            appLocalizations
                                                .xboardCampusHostsEnabled);
                                      } else {
                                        await clearCampusHosts(ref, hosts);
                                        XBoardNotification.showSuccess(
                                            appLocalizations
                                                .xboardCampusHostsDisabled);
                                      }
                                      // 触发重建以更新开关状态
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    } catch (e) {
                                      XBoardNotification.showError(
                                          appLocalizations
                                              .xboardOperationFailed);
                                    } finally {
                                      if (mounted) {
                                        setState(
                                            () => _campusHostsLoading = false);
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        appLocalizations.xboardCampusHostsHint,
                        style: TextStyle(
                          color: AppColors.fg(context).withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.fg(context)),
                ),
              ),
              SizedBox(width: 8),
              Text(
                appLocalizations.xboardLoadingCampusConfig,
                style: TextStyle(
                  color: AppColors.fg(context).withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          error: (error, stack) => Text(
            appLocalizations.xboardCampusConfigFailed,
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}

class _GeoInfo {
  final bool exists;
  final int size;
  final DateTime? modified;

  const _GeoInfo({
    required this.exists,
    this.size = 0,
    this.modified,
  });

  String get dateText {
    final date = modified;
    if (date == null) return '--';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get sizeText {
    if (size <= 0) return '0 B';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
            AppColors.fg(context).withValues(alpha: 0.7)),
      ),
    );
  }
}
