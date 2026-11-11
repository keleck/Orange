import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_clash/xboard/features/order/providers/order_provider.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class OrderPage extends ConsumerWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: AppColors.getBackgroundDecoration(),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: const Text('我的订单'),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
          ),
          // 可滚动内容
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(child: Text('暂无订单'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    return ref.refresh(ordersProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: orders.length,
                    padding: const EdgeInsets.only(bottom: 100), // 增加底部 padding 避免被导航栏遮挡
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderCard(order: order);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('加载失败: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final DomainOrder order;

  const _OrderCard({required this.order});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final createdAt = DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(15, 14, 13, 10),
      decoration: _glassmorphicDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.planName ?? '未知套餐',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '¥${order.totalAmount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                createdAt,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.32),
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              _buildStatusChip(context, order.status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '订单号 ${order.tradeNo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.24),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.status == OrderStatus.pending) ...[
                GestureDetector(
                  onTap: () => _cancelOrder(context, ref),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Text(
                      '取消订单',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.45),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              GestureDetector(
                onTap: () => _showDetails(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    '查看详情',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: primary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _glassmorphicDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }

  BoxDecoration _detailGlassmorphicDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  '订单详情',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    _buildStatusIcon(context, order.status),
                    const SizedBox(height: 8),
                    Text(
                      '¥${order.totalAmount}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(context, order.status),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '基本信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: _detailGlassmorphicDecoration(context),
                    child: Column(
                      children: [
                        _buildDetailTile(
                            context, Icons.numbers, '订单号', order.tradeNo,
                            canCopy: true),
                        _buildDetailTile(context, Icons.inventory_2_outlined,
                            '套餐名称', order.planName ?? '未知套餐'),
                        _buildDetailTile(
                            context, Icons.update, '订单周期', order.period),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '时间信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: _detailGlassmorphicDecoration(context),
                    child: Column(
                      children: [
                        _buildDetailTile(
                            context,
                            Icons.access_time,
                            '创建时间',
                            DateFormat('yyyy-MM-dd HH:mm:ss')
                                .format(order.createdAt)),
                        if (order.paidAt != null)
                          _buildDetailTile(
                              context,
                              Icons.payment,
                              '支付时间',
                              DateFormat('yyyy-MM-dd HH:mm:ss')
                                  .format(order.paidAt!)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, OrderStatus status) {
    IconData icon;
    Color color;
    switch (status) {
      case OrderStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case OrderStatus.pending:
        icon = Icons.pending;
        color = Colors.orange;
        break;
      case OrderStatus.canceled:
        icon = Icons.cancel;
        color = Colors.grey;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }
    return Icon(icon, size: 48, color: color);
  }

  Widget _buildDetailTile(
      BuildContext context, IconData icon, String label, String value,
      {bool canCopy = false}) {
    return ListTile(
      leading:
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      trailing: canCopy
          ? IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制')),
                );
              },
            )
          : null,
    );
  }

  Future<void> _cancelOrder(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订单'),
        content: const Text('确定要取消该订单吗？取消后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('暂不取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success =
          await ref.read(orderControllerProvider).cancelOrder(order.tradeNo);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('订单已取消')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('取消失败，请稍后重试')),
          );
        }
      }
    }
  }

  Widget _buildStatusChip(BuildContext context, OrderStatus status) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = '待支付';
      case OrderStatus.processing:
        color = Colors.blue;
        label = '处理中';
      case OrderStatus.completed:
        color = Colors.green;
        label = '已完成';
      case OrderStatus.canceled:
        color = Colors.grey;
        label = '已取消';
      case OrderStatus.discounted:
        color = Colors.purple;
        label = '已折抵';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
