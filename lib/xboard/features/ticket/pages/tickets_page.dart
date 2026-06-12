import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:intl/intl.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class TicketsPage extends ConsumerWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(getTicketsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('我的工单'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: AppColors.getBackgroundDecoration(),
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(getTicketsProvider.future),
            child: ticketsAsync.when(
              data: (tickets) {
                final openCount = tickets.where((t) => t.status == 0).length;
                final closedCount = tickets.where((t) => t.status == 1).length;
                final waitingReply = tickets.where((t) => t.replyStatus == 1).length;

                if (tickets.isEmpty) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HeaderSummary(
                          openCount: openCount,
                          closedCount: closedCount,
                          waitingReply: waitingReply,
                        ),
                      ),
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      ),
                    ],
                  );
                }

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderSummary(
                        openCount: openCount,
                        closedCount: closedCount,
                        waitingReply: waitingReply,
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ticket = tickets[index];
                        return _TicketCard(ticket: ticket);
                      },
                      childCount: tickets.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // 增加底部空间避免被导航栏遮挡
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: Center(child: Text('加载失败: $error')),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/user/tickets/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final int openCount;
  final int closedCount;
  final int waitingReply;

  const _HeaderSummary({
    required this.openCount,
    required this.closedCount,
    required this.waitingReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.support_agent, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('工单概览', style: textTheme.titleMedium),
                    Text(
                      '查看进度并保持沟通',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatPill(
                  label: '处理中',
                  value: openCount,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: '待回复',
                  value: waitingReply,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: '已关闭',
                  value: closedCount,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '暂无工单',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '遇到问题可以创建工单与客服沟通',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusMeta = _statusMeta(ticket.status, theme);
    final levelMeta = _levelMeta(ticket.level, theme);
    final replyMeta = _replyStatusMeta(ticket.replyStatus, theme);
    final messagePreview = (ticket.message ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/user/tickets/${ticket.id}'),
            borderRadius: BorderRadius.circular(16),
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
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(context, statusMeta),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '工单号: #${ticket.id}',
                          style: theme.textTheme.bodySmall,
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: levelMeta.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: levelMeta.color.withOpacity(0.3)),
                              ),
                              child: Text(
                                '优先级: ${levelMeta.label}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: levelMeta.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: replyMeta.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: replyMeta.color.withOpacity(0.3)),
                              ),
                              child: Text(
                                replyMeta.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: replyMeta.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      messagePreview.isNotEmpty ? messagePreview : '无附加描述',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '创建时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(ticket.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildStatusChip(BuildContext context, _ChipMeta meta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 16, color: meta.color),
          const SizedBox(width: 6),
          Text(
            meta.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: meta.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}



class _ChipMeta {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const _ChipMeta({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });
}

_ChipMeta _statusMeta(int status, ThemeData theme) {
  switch (status) {
    case 0:
      return _ChipMeta(
        label: '处理中',
        color: Colors.green.shade700,
        background: Colors.green.withOpacity(0.08),
        icon: Icons.autorenew,
      );
    case 1:
      return _ChipMeta(
        label: '已关闭',
        color: theme.colorScheme.outline,
        background: theme.colorScheme.outline.withOpacity(0.12),
        icon: Icons.check_circle,
      );
    default:
      return _ChipMeta(
        label: '未知',
        color: theme.colorScheme.primary,
        background: theme.colorScheme.primary.withOpacity(0.12),
        icon: Icons.help_outline,
      );
  }
}

_ChipMeta _levelMeta(int level, ThemeData theme) {
  switch (level) {
    case 0:
      return _ChipMeta(
        label: '低优先级',
        color: Colors.blueGrey.shade600,
        background: Colors.blueGrey.withOpacity(0.12),
        icon: Icons.low_priority,
      );
    case 1:
      return _ChipMeta(
        label: '中优先级',
        color: Colors.orange.shade700,
        background: Colors.orange.withOpacity(0.12),
        icon: Icons.trending_up,
      );
    case 2:
      return _ChipMeta(
        label: '高优先级',
        color: Colors.red.shade700,
        background: Colors.red.withOpacity(0.12),
        icon: Icons.priority_high,
      );
    default:
      return _ChipMeta(
        label: '未知优先级',
        color: theme.colorScheme.primary,
        background: theme.colorScheme.primary.withOpacity(0.12),
        icon: Icons.help_outline,
      );
  }
}

_ChipMeta _replyStatusMeta(int replyStatus, ThemeData theme) {
  switch (replyStatus) {
    case 0:
      return _ChipMeta(
        label: '已回复',
        color: Colors.green.shade700,
        background: Colors.green.withOpacity(0.12),
        icon: Icons.mark_chat_read,
      );
    case 1:
      return _ChipMeta(
        label: '等待回复',
        color: Colors.amber.shade800,
        background: Colors.amber.withOpacity(0.12),
        icon: Icons.mark_chat_unread,
      );
    default:
      return _ChipMeta(
        label: '未知回复状态',
        color: theme.colorScheme.primary,
        background: theme.colorScheme.primary.withOpacity(0.12),
        icon: Icons.help_outline,
      );
  }
}
