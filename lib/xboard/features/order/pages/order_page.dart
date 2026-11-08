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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: _glassmorphicDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.planName ?? '未知套餐',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '¥${order.totalAmount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '订单号: ${order.tradeNo}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    _buildStatusChip(context, order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '创建时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '周期: ${order.period}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (order.status == OrderStatus.pending)
                  TextButton(
                    onPressed: () => _cancelOrder(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    child: const Text('取消订单'),
                  ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _showDetails(context),
                  child: const Text('查看详情'),
                ),
              ],
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassmorphicDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.primary.withValues(alpha: 0.08),
          theme.colorScheme.primary.withValues(alpha: 0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.shadowColor.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: theme.shadowColor.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  BoxDecoration _detailGlassmorphicDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.primary.withValues(alpha: 0.06),
          theme.colorScheme.primary.withValues(alpha: 0.02),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.shadowColor.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}
