import 'dart:async';
import 'dart:math';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('node_quality_service.dart');

/// 节点质量等级（连接后综合延迟 / 抖动 / 丢包评估）
enum NodeQualityLevel {
  /// 未评估或评估中
  unknown,

  /// 差
  poor,

  /// 一般
  fair,

  /// 良
  good,

  /// 优
  excellent,
}

/// 一次节点质量评估的结果
class NodeQuality {
  const NodeQuality({
    required this.level,
    required this.score,
    this.delay,
    this.jitter = 0,
    this.lossRate = 0,
    this.sampledAt,
  });

  /// 等级
  final NodeQualityLevel level;

  /// 综合得分 0~100
  final int score;

  /// 中位延迟（ms），全部采样失败时为空
  final int? delay;

  /// 抖动（采样极差，ms）
  final int jitter;

  /// 丢包率 0~1
  final double lossRate;

  /// 采样时间
  final DateTime? sampledAt;

  bool get isKnown => level != NodeQualityLevel.unknown;

  String get label => switch (level) {
        NodeQualityLevel.excellent => '质量优',
        NodeQualityLevel.good => '质量良',
        NodeQualityLevel.fair => '质量一般',
        NodeQualityLevel.poor => '质量差',
        NodeQualityLevel.unknown => '质量评估中',
      };

  static const unknown = NodeQuality(level: NodeQualityLevel.unknown, score: 0);

  @override
  String toString() =>
      'NodeQuality(${level.name}, score=$score, delay=$delay, jitter=$jitter, '
      'loss=${lossRate.toStringAsFixed(2)})';
}

class _QualityCacheEntry {
  const _QualityCacheEntry(this.quality, this.time);

  final NodeQuality quality;
  final DateTime time;
}

/// 节点质量评估服务。
///
/// 连接成功后对当前节点连续采样若干次，结合中位延迟、抖动与丢包率给出
/// 0~100 的综合评分，用于在节点卡片上展示「质量优 / 良 / 一般 / 差」。
class NodeQualityService {
  static final NodeQualityService _instance = NodeQualityService._internal();

  factory NodeQualityService() => _instance;

  NodeQualityService._internal();

  static const int _sampleCount = 3;
  static const Duration _sampleInterval = Duration(milliseconds: 120);
  static const Duration _sampleTimeout = Duration(seconds: 6);
  static const Duration _cacheTtl = Duration(seconds: 90);

  final Map<String, _QualityCacheEntry> _cache = {};
  final Map<String, Future<NodeQuality>> _inflight = {};

  /// 读取缓存（未过期时），用于首帧直接展示上一次结果
  NodeQuality? peek(String proxyName) {
    final entry = _cache[proxyName];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.time) > _cacheTtl) {
      _cache.remove(proxyName);
      return null;
    }
    return entry.quality;
  }

  /// 评估指定节点质量，同一节点并发调用会复用同一个 Future
  Future<NodeQuality> evaluate(
    String proxyName,
    String testUrl, {
    bool force = false,
  }) {
    if (proxyName.isEmpty || testUrl.isEmpty) {
      return Future.value(NodeQuality.unknown);
    }

    if (!force) {
      final cached = peek(proxyName);
      if (cached != null) return Future.value(cached);
    }

    final running = _inflight[proxyName];
    if (running != null) return running;

    final future = _run(proxyName, testUrl);
    _inflight[proxyName] = future;
    return future.whenComplete(() {
      _inflight.remove(proxyName);
    });
  }

  void invalidate([String? proxyName]) {
    if (proxyName == null) {
      _cache.clear();
      return;
    }
    _cache.remove(proxyName);
  }

  Future<NodeQuality> _run(String proxyName, String testUrl) async {
    final samples = <int?>[];
    for (var i = 0; i < _sampleCount; i++) {
      if (i > 0) {
        await Future.delayed(_sampleInterval);
      }
      samples.add(await _probe(proxyName, testUrl));
      // 连续两次都失败说明节点不可用，不再继续采样
      if (samples.length >= 2 && samples.every((value) => value == null)) {
        break;
      }
    }

    final quality = _score(samples);
    _cache[proxyName] = _QualityCacheEntry(quality, DateTime.now());
    _logger.debug('节点质量评估完成 $proxyName -> $quality');
    return quality;
  }

  Future<int?> _probe(String proxyName, String testUrl) async {
    try {
      final delay = await clashCore
          .getDelay(testUrl, proxyName)
          .timeout(_sampleTimeout);
      final value = delay.value;
      if (value == null || value <= 0) return null;
      return value;
    } catch (e) {
      _logger.debug('节点质量采样失败: $proxyName, $e');
      return null;
    }
  }

  NodeQuality _score(List<int?> samples) {
    final now = DateTime.now();
    final valid = samples.whereType<int>().where((v) => v > 0).toList()..sort();
    final lossRate =
        samples.isEmpty ? 1.0 : 1 - valid.length / samples.length;

    if (valid.isEmpty) {
      return NodeQuality(
        level: NodeQualityLevel.poor,
        score: 0,
        lossRate: 1,
        sampledAt: now,
      );
    }

    final median = valid[valid.length ~/ 2];
    final jitter = valid.length > 1 ? valid.last - valid.first : 0;

    var score = 100.0;

    // 延迟惩罚：60ms 以内不扣分，越往上扣得越快
    if (median > 60) {
      if (median <= 120) {
        score -= (median - 60) * 0.15;
      } else if (median <= 250) {
        score -= 9 + (median - 120) * 0.12;
      } else if (median <= 500) {
        score -= 24.6 + (median - 250) * 0.08;
      } else {
        score -= 44.6 + (median - 500) * 0.04;
      }
    }

    // 抖动惩罚：抖动相对延迟越大扣分越多，最多扣 20 分
    final jitterRatio = jitter / max(median, 1);
    score -= min(20.0, jitterRatio * 40);

    // 丢包惩罚
    score -= lossRate * 55;

    final rounded = score.clamp(0, 100).round();
    final level = switch (rounded) {
      >= 85 => NodeQualityLevel.excellent,
      >= 70 => NodeQualityLevel.good,
      >= 50 => NodeQualityLevel.fair,
      _ => NodeQualityLevel.poor,
    };

    return NodeQuality(
      level: level,
      score: rounded,
      delay: median,
      jitter: jitter,
      lossRate: lossRate,
      sampledAt: now,
    );
  }
}

final nodeQualityService = NodeQualityService();
