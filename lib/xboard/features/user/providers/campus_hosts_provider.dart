import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/config/core/service_locator.dart';
import 'package:fl_clash/xboard/config/internal/xboard_config_accessor.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/providers/providers.dart';

final _logger = FileLogger('campus_hosts_provider.dart');

/// 校园网 hosts 提供者
/// 从远程配置中获取 campusHosts 列表
final campusHostsProvider = FutureProvider<List<String>>((ref) async {
  try {
    // 通过 ServiceLocator 获取配置访问器
    final configAccessor = ServiceLocator.get<XBoardConfigAccessor>();
    
    final config = await configAccessor.getConfiguration();
    if (config == null) {
      _logger.warning('Configuration is null');
      return [];
    }

    // 从原始配置数据中获取 campusHosts
    final rawData = config.rawRemoteData;
    if (rawData == null) {
      _logger.warning('Raw remote data not available');
      return [];
    }

    final campusHosts = rawData['campusHosts'] as List<dynamic>?;
    if (campusHosts == null || campusHosts.isEmpty) {
      _logger.info('No campusHosts found in remote config');
      return [];
    }

    // 转换为字符串列表
    final hosts = <String>[];
    for (final host in campusHosts) {
      if (host is String && host.isNotEmpty) {
        hosts.add(host);
      }
    }

    _logger.info('Loaded ${hosts.length} campus hosts from remote config');
    return hosts;
  } catch (e) {
    _logger.error('Failed to load campus hosts', e);
    return [];
  }
});

/// 应用校园网 hosts
/// 将校园网 hosts 添加到 Clash 配置中的 hosts 字段
Future<void> applyCampusHosts(WidgetRef ref, List<String> hosts) async {
  try {
    if (hosts.isEmpty) {
      return;
    }

    // 获取当前 hosts 映射
    final currentHosts = ref.read(patchClashConfigProvider).hosts;
    final updatedHosts = Map<String, String>.from(currentHosts);

    // 解析并添加校园网 hosts
    // 格式: "IP hostname" 例如: "89.185.27.143 yyds2026410.515120123215461.xyz"
    for (final hostEntry in hosts) {
      final parts = hostEntry.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final ip = parts[0];
        final hostname = parts[1];
        updatedHosts[hostname] = ip;
        _logger.debug('Added campus host: $hostname -> $ip');
      }
    }

    // 更新配置
    ref.read(patchClashConfigProvider.notifier).updateState(
      (state) => state.copyWith(hosts: updatedHosts),
    );

    _logger.info('Campus hosts applied successfully');
  } catch (e) {
    _logger.error('Failed to apply campus hosts', e);
  }
}

/// 清除校园网 hosts
/// 从 Clash 配置中删除所有校园网 hosts
Future<void> clearCampusHosts(WidgetRef ref, List<String> campusHosts) async {
  try {
    if (campusHosts.isEmpty) {
      return;
    }

    // 获取当前 hosts 映射
    final currentHosts = ref.read(patchClashConfigProvider).hosts;
    final updatedHosts = Map<String, String>.from(currentHosts);

    // 删除校园网 hosts
    for (final hostEntry in campusHosts) {
      final parts = hostEntry.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final hostname = parts[1];
        updatedHosts.remove(hostname);
        _logger.debug('Removed campus host: $hostname');
      }
    }

    // 更新配置
    ref.read(patchClashConfigProvider.notifier).updateState(
      (state) => state.copyWith(hosts: updatedHosts),
    );

    _logger.info('Campus hosts cleared successfully');
  } catch (e) {
    _logger.error('Failed to clear campus hosts', e);
  }
}
