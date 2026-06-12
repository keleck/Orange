import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/user/providers/campus_hosts_provider.dart';
import 'package:fl_clash/widgets/app_colors.dart';

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
  bool _campusHostsEnabled = false;
  bool _campusHostsLoading = false;
  late TextEditingController _importRulesController;

  @override
  void initState() {
    super.initState();
    _importRulesController = TextEditingController();
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
        XBoardNotification.showSuccess(
          value ? 'IPv6 已开启' : 'IPv6 已关闭'
        );
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
        XBoardNotification.showSuccess(
          value ? '局域网代理已开启' : '局域网代理已关闭'
        );
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
      
      XBoardNotification.showSuccess('规则已删除');
      
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
      
      XBoardNotification.showSuccess('所有规则已清除');
      
      // 重新应用 Clash 配置
      await _applyConfig();
    } catch (e) {
      XBoardNotification.showError('清除失败: ${e.toString()}');
    }
  }

  Future<void> _importRules(String rulesText) async {
    try {
      if (rulesText.trim().isEmpty) {
        XBoardNotification.showError('请输入规则');
        return;
      }

      // 解析规则：按换行符或分号分隔
      final lines = rulesText
          .split(RegExp(r'[\n;]'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        XBoardNotification.showError('未找到有效的规则');
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
        final destination = parts[2].trim();  // 只取第3个部分作为目标，忽略其他参数如 no-resolve

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
        XBoardNotification.showError('未找到有效的规则');
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
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                          color: Colors.white.withOpacity(0.1),
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
                            const SizedBox(width: 12),
                            Text(
                              '批量导入规则',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.6),
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '每行一条规则，格式: TYPE,CONDITION,DESTINATION',
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
                          const SizedBox(height: 16),
                          Text(
                            '规则示例',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              'DOMAIN,example.com,proxy-group-name\nDOMAIN-KEYWORD,youtube,node-name\nIP-CIDR,192.168.0.0/16,DIRECT\nGEOIP,CN,DIRECT',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.7),
                                fontFamily: 'monospace',
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '粘贴或输入规则',
                            style: TextStyle(
                              color: Colors.white,
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
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: '每行一条规则...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15),
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: Colors.green.shade300,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '支持换行符或分号分隔规则',
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
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.7),
                          ),
                          child: const Text('取消'),
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
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          '导入',
                                          style: TextStyle(
                                            color: Colors.white,
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
        XBoardNotification.showInfo('正在更新 Clash 配置...');
        globalState.appController.setupClashConfigDebounce();
        // 等待一下确保配置已应用
        await Future.delayed(const Duration(seconds: 2));
        XBoardNotification.showSuccess('配置已更新');
      } else {
        XBoardNotification.showInfo('Clash 未启动，规则将在启动时生效');
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
      decoration: AppColors.getBackgroundDecoration(),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: const Text('设置'),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          // 可滚动内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // 底部增加 padding 避免被导航栏遮挡
              children: [
                _buildSectionHeader(context, '基础配置', icon: Icons.settings),
                const SizedBox(height: 16),
                _buildIPv6Section(context),
                const SizedBox(height: 12),
                _buildLanProxySection(context),
                const SizedBox(height: 16),
                _buildCampusHostsSection(context),
                const SizedBox(height: 32),
                _buildSectionHeader(context, '自定义规则', icon: Icons.rule),
                const SizedBox(height: 16),
                _buildCustomRulesSection(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildIPv6Section(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
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
                      'IPv6 支持',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '开启后将可以接收 IPv6 流量',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_ipv6Loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Switch(
                  value: _ipv6Enabled,
                  onChanged: _ipv6Loading ? null : (value) {
                    _updateIPv6Setting(value);
                  },
                  activeColor: Colors.green.shade600,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanProxySection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 局域网代理开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '局域网代理',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '允许通过局域网访问代理',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_lanProxyLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Switch(
                  value: _lanProxyEnabled,
                  onChanged: _lanProxyLoading ? null : (value) {
                    _updateLanProxySetting(value);
                  },
                  activeColor: Colors.green.shade600,
                ),
            ],
          ),
        ],
      ),
    );
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
            
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
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
                                  '校园网 Hosts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${hosts.length} 条穿透规则',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _campusHostsEnabled,
                            onChanged: _campusHostsLoading
                                ? null
                                : (value) async {
                                    setState(() => _campusHostsLoading = true);
                                    try {
                                      if (value) {
                                        await applyCampusHosts(ref, hosts);
                                        XBoardNotification.showSuccess('校园网 Hosts 已启用');
                                      } else {
                                        await clearCampusHosts(ref, hosts);
                                        XBoardNotification.showSuccess('校园网 Hosts 已禁用');
                                      }
                                      if (mounted) {
                                        setState(() => _campusHostsEnabled = value);
                                      }
                                    } catch (e) {
                                      XBoardNotification.showError('操作失败');
                                    } finally {
                                      if (mounted) {
                                        setState(() => _campusHostsLoading = false);
                                      }
                                    }
                                  },
                            activeColor: Colors.green.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '不使用或者不需要突破时请关闭校园网穿透',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
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
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '加载校园网配置中...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          error: (error, stack) => Text(
            '加载校园网配置失败',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomRulesSection(BuildContext context) {
    final theme = Theme.of(context);
    final customRules = ref.watch(patchClashConfigProvider.select((state) => state.customRules));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 批量导入按钮
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: FilledButton.tonal(
                  onPressed: _showImportDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file, size: 16),
                      SizedBox(width: 6),
                      Text('批量导入'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 规则列表
        if (customRules.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            child: Center(
              child: Text(
                '暂无规则',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            constraints: const BoxConstraints(
              maxHeight: 400,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withOpacity(0.1),
                height: 1,
              ),
              itemCount: customRules.length,
              itemBuilder: (_, index) {
                final rule = customRules[index];
                // 解析规则: TYPE,CONDITION,DESTINATION
                final parts = rule.split(',');
                final displayRule = parts.length >= 3 
                    ? '${parts[0]}, ${parts[1]}, ${parts.skip(2).join(',').trim()}'
                    : rule;
                
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayRule,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rule.length > 60 ? '${rule.substring(0, 60)}...' : rule,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade300,
                          size: 20,
                        ),
                        tooltip: '删除规则',
                        onPressed: () {
                          _removeCustomRule(rule);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (customRules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  _clearAllRules();
                },
                icon: const Icon(Icons.delete_sweep),
                label: const Text('清除所有规则'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
      ],
    );
  }
}
