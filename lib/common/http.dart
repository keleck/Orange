import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/utils/url_masker.dart';

class FlClashHttpOverrides extends HttpOverrides {
  static String handleFindProxy(Uri url) {
    if ([localhost].contains(url.host)) {
      return "DIRECT";
    }
    final port = globalState.config.patchClashConfig.mixedPort;
    final isStart = globalState.appState.runTime != null;
    commonPrint.log("find ${UrlMasker.mask(url.toString())} proxy:$isStart");
    if (!isStart) return "DIRECT";
    return "PROXY localhost:$port";
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, __, ___) => true;
    // Dart 的 connectionTimeout 默认是 null，等于无限等待。
    // 遇到 IPv6 优先但不通、TLS 中间盒或企业策略时，握手会既不成功也不失败，
    // 上层虽然有 Future.timeout，但底层 socket 不会断，
    // 表现就是订阅一直「正在加载节点」。给个硬上限让失败可感知。
    client.connectionTimeout = const Duration(seconds: 15);
    client.findProxy = handleFindProxy;
    return client;
  }
}
