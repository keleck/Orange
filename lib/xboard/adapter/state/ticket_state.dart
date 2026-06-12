import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

part 'generated/ticket_state.g.dart';

/// 工单状态管理

/// 获取工单列表
@riverpod
Future<List<TicketModel>> getTickets(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.ticket.getTickets();
}

/// 获取单个工单
@riverpod
Future<TicketDetailModel> getTicket(Ref ref, int id) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.ticket.getTicket(id);
}

@riverpod
class TicketController extends _$TicketController {
  @override
  FutureOr<void> build() {}

  Future<void> createTicket({
    required String subject,
    required String message,
    required int level,
  }) async {
    final sdk = await ref.read(xboardSdkProvider.future);
    state = const AsyncLoading();
    try {
      await sdk.ticket.createTicket(subject, message, level);
      // 延迟一下，确保服务端数据已更新
      await Future.delayed(const Duration(milliseconds: 1000));
      ref.invalidate(getTicketsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> replyTicket({
    required int id,
    required String message,
  }) async {
    final sdk = await ref.read(xboardSdkProvider.future);
    state = const AsyncLoading();
    try {
      await sdk.ticket.replyTicket(id, message);
      // 延迟一下，确保服务端数据已更新
      await Future.delayed(const Duration(milliseconds: 1000));
      ref.invalidate(getTicketProvider(id));
      ref.invalidate(getTicketsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> closeTicket(int id) async {
    final sdk = await ref.read(xboardSdkProvider.future);
    state = const AsyncLoading();
    try {
      await sdk.ticket.closeTicket(id);
      ref.invalidate(getTicketsProvider);
      ref.invalidate(getTicketProvider(id));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
