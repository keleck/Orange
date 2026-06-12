import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

final trafficLogProvider = FutureProvider.autoDispose<List<TrafficLog>>((ref) async {
  final sdk = XBoardSDK.instance;
  final userApi = sdk.user;
  if (userApi == null) {
    throw Exception('User API not initialized');
  }
  return await userApi.getTrafficLogs();
});
