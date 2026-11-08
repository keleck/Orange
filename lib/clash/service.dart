import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/state.dart';

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;

  Process? process;

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _initServer();
    reStart();
  }

  _initServer() async {
    runZonedGuarded(() async {
      final address = !Platform.isWindows
          ? InternetAddress(
              unixSocketPath,
              type: InternetAddressType.unix,
            )
          : InternetAddress(
              localhost,
              type: InternetAddressType.IPv4,
            );
      await _deleteSocketFile();
      final server = await ServerSocket.bind(
        address,
        0,
        shared: true,
      );
      serverCompleter.complete(server);
      await for (final socket in server) {
        await _destroySocket();
        socketCompleter.complete(socket);
        socket
            .transform(uint8ListToListIntConverter)
            .transform(utf8.decoder)
            .transform(LineSplitter())
            .listen(
          (data) {
            handleResult(
              ActionResult.fromJson(
                json.decode(data.trim()),
              ),
            );
          },
        );
      }
    }, (error, stack) {
      commonPrint.log(error.toString());
      if (error is SocketException) {
        globalState.showNotifier(error.toString());
        // globalState.appController.restartCore();
      }
    });
  }

  @override
  reStart() async {
    if (isStarting == true) {
      return;
    }
    isStarting = true;
    socketCompleter = Completer();
    if (process != null) {
      await shutdown();
    }
    final serverSocket = await serverCompleter.future;
    final arg = Platform.isWindows
        ? "${serverSocket.port}"
        : serverSocket.address.address;
    if (Platform.isWindows && await system.checkIsAdmin()) {
      final isSuccess = await request.startCoreByHelper(arg);
      if (isSuccess) {
        _watchCoreStart();
        return;
      }
    }
    try {
      process = await Process.start(
        appPath.corePath,
        [
          arg,
        ],
      );
      process?.stdout.listen((_) {});
      process?.stderr.listen((e) {
        final error = utf8.decode(e);
        if (error.isNotEmpty) {
          commonPrint.log(error);
        }
      });
      _watchCoreStart();
    } catch (e, s) {
      commonPrint.log("core start failed: ${appPath.corePath} -> $e");
      globalState.showNotifier("核心启动失败: $e");
      commonPrint.log(s.toString());
    } finally {
      isStarting = false;
    }
  }

  /// 核心启动看门狗：超时未建立连接时给出可诊断的提示
  void _watchCoreStart() {
    Future.delayed(const Duration(seconds: 15), () {
      if (socketCompleter.isCompleted) {
        return;
      }
      commonPrint.log(
        "核心未在 15 秒内建立连接，可能被安全软件拦截、端口被占用或缺少运行库。"
        "路径: ${appPath.corePath}",
      );
      globalState.showNotifier("核心启动失败：请检查是否被安全软件拦截");
    });
  }

  @override
  destroy() async {
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  sendMessage(String message) async {
    // 核心未连接时最多等待 30 秒，避免界面无限转圈
    final socket = await socketCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException("核心未响应（30 秒超时）"),
    );
    socket.writeln(message);
  }

  _deleteSocketFile() async {
    if (!Platform.isWindows) {
      final file = File(unixSocketPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      await lastSocket.close();
      socketCompleter = Completer();
    }
  }

  @override
  shutdown() async {
    if (Platform.isWindows) {
      await request.stopCoreByHelper();
    }
    await _destroySocket();
    process?.kill();
    process = null;
    return true;
  }

  @override
  Future<bool> preload() async {
    await serverCompleter.future;
    return true;
  }
}

final clashService = system.isDesktop ? ClashService() : null;
