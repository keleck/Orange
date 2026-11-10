import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/core/logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

class ClashCore {
  static ClashCore? _instance;
  late ClashHandlerInterface clashInterface;

  ClashCore._internal() {
    if (Platform.isAndroid) {
      clashInterface = clashLib!;
    } else {
      clashInterface = clashService!;
    }
  }

  factory ClashCore() {
    _instance ??= ClashCore._internal();
    return _instance!;
  }

  Future<bool> preload() {
    return clashInterface.preload();
  }

  static Future<void> initGeo() async {
    final homePath = await appPath.homeDirPath;
    final homeDir = Directory(homePath);
    final isExists = await homeDir.exists();
    if (!isExists) {
      await homeDir.create(recursive: true);
    }
    const geoFileNameList = [
      mmdbFileName,
      geoIpFileName,
      geoSiteFileName,
      asnFileName,
    ];
    try {
      for (final geoFileName in geoFileNameList) {
        final geoFile = File(
          join(homePath, geoFileName),
        );
        final isExists = await geoFile.exists();
        if (isExists) {
          continue;
        }
        final data = await rootBundle.load('assets/data/$geoFileName');
        List<int> bytes = data.buffer.asUint8List();
        await geoFile.writeAsBytes(bytes, flush: true);
      }
    } catch (e) {
      exit(0);
    }
  }

  Future<bool> init() async {
    await initGeo();
    if (globalState.config.appSetting.openLogs) {
      clashCore.startLog();
    } else {
      clashCore.stopLog();
    }
    final homeDirPath = await appPath.homeDirPath;
    return await clashInterface.init(
      InitParams(
        homeDir: homeDirPath,
        version: globalState.appState.version,
      ),
    );
  }

  Future<bool> setState(CoreState state) async {
    return await clashInterface.setState(state);
  }

  shutdown() async {
    await clashInterface.shutdown();
  }

  FutureOr<bool> get isInit => clashInterface.isInit;

  FutureOr<String> validateConfig(String data) {
    return clashInterface.validateConfig(data);
  }

  /// 转换订阅内容为标准Clash YAML格式
  /// 支持 Base64 编码的节点链接列表（如 ss://, vmess://, vless://, trojan://, hysteria2:// 等）
  /// 如果已经是有效的 YAML 格式，直接返回原内容
  /// 如果转换失败，返回空字符串
  FutureOr<String> convertSubscription(String data) {
    return clashInterface.convertSubscription(data);
  }

  Future<String> updateConfig(UpdateParams updateParams) async {
    return await clashInterface.updateConfig(updateParams);
  }

  Future<String> setupConfig(SetupParams setupParams) async {
    return await clashInterface.setupConfig(setupParams);
  }

  // 需要隐藏的节点名称关键词
  static const _hiddenProxyKeywords = [
    'DIRECT',
    'REJECT',
    '剩余流量',
    '套餐到期',
    '过期时间',
    '到期时间',
    '剩余',
    '流量',
    '套餐',
  ];

  // 需要优先显示的节点关键字（自动选择/故障转移等）
  static const _priorityProxyKeywords = [
    '自动选择',
    'auto',
    '故障转移',
    'fallback',
  ];

  // 检查节点名称是否应该被隐藏
  static bool _shouldHideProxy(String? name) {
    if (name == null) return true;
    final nameLower = name.toLowerCase();
    for (final keyword in _hiddenProxyKeywords) {
      if (nameLower.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Future<List<Group>> getProxiesGroups() async {
    final proxies = await clashInterface.getProxies();
    XBoardLogger.info('[groups] getProxies 返回 ${proxies.length} 项');
    if (proxies.isEmpty) return [];

    // 正常情况下 GLOBAL 一定存在，但内核刚启动、配置刚下发时可能还没建好，
    // 直接取 ["all"] 会在 null 上抛 NoSuchMethodError，被上层 catch 吞掉后
    // 节点列表就永远为空。这里做一次退化处理。
    final globalRaw = proxies[UsedProxy.GLOBAL.name];
    final groupNames = <String>[];
    if (globalRaw is Map) {
      groupNames.add(UsedProxy.GLOBAL.name);
      groupNames.addAll(
        (globalRaw["all"] as List? ?? const []).where((e) {
          final proxy = proxies[e];
          return proxy is Map &&
              GroupTypeExtension.valueList.contains(proxy['type']);
        }).cast<String>(),
      );
    } else {
      // 没有 GLOBAL 时扫描全部，至少把已有的策略组列出来
      groupNames.addAll(
        proxies.entries
            .where(
              (entry) =>
                  entry.value is Map &&
                  GroupTypeExtension.valueList.contains(
                    (entry.value as Map)['type'],
                  ),
            )
            .map((entry) => entry.key)
            .cast<String>(),
      );
    }
    if (groupNames.isEmpty) return [];

    final groupsRaw = groupNames.map((groupName) {
      final raw = proxies[groupName];
      if (raw is! Map) return null;
      // 复制一份，避免直接改内核返回的原始结构
      final group = Map<String, dynamic>.from(raw);
      final allProxies = ((group["all"] ?? []) as List)
          .map(
            (name) => proxies[name],
          )
          .where((proxy) {
            if (proxy is! Map) return false;
            // 过滤掉需要隐藏的节点
            return !_shouldHideProxy(proxy['name'] as String?);
          })
          .toList();
      
      // 分离优先级节点和普通节点，保持各自的原始顺序
      final priorityProxies = <dynamic>[];
      final normalProxies = <dynamic>[];
      
      for (final proxy in allProxies) {
        final name = (proxy['name'] as String? ?? '').toLowerCase();
        final isPriority = _priorityProxyKeywords.any((k) => name.contains(k.toLowerCase()));
        if (isPriority) {
          priorityProxies.add(proxy);
        } else {
          normalProxies.add(proxy);
        }
      }
      
      // 优先级节点在前，普通节点在后，各自保持原始顺序。
      // 每个节点都重新转成 Map<String, dynamic>：内核返回的是
      // Map<dynamic, dynamic>，而 Group.fromJson 内部会做
      // `e as Map<String, dynamic>`，不转会直接抛类型转换错误。
      group["all"] = [...priorityProxies, ...normalProxies]
          .map((proxy) => Map<String, dynamic>.from(proxy as Map))
          .toList();
      XBoardLogger.info(
        '[groups] ${group['name']}: 原始 ${((raw['all'] ?? const []) as List).length} 项'
        ' → 过滤后 ${allProxies.length} 项',
      );
      return group;
    }).whereType<Map<String, dynamic>>().toList();
    return groupsRaw
        .map(
          (e) => Group.fromJson(e),
        )
        .toList();
  }

  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    return await clashInterface.changeProxy(changeProxyParams);
  }

  Future<List<Connection>> getConnections() async {
    final res = await clashInterface.getConnections();
    final connectionsData = json.decode(res) as Map;
    final connectionsRaw = connectionsData['connections'] as List? ?? [];
    return connectionsRaw.map((e) => Connection.fromJson(e)).toList();
  }

  closeConnection(String id) {
    clashInterface.closeConnection(id);
  }

  closeConnections() {
    clashInterface.closeConnections();
  }

  resetConnections() {
    clashInterface.resetConnections();
  }

  Future<List<ExternalProvider>> getExternalProviders() async {
    final externalProvidersRawString =
        await clashInterface.getExternalProviders();
    if (externalProvidersRawString.isEmpty) {
      return [];
    }
    return Isolate.run<List<ExternalProvider>>(
      () {
        final externalProviders =
            (json.decode(externalProvidersRawString) as List<dynamic>)
                .map(
                  (item) => ExternalProvider.fromJson(item),
                )
                .toList();
        return externalProviders;
      },
    );
  }

  Future<ExternalProvider?> getExternalProvider(
      String externalProviderName) async {
    final externalProvidersRawString =
        await clashInterface.getExternalProvider(externalProviderName);
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    return ExternalProvider.fromJson(json.decode(externalProvidersRawString));
  }

  Future<String> updateGeoData(UpdateGeoDataParams params) {
    return clashInterface.updateGeoData(params);
  }

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) {
    return clashInterface.sideLoadExternalProvider(
        providerName: providerName, data: data);
  }

  Future<String> updateExternalProvider({
    required String providerName,
  }) async {
    return clashInterface.updateExternalProvider(providerName);
  }

  startListener() async {
    await clashInterface.startListener();
  }

  stopListener() async {
    await clashInterface.stopListener();
  }

  Future<Delay> getDelay(String url, String proxyName) async {
    final data = await clashInterface.asyncTestDelay(url, proxyName);
    return Delay.fromJson(json.decode(data));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final profilePath = await appPath.getProfilePath(id);
    final res = await clashInterface.getConfig(profilePath);
    if (res.isSuccess) {
      // 内核或兜底值可能是 Map<dynamic, dynamic>，直接 as 会抛
      // type '_Map<dynamic, dynamic>' is not a subtype of 'Map<String, dynamic>'
      return Map<String, dynamic>.from(res.data as Map);
    } else {
      throw res.message;
    }
  }

  Future<Traffic> getTraffic() async {
    final trafficString = await clashInterface.getTraffic();
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<IpInfo?> getCountryCode(String ip) async {
    final countryCode = await clashInterface.getCountryCode(ip);
    if (countryCode.isEmpty) {
      return null;
    }
    return IpInfo(
      ip: ip,
      countryCode: countryCode,
    );
  }

  Future<Traffic> getTotalTraffic() async {
    final totalTrafficString = await clashInterface.getTotalTraffic();
    if (totalTrafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(totalTrafficString));
  }

  Future<int> getMemory() async {
    final value = await clashInterface.getMemory();
    if (value.isEmpty) {
      return 0;
    }
    return int.parse(value);
  }

  /// 走 [proxyName] 探测服务可用性。
  ///
  /// [names] 为空表示全部检测；[proxyName] 为空则由内核按规则路由。
  Future<List<ServiceCheckItem>> serviceCheck({
    String proxyName = '',
    List<String> names = const [],
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // serviceCheck 声明为 FutureOr<String>，先归一成 Future 才能挂超时。
    final data = await Future<String>.value(
      clashInterface.serviceCheck(
        json.encode({
          'proxy-name': proxyName,
          'names': names,
          'timeout': timeout.inMilliseconds,
        }),
      ),
    ).timeout(
      // 内核一次 sweep 的预算是单次超时的 6 倍，这里留足余量后兜底，
      // 避免回调丢失时界面永久停在「检测中」。
      const Duration(seconds: 75),
      onTimeout: () => '',
    );
    if (data.isEmpty) {
      return const [];
    }
    try {
      final list = json.decode(data) as List;
      return list
          .whereType<Map>()
          .map((e) => ServiceCheckItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      commonPrint.log('serviceCheck 解析失败: $e');
      return const [];
    }
  }

  /// 走 [proxyName] 请求出口 IP 源，返回第一个可用应答的原始内容。
  Future<OutboundIpResult?> outboundIp({
    String proxyName = '',
    List<String> urls = const [],
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final data = await clashInterface.outboundIp(
      json.encode({
        'proxy-name': proxyName,
        'urls': urls,
        'timeout': timeout.inMilliseconds,
      }),
    );
    if (data.isEmpty) {
      return null;
    }
    try {
      return OutboundIpResult.fromJson(
        (json.decode(data) as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      commonPrint.log('outboundIp 解析失败: $e');
      return null;
    }
  }

  resetTraffic() {
    clashInterface.resetTraffic();
  }

  startLog() {
    clashInterface.startLog();
  }

  stopLog() {
    clashInterface.stopLog();
  }

  requestGc() {
    clashInterface.forceGc();
  }

  destroy() async {
    await clashInterface.destroy();
  }
}

final clashCore = ClashCore();
