import 'config_entry.dart';

/// Crisp 客服系统配置信息
/// 
/// 用于存储 Crisp 在线客服系统的配置
class CrispInfo extends ConfigEntry {
  /// Crisp 网站 ID
  final String websiteId;

  const CrispInfo({
    required String url,
    required String description,
    required this.websiteId,
    Map<String, dynamic>? metadata,
  }) : super(url: url, description: description, metadata: metadata);

  /// 从 JSON 创建 Crisp 配置信息
  factory CrispInfo.fromJson(Map<String, dynamic> json) {
    return CrispInfo(
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      websiteId: json['websiteId'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'websiteId': websiteId,
    });
    return json;
  }

  /// 检查配置是否有效
  bool get isValid => websiteId.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrispInfo &&
        other.websiteId == websiteId &&
        other.url == url &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(websiteId, url, description);

  @override
  String toString() {
    return 'CrispInfo(websiteId: $websiteId, description: $description)';
  }
}
