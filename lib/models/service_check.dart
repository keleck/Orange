/// 内核 serviceCheck 返回的单条结果。
///
/// [status] 的取值与 core/service_check.go 里的常量一一对应，
/// 不能在单侧随意改写。
class ServiceCheckItem {
  const ServiceCheckItem({
    required this.name,
    required this.status,
    this.region,
    this.delay,
    this.checkedAt,
  });

  final String name;
  final String status;
  final String? region;
  final int? delay;
  final int? checkedAt;

  factory ServiceCheckItem.fromJson(Map<String, dynamic> json) {
    final region = (json['region'] as String?)?.trim();
    return ServiceCheckItem(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'failed',
      region: (region == null || region.isEmpty) ? null : region,
      delay: (json['delay'] as num?)?.toInt(),
      checkedAt: (json['checked-at'] as num?)?.toInt(),
    );
  }

  @override
  String toString() =>
      'ServiceCheckItem($name, $status, region: $region, delay: $delay)';
}

/// 内核 getOutboundIp 返回的原始结果。
///
/// [body] 是原始响应体，由 Dart 侧按 [url] 对应的解析器读取，
/// 这样出口 IP 与归属地来自同一次走代理的请求。
class OutboundIpResult {
  const OutboundIpResult({
    required this.url,
    required this.body,
    this.delay,
    this.error,
  });

  final String url;
  final String body;
  final int? delay;
  final String? error;

  factory OutboundIpResult.fromJson(Map<String, dynamic> json) {
    return OutboundIpResult(
      url: json['url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt(),
      error: json['error'] as String?,
    );
  }
}
