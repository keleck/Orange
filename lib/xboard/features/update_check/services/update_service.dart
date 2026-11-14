import 'dart:io';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fl_clash/common/common.dart';

// 初始化文件级日志器
final _logger = FileLogger('update_service.dart');

class UpdateService {
  /// Get the best update server URL from configuration

  /// 获取所有可用的更新服务器URL

  /// 检查更新（使用配置的更新服务器）
  Future<Map<String, dynamic>> checkForUpdatesWithFallback() {
    return checkForUpdates();
  }

  /// 从指定URL检查更新
  Future<Map<String, dynamic>> _checkForUpdatesFromUrl(String serverUrl) async {
    final currentVersion = await getCurrentVersion();
    final platform = _getPlatformName();
    final dio = Dio();
    final requestUrl =
        '$serverUrl/api/v1/check-update?version=$currentVersion&platform=$platform';

    _logger.info('发送更新检查请求: $requestUrl');
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.validateStatus = (status) {
      return status != null && status < 600; // 接受所有小于600的状态码
    };

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      if (kDebugMode) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          _logger.debug('忽略SSL证书验证: $host:$port');
          return true;
        };
      }
      return client;
    };

    final response = await dio.get(
      requestUrl,
      options: Options(
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      final errorMessage =
          appLocalizations.updateCheckServerError(response.statusCode!);
      if (response.statusCode == 530) {
        throw Exception(
            '$errorMessage - ${appLocalizations.updateCheckServerTemporarilyUnavailable}');
      } else {
        throw Exception('$errorMessage: ${response.data}');
      }
    }

    final responseData = response.data as Map<String, dynamic>;
    final latestVersion = responseData["latest_version"]?.toString() ?? "";
    return {
      "currentVersion": currentVersion,
      "latestVersion": latestVersion,
      // 服务端写死 update_available 时也能靠版本号判断
      "hasUpdate": responseData["update_available"] == true ||
          _isNewerVersion(latestVersion, currentVersion),
      "updateUrl": responseData["download_url"]?.toString() ?? "",
      "releaseNotes": responseData["release_notes"]?.toString() ?? "",
      "forceUpdate": responseData["force_update"] == true,
    };
  }

  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// GitHub Releases 仓库，配置的更新服务都不可用时用它兜底
  static const String _githubRepo = 'keleck/Orange';

  /// 检查更新：先按配置顺序试更新服务，全部失败（含 404）再查 GitHub Releases
  Future<Map<String, dynamic>> checkForUpdates() async {
    final currentVersion = await getCurrentVersion();
    final serverUrls = XBoardConfig.allUpdateUrls;

    Object? lastError;
    for (final serverUrl in serverUrls) {
      try {
        _logger.info('尝试更新服务: $serverUrl');
        return await _checkForUpdatesFromUrl(serverUrl);
      } catch (e) {
        _logger.warning('更新服务不可用 $serverUrl: $e');
        lastError = e;
      }
    }

    _logger.info('配置的更新服务均不可用，改用 GitHub Releases');
    try {
      return await _checkFromGithub(currentVersion);
    } catch (e) {
      _logger.error('GitHub 更新检查失败', e);
      throw lastError ?? e;
    }
  }

  /// 直接查 GitHub Releases（api.github.com），按平台挑安装包
  Future<Map<String, dynamic>> _checkFromGithub(String currentVersion) async {
    final dio = Dio(
      BaseOptions(
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': browserUa,
        },
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    final response = await dio.get(
      'https://api.github.com/repos/$_githubRepo/releases/latest',
    );
    final data = response.data as Map<String, dynamic>;

    final tag = (data['tag_name'] ?? '').toString();
    final latestVersion = tag.replaceFirst(RegExp(r'^v'), '');
    final assets = (data['assets'] as List?) ?? const [];
    final patterns = _assetPatterns();

    String? downloadUrl;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = (asset['name'] ?? '').toString();
      if (name.endsWith('.sha256')) continue;
      if (patterns.any(name.contains)) {
        downloadUrl = (asset['browser_download_url'] ?? '').toString();
        break;
      }
    }

    _logger.info('GitHub 最新版本: $latestVersion，下载地址: $downloadUrl');

    return {
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'hasUpdate': _isNewerVersion(latestVersion, currentVersion),
      'updateUrl': downloadUrl ?? (data['html_url'] ?? '').toString(),
      'releaseNotes': (data['body'] ?? '').toString(),
      'forceUpdate': false,
    };
  }

  /// 当前平台该拿哪个安装包（按 Release 资产命名匹配，前者优先）
  List<String> _assetPatterns() {
    if (Platform.isAndroid) {
      return const [
        '-android-arm64-v8a.apk',
        '-android-armeabi-v7a.apk',
        '-android-x86_64.apk',
      ];
    }
    if (Platform.isWindows) {
      return const ['-windows-amd64-setup.exe', '-windows-amd64.zip'];
    }
    if (Platform.isMacOS) {
      return const ['-macos-universal.dmg'];
    }
    if (Platform.isLinux) {
      return const ['-linux-amd64.AppImage'];
    }
    return const [];
  }

  /// 语义化版本比较，忽略 `v` 前缀与构建号
  bool _isNewerVersion(String latest, String current) {
    List<int> parse(String value) {
      return value
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .where((part) => part.isNotEmpty)
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final a = parse(latest);
    final b = parse(current);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  String _getPlatformName() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    if (Platform.isWindows) return "windows";
    if (Platform.isMacOS) return "macos";
    if (Platform.isLinux) return "linux";
    return "unknown";
  }
}
