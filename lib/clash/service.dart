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

  /// 内核启动失败时记录的原因，用于界面提示。
  String lastCoreError = '';

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _initServer();
    reStart();
    _watchCoreStart();
  }

  /// 内核要主动连回本地端口，连不上就说明没起来。
  ///
  /// 以前这里没有任何兜底：`Process.start` 失败、或进程被安全软件拦掉时，
  /// socket 永远不会连上，界面就只剩一个「正在加载节点」。
  Future<void> _watchCoreStart() async {
    for (var i = 0; i < 3; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (socketCompleter.isCompleted) {
        return;
      }
    }
    if (socketCompleter.isCompleted) {
      return;
    }
    final detail = lastCoreError.isEmpty
        ? '内核进程未连接，可能被安全软件拦截'
        : lastCoreError;
    commonPrint.log('[core] 启动失败: $detail');
    globalState.showNotifier(detail);
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
          lastCoreError = error.trim();
        }
      });
      // 进程起来又立刻退出时，退出码是唯一线索。
      process?.exitCode.then((code) {
        if (code != 0 && !socketCompleter.isCompleted) {
          lastCoreError = '内核进程异常退出，退出码 $code';
          commonPrint.log('[core] $lastCoreError');
        }
      });
    } catch (e) {
      // 文件缺失、权限被拒、被杀软拦截都会走到这里，必须让用户看到。
      lastCoreError = '内核启动失败：$e';
      commonPrint.log('[core] $lastCoreError');
      globalState.showNotifier(lastCoreError);
    }
    isStarting = false;
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
    final socket = await socketCompleter.future;
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
