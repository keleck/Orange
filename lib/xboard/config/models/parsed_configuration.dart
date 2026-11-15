import 'panel_configuration.dart';
import 'proxy_info.dart';
import 'websocket_info.dart';
import 'update_info.dart';
import 'online_support_info.dart';
import 'subscription_info.dart';
import 'crisp_info.dart';

/// 解析后的配置数据
///
/// 包含所有类型的配置信息
class ParsedConfiguration {
  final String panelType; // 面板类型：xboard 或 v2board
  final PanelConfiguration panels;
  final List<ProxyInfo> proxies;
  final List<WebSocketInfo> webSockets;
  final List<UpdateInfo> updates;
  final List<OnlineSupportInfo> onlineSupport;
  final CrispInfo? crisp; // Crisp 客服系统配置
  final SubscriptionInfo? subscription;
  final String? telegramDiscussLink; // Telegram 讨论组链接
  final String? websiteUrl; // 官网地址
  final bool showWallet; // 是否显示"我的钱包"按钮
  final bool showGiftCard; // 是否显示"礼品卡兑换"按钮
  final DateTime parsedAt;
  final String sourceHash;
  final ConfigMetadata metadata;
  final Map<String, dynamic>? rawRemoteData; // 原始远程配置数据，用于访问额外字段如 campusHosts

  const ParsedConfiguration({
    required this.panelType,
    required this.panels,
    required this.proxies,
    required this.webSockets,
    required this.updates,
    required this.onlineSupport,
    this.crisp,
    this.subscription,
    this.telegramDiscussLink,
    this.websiteUrl,
    this.showWallet = true,
    this.showGiftCard = true,
    required this.parsedAt,
    required this.sourceHash,
    required this.metadata,
    this.rawRemoteData,
  });

  /// 从JSON创建配置
  factory ParsedConfiguration.fromJson(
    Map<String, dynamic> json,
    String currentProvider,
  ) {
    // 读取面板类型，必填字段
    final panelType = json['panelType'] as String?;
    if (panelType == null || panelType.isEmpty) {
      throw Exception('panelType is required in configuration');
    }

    final panelsData = json['panels'] as Map<String, dynamic>? ?? {};
    final proxyList = json['proxy'] as List<dynamic>? ?? [];
    final wsList = json['ws'] as List<dynamic>? ?? [];
    final updateList = json['update'] as List<dynamic>? ?? [];
    final onlineSupportList = json['onlineSupport'] as List<dynamic>? ?? [];
    final crispData = json['crisp'] as Map<String, dynamic>?;
    final subscriptionData = json['subscription'] as Map<String, dynamic>?;
    final telegramLink = json['telegramDiscussLink'] as String?;
    final websiteLink = json['websiteUrl'] as String?;
    final showWallet = json['showWallet'] as bool? ?? true;
    final showGiftCard = json['showGiftCard'] as bool? ?? true;

    return ParsedConfiguration(
      panelType: panelType, // 面板类型
      panels: PanelConfiguration.fromJson(panelsData, currentProvider),
      proxies: proxyList
          .map((item) => ProxyInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      webSockets: wsList
          .map((item) => WebSocketInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      updates: updateList
          .map((item) => UpdateInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      onlineSupport: onlineSupportList
          .map((item) =>
              OnlineSupportInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      crisp: crispData != null ? CrispInfo.fromJson(crispData) : null,
      subscription: subscriptionData != null
          ? SubscriptionInfo.fromJson(subscriptionData)
          : null,
      telegramDiscussLink: telegramLink,
      websiteUrl: websiteLink,
      showWallet: showWallet,
      showGiftCard: showGiftCard,
      parsedAt: DateTime.now(),
      sourceHash: json.hashCode.toString(),
      metadata: ConfigMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>? ?? {}),
      rawRemoteData: json, // 保存原始远程配置数据
    );
  }

  /// 获取第一个可用的WebSocket URL
  String? get firstWsUrl {
    return webSockets.isNotEmpty ? webSockets.first.url : null;
  }

  /// 获取第一个可用的代理URL
  String? get firstProxyUrl {
    return proxies.isNotEmpty ? proxies.first.url : null;
  }

  /// 获取第一个可用的面板URL
  String? get firstPanelUrl {
    return panels.firstUrl;
  }

  /// 获取第一个可用的更新URL
  String? get firstUpdateUrl {
    return updates.isNotEmpty ? updates.first.url : null;
  }

  /// 获取第一个可用的在线客服API URL
  String? get firstOnlineSupportApiUrl {
    return onlineSupport.isNotEmpty ? onlineSupport.first.apiBaseUrl : null;
  }

  /// 获取第一个可用的在线客服WebSocket URL
  String? get firstOnlineSupportWsUrl {
    return onlineSupport.isNotEmpty ? onlineSupport.first.wsBaseUrl : null;
  }

  /// 获取 Crisp 网站 ID
  String? get crispWebsiteId {
    return crisp?.websiteId;
  }

  /// 检查是否配置了 Crisp 客服系统
  bool get hasCrispSupport {
    return crisp != null && crisp!.isValid;
  }

  /// 获取第一个可用的订阅URL
  String? get firstSubscriptionUrl {
    return subscription?.firstUrl;
  }

  /// 获取第一个支持加密的订阅URL
  String? get firstEncryptSubscriptionUrl {
    return subscription?.firstEncryptUrl?.url;
  }

  /// 构建订阅URL
  String? buildSubscriptionUrl(String token, {bool preferEncrypt = true}) {
    return subscription?.buildSubscriptionUrl(token,
        forceEncrypt: preferEncrypt);
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'panels': panels.toJson(),
      'proxy': proxies.map((e) => e.toJson()).toList(),
      'ws': webSockets.map((e) => e.toJson()).toList(),
      'update': updates.map((e) => e.toJson()).toList(),
      'onlineSupport': onlineSupport.map((e) => e.toJson()).toList(),
      if (crisp != null) 'crisp': crisp!.toJson(),
      if (subscription != null) 'subscription': subscription!.toJson(),
      if (telegramDiscussLink != null)
        'telegramDiscussLink': telegramDiscussLink,
      if (websiteUrl != null) 'websiteUrl': websiteUrl,
      'showWallet': showWallet,
      'showGiftCard': showGiftCard,
      'parsedAt': parsedAt.toIso8601String(),
      'sourceHash': sourceHash,
      'metadata': metadata.toJson(),
    };
  }

  @override
  String toString() {
    return 'ParsedConfiguration(panels: $panels, proxies: ${proxies.length}, '
        'ws: ${webSockets.length}, updates: ${updates.length}, '
        'onlineSupport: ${onlineSupport.length}, '
        'subscription: ${subscription != null ? subscription!.urls.length : 0})';
  }
}

/// 配置元数据
class ConfigMetadata {
  final List<String> sources;
  final DateTime lastUpdated;
  final String version;
  final Map<String, dynamic> statistics;

  const ConfigMetadata({
    required this.sources,
    required this.lastUpdated,
    required this.version,
    required this.statistics,
  });

  factory ConfigMetadata.fromJson(Map<String, dynamic> json) {
    return ConfigMetadata(
      sources: (json['sources'] as List<dynamic>?)?.cast<String>() ?? [],
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
          DateTime.now(),
      version: json['version'] as String? ?? '1.0.0',
      statistics: json['statistics'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sources': sources,
      'lastUpdated': lastUpdated.toIso8601String(),
      'version': version,
      'statistics': statistics,
    };
  }
}
