import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

final ordersProvider =
    FutureProvider.autoDispose<List<DomainOrder>>((ref) async {
  final orderModels = await XBoardSDK.instance.order.getOrders();
  // 按创建时间倒序排列
  orderModels.sort((a, b) =>
      (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return orderModels.map(_mapOrder).toList();
});

final orderControllerProvider = Provider((ref) => OrderController(ref));

class OrderController {
  final Ref _ref;

  OrderController(this._ref);

  Future<bool> cancelOrder(String tradeNo) async {
    try {
      final success = await XBoardSDK.instance.order.cancelOrder(tradeNo);
      // 无论成功与否，都刷新列表以获取最新状态
      // 增加短暂延迟，确保后端数据已更新
      await Future.delayed(const Duration(milliseconds: 200));
      _ref.invalidate(ordersProvider);
      return success;
    } catch (e) {
      // 即使失败也刷新列表
      _ref.invalidate(ordersProvider);
      return false;
    }
  }
}

DomainOrder _mapOrder(OrderModel order) {
  return DomainOrder(
    tradeNo: order.tradeNo ?? '',
    planId: order.planId ?? 0,
    period: order.period ?? '',
    totalAmount: (order.totalAmount ?? 0).toDouble() / 100,
    status: OrderStatus.fromCode(order.status ?? 0),
    planName: order.orderPlan?.name,
    createdAt: order.createdAt ?? DateTime.now(),
  );
}
