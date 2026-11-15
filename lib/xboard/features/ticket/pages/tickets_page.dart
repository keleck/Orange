import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';

class TicketsPage extends ConsumerWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(getTicketsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardMyTickets),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: AppColors.backgroundDecoration(context),
        child: Padding(
          // AppBar 悬浮在 body 之上，顶部留白需等于「状态栏 + 工具栏」
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
          ),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(getTicketsProvider.future),
            child: ticketsAsync.when(
              data: (tickets) {
                final openCount = tickets.where((t) => t.status == 0).length;
                final closedCount = tickets.where((t) => t.status == 1).length;
                final waitingReply =
                    tickets.where((t) => t.replyStatus == 1).length;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderSummary(
                        total: tickets.length,
                        openCount: openCount,
                        closedCount: closedCount,
                        waitingReply: waitingReply,
                      ),
                    ),
                    if (tickets.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 4),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _TicketCard(ticket: tickets[index]),
                            childCount: tickets.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                );
              },
              loading: () => Center(child: CircularProgressIndicator()),
              error: (error, stack) => ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color:
                                AppColors.fg(context).withValues(alpha: 0.25),
                          ),
                          SizedBox(height: 12),
                          Text(
                            appLocalizations.xboardTicketLoadFailed,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  AppColors.fg(context).withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              '$error',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.fg(context)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => ref.invalidate(getTicketsProvider),
                            child:
                                Text(AppLocalizations.of(context).xboardRetry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: _CreateTicketButton(
          onTap: () => context.push('/user/tickets/create'),
        ),
      ),
    );
  }
}

/// 顶部概览：标题 + 三个统计，用竖线分隔而不是三个带框的小块
class _HeaderSummary extends StatelessWidget {
  final int total;
  final int openCount;
  final int closedCount;
  final int waitingReply;

  const _HeaderSummary({
    required this.total,
    required this.openCount,
    required this.closedCount,
    required this.waitingReply,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.cardGradientColors(context, accent: primary),
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.surface(context, 0.07),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.support_agent_rounded, size: 18, color: primary),
                SizedBox(width: 8),
                Text(
                  appLocalizations.xboardTicketOverview,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg(context),
                    decoration: TextDecoration.none,
                  ),
                ),
                Spacer(),
                Text(
                  '共 $total 条',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.fg(context).withValues(alpha: 0.35),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                _StatItem(
                  value: openCount,
                  label: appLocalizations.xboardProcessingStatus,
                  color: primary,
                ),
                const _StatDivider(),
                _StatItem(
                  value: waitingReply,
                  label: appLocalizations.xboardPendingReply,
                  color: const Color(0xFFFFC061),
                ),
                const _StatDivider(),
                _StatItem(
                  value: closedCount,
                  label: AppLocalizations.of(context).xboardClosed,
                  color: AppColors.fg(context).withValues(alpha: 0.45),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.fg(context).withValues(alpha: 0.42),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: AppColors.surface(context, 0.07),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.10),
              border: Border.all(
                color: primary.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              Icons.forum_outlined,
              size: 28,
              color: primary.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: 16),
          Text(
            appLocalizations.xboardNoTickets,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.fg(context),
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 6),
          Text(
            appLocalizations.xboardTicketEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.fg(context).withValues(alpha: 0.4),
              decoration: TextDecoration.none,
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
    final primary = Theme.of(context).colorScheme.primary;
    final statusColor = ticket.status == 0
        ? primary
        : AppColors.fg(context).withValues(alpha: 0.35);
    final messagePreview = (ticket.message ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: AppColors.surface(context, 0.035),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/user/tickets/${ticket.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.surface(context, 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        ticket.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.fg(context),
                          height: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.fg(context).withValues(alpha: 0.22),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '#${ticket.id}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.fg(context).withValues(alpha: 0.32),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.fg(context).withValues(alpha: 0.2),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      _relativeTime(ticket.createdAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.fg(context).withValues(alpha: 0.32),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    if (ticket.level == 2)
                      _MiniTag(
                        label: AppLocalizations.of(context).xboardHighPriority,
                        color: Color(0xFFFF6B6B),
                      ),
                    if (ticket.level == 2) const SizedBox(width: 6),
                    _ReplyTag(replyStatus: ticket.replyStatus),
                  ],
                ),
                if (messagePreview.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    messagePreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.fg(context).withValues(alpha: 0.48),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 高优先级小标签
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 回复状态：等待回复时用琥珀色提醒，已回复保持低调
class _ReplyTag extends StatelessWidget {
  final int replyStatus;

  const _ReplyTag({required this.replyStatus});

  @override
  Widget build(BuildContext context) {
    final isWaiting = replyStatus == 1;
    final color = isWaiting
        ? const Color(0xFFFFC061)
        : AppColors.fg(context).withValues(alpha: 0.32);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isWaiting
              ? Icons.mark_chat_unread_outlined
              : Icons.mark_chat_read_outlined,
          size: 13,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          isWaiting
              ? appLocalizations.xboardAwaitingReply
              : appLocalizations.xboardReplied,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isWaiting ? FontWeight.w600 : FontWeight.w400,
            color: color,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _CreateTicketButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateTicketButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, primary.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text(
              appLocalizations.xboardNewTicket,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.fg(context),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);

  if (difference.inMinutes < 1) return appLocalizations.just;
  if (difference.inHours < 1) return '${difference.inMinutes}分钟前';
  if (difference.inDays < 1) return '${difference.inHours}小时前';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}
