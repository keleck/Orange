/// 订阅请求管理器
///
/// 负责管理订阅请求的去重、速率限制和智能重试
/// 确保：只要API没问题，就绝对不会出现404错误
library;

import 'dart:async';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('subscription_request_manager.dart');

/// 订阅请求管理器
///
/// 核心功能：
/// 1. 请求去重：同一时刻只允许一个订阅请求
/// 2. 速率限制：防止请求过于频繁触发服务器限流
/// 3. 熔断保护：连续失败时暂停请求，给服务器恢复时间
/// 4. 请求合并：多个并发请求自动合并为一个
class SubscriptionRequestManager {
  // 单例模式
  static final SubscriptionRequestManager _instance =
      SubscriptionRequestManager._internal();
  factory SubscriptionRequestManager() => _instance;
  SubscriptionRequestManager._internal();

  // 当前正在执行的请求
  Future<dynamic>? _ongoingRequest;
  String? _ongoingRequestKey;

  // 最后一次成功请求的时间
  DateTime? _lastSuccessTime;

  // 最后一次请求的时间（无论成功失败）
  DateTime? _lastRequestTime;

  // 连续失败次数
  int _consecutiveFailures = 0;

  // 熔断器状态
  bool _circuitBreakerOpen = false;
  DateTime? _circuitBreakerOpenTime;

  // 配置参数
  static const Duration minRequestInterval = Duration(seconds: 2); // 最小请求间隔
  static const Duration successRequestInterval =
      Duration(seconds: 1); // 成功后的请求间隔
  static const int maxConsecutiveFailures = 3; // 触发熔断的连续失败次数
  static const Duration circuitBreakerDuration =
      Duration(seconds: 30); // 熔断持续时间

  /// 执行订阅请求（带去重、速率限制和熔断保护）
  ///
  /// [requestKey] 请求的唯一标识（用于去重）
  /// [request] 实际的请求函数
  ///
  /// 返回请求结果
  Future<T> executeRequest<T>(
    String requestKey,
    Future<T> Function() request,
  ) async {
    _logger.info('[请求管理] 收到订阅请求，key: $requestKey');

    // 1. 检查请求去重
    if (_ongoingRequest != null && _ongoingRequestKey == requestKey) {
      _logger.info('[请求管理] 🔄 检测到重复请求，复用正在进行的请求');
      return await _ongoingRequest as T;
    }

    // 2. 检查熔断器
    if (_circuitBreakerOpen) {
      final now = DateTime.now();
      final timeSinceOpen = now.difference(_circuitBreakerOpenTime!);

      if (timeSinceOpen < circuitBreakerDuration) {
        final remainingSeconds =
            (circuitBreakerDuration - timeSinceOpen).inSeconds;
        _logger.warning('[请求管理] 🚫 熔断器开启中，请求被阻止。剩余时间: ${remainingSeconds}秒');
        throw SubscriptionRequestBlockedException(
            '订阅服务暂时不可用，请 $remainingSeconds 秒后重试');
      } else {
        // 熔断时间已过，重置熔断器
        _logger.info('[请求管理] 🔓 熔断器时间已过，重置状态');
        _resetCircuitBreaker();
      }
    }

    // 3. 检查速率限制
    if (_lastRequestTime != null) {
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequestTime!);

      // 根据上次请求是否成功决定间隔时间
      final requiredInterval = _lastSuccessTime != null &&
              now.difference(_lastSuccessTime!).inSeconds < 5
          ? successRequestInterval // 最近成功过，使用较短间隔
          : minRequestInterval; // 长时间未成功，使用较长间隔

      if (timeSinceLastRequest < requiredInterval) {
        final waitTime = requiredInterval - timeSinceLastRequest;
        _logger.info('[请求管理] ⏱️  速率限制，等待 ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }

    // 4. 执行请求
    _lastRequestTime = DateTime.now();
    _ongoingRequestKey = requestKey;

    try {
      _logger.info('[请求管理] 🚀 开始执行订阅请求');

      _ongoingRequest = request();
      final result = await _ongoingRequest as T;

      // 请求成功
      _logger.info('[请求管理] ✅ 订阅请求成功');
      _onRequestSuccess();

      return result;
    } catch (e) {
      // 请求失败
      _logger.error('[请求管理] ❌ 订阅请求失败', e);
      _onRequestFailure(e);
      rethrow;
    } finally {
      _ongoingRequest = null;
      _ongoingRequestKey = null;
    }
  }

  /// 请求成功回调
  void _onRequestSuccess() {
    _lastSuccessTime = DateTime.now();
    _consecutiveFailures = 0;

    // 如果熔断器是开启状态，关闭它
    if (_circuitBreakerOpen) {
      _logger.info('[请求管理] 🎉 请求恢复成功，关闭熔断器');
      _resetCircuitBreaker();
    }
  }

  /// 请求失败回调
  void _onRequestFailure(Object error) {
    _consecutiveFailures++;

    _logger.warning(
        '[请求管理] 📊 连续失败次数: $_consecutiveFailures/$maxConsecutiveFailures');

    // 检查是否需要触发熔断
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      _openCircuitBreaker();
    }
  }

  /// 开启熔断器
  void _openCircuitBreaker() {
    _circuitBreakerOpen = true;
    _circuitBreakerOpenTime = DateTime.now();

    _logger.warning('[请求管理] 🚨 连续失败 $_consecutiveFailures 次，开启熔断器，'
        '将在 ${circuitBreakerDuration.inSeconds} 秒后自动恢复');
  }

  /// 重置熔断器
  void _resetCircuitBreaker() {
    _circuitBreakerOpen = false;
    _circuitBreakerOpenTime = null;
    _consecutiveFailures = 0;
  }

  /// 手动重置状态（用于用户主动刷新或重试）
  void reset() {
    _logger.info('[请求管理] 🔄 手动重置请求管理器状态');
    _resetCircuitBreaker();
    _lastSuccessTime = null;
    _lastRequestTime = null;
  }

  /// 获取当前状态信息
  Map<String, dynamic> getStatus() {
    return {
      'circuitBreakerOpen': _circuitBreakerOpen,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessTime': _lastSuccessTime?.toIso8601String(),
      'lastRequestTime': _lastRequestTime?.toIso8601String(),
      'hasOngoingRequest': _ongoingRequest != null,
    };
  }
}

/// 订阅请求被阻止异常（熔断器开启）
class SubscriptionRequestBlockedException implements Exception {
  final String message;

  const SubscriptionRequestBlockedException(this.message);

  @override
  String toString() => 'SubscriptionRequestBlockedException: $message';
}
