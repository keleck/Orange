import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:intl/intl.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';

class TicketDetailPage extends ConsumerStatefulWidget {
  final int ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends ConsumerState<TicketDetailPage> {
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _reply() async {
    if (_replyController.text.isEmpty) return;

    try {
      await ref.read(ticketControllerProvider.notifier).replyTicket(
            id: widget.ticketId,
            message: _replyController.text,
          );
      _replyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).xboardReplySent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回复失败: $e')),
        );
      }
    }
  }

  Future<void> _closeTicket() async {
    try {
      await ref
          .read(ticketControllerProvider.notifier)
          .closeTicket(widget.ticketId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).xboardTicketClosed)),
        );
        // Refresh the ticket detail
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // ignore: unused_result
          ref.refresh(getTicketProvider(widget.ticketId));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('关闭失败: $e')),
        );
      }
    }
  }

  void _showCloseConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).xboardCloseTicket),
        content: Text(AppLocalizations.of(context).xboardCloseTicketConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _closeTicket();
            },
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(getTicketProvider(widget.ticketId));
    final isLoading = ref.watch(ticketControllerProvider).isLoading;
    // 获取底部安全区域和底部导航栏的高度
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardTicketDetails),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          ticketAsync.when(
            data: (ticket) {
              if (ticket.status == 1) {
                // Already closed
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: AppLocalizations.of(context).xboardCloseTicket,
                onPressed: _showCloseConfirmDialog,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Container(
        decoration: AppColors.getBackgroundDecoration(),
        child: Padding(
          // AppBar 悬浮在 body 之上，顶部留白需等于「状态栏 + 工具栏」
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
          ),
          child: ticketAsync.when(
            data: (ticket) {
              // 调试：打印消息列表长度
              debugPrint(
                  'Ticket ID: ${ticket.id}, Messages count: ${ticket.messages.length}');
              if (ticket.messages.isNotEmpty) {
                for (int i = 0; i < ticket.messages.length; i++) {
                  debugPrint('Message $i: ${ticket.messages[i].message}');
                }
              }

              // 计算回复框的实际高度（输入框 + padding + 底部导航栏 + 安全区域）
              final replyBoxHeight = ticket.status != 1
                  ? 72.0 + bottomPadding + 56.0
                  : bottomPadding + 56.0;

              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .refresh(getTicketProvider(widget.ticketId).future),
                      child: ticket.messages.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 16,
                                  bottom: replyBoxHeight + 16),
                              children: [
                                _TicketHeader(ticket: ticket),
                                const SizedBox(height: 32),
                                Center(
                                  child: Text(
                                    '暂无消息',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context).hintColor,
                                        ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 16,
                                  bottom: replyBoxHeight + 16),
                              itemCount:
                                  ticket.messages.length + 1, // +1 for header
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _TicketHeader(ticket: ticket);
                                }
                                final message = ticket.messages[index - 1];
                                return _MessageBubble(message: message);
                              },
                            ),
                    ),
                  ),
                  if (ticket.status != 1) // Not closed
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          8.0, 8.0, 8.0, 8.0 + bottomPadding + 56.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)
                                    .xboardReplyHint,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: isLoading ? null : _reply,
                            icon: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  final TicketDetailModel ticket;

  const _TicketHeader({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusMeta = _statusMeta(ticket.status, theme);
    final levelMeta = _levelMeta(ticket.level, theme);
    final replyMeta = _replyStatusMeta(ticket.replyStatus, theme);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: levelMeta.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: levelMeta.color.withValues(alpha: 0.3)),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: replyMeta.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: replyMeta.color.withValues(alpha: 0.3)),
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

  Widget _buildStatusChip(BuildContext context, _ChipMeta meta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withValues(alpha: 0.3)),
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

class _MessageBubble extends StatelessWidget {
  final TicketMessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final primary = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withValues(alpha: 0.85),
                    primary.withValues(alpha: 0.62),
                  ],
                )
              : null,
          color: isMe ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: isMe ? 0.10 : 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color:
                    isMe ? Colors.white : Colors.white.withValues(alpha: 0.88),
                fontSize: 13.5,
                height: 1.55,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('MM-dd HH:mm').format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.42),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
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
        background: Colors.green.withValues(alpha: 0.08),
        icon: Icons.autorenew,
      );
    case 1:
      return _ChipMeta(
        label: appLocalizations.xboardClosed,
        color: theme.colorScheme.outline,
        background: theme.colorScheme.outline.withValues(alpha: 0.12),
        icon: Icons.check_circle,
      );
    default:
      return _ChipMeta(
        label: appLocalizations.unknown,
        color: theme.colorScheme.primary,
        background: theme.colorScheme.primary.withValues(alpha: 0.12),
        icon: Icons.help_outline,
      );
  }
}

_ChipMeta _levelMeta(int level, ThemeData theme) {
  switch (level) {
    case 0:
      return _ChipMeta(
        label: appLocalizations.xboardLowPriority,
        color: Colors.blueGrey.shade600,
        background: Colors.blueGrey.withValues(alpha: 0.12),
        icon: Icons.low_priority,
      );
    case 1:
      return _ChipMeta(
        label: appLocalizations.xboardMediumPriority,
        color: Colors.orange.shade700,
        background: Colors.orange.withValues(alpha: 0.12),
        icon: Icons.trending_up,
      );
    case 2:
      return _ChipMeta(
        label: appLocalizations.xboardHighPriority,
        color: Colors.red.shade700,
        background: Colors.red.withValues(alpha: 0.12),
        icon: Icons.priority_high,
      );
    default:
      return _ChipMeta(
        label: appLocalizations.xboardUnknownPriority,
        color: theme.colorScheme.primary,
        background: theme.colorScheme.primary.withValues(alpha: 0.12),
        icon: Icons.help_outline,
      );
  }
}

_ChipMeta _replyStatusMeta(int replyStatus, ThemeData theme) {
  switch (replyStatus) {
    case 0:
      return _ChipMeta(
        label: appLocalizations.xboardReplied,
        color: Colors.green.shade700,
        background: Colors.green.withValues(alpha: 0.12),
        icon: Icons.mark_chat_read,
      );
    case 1:
      return _ChipMeta(
        label: appLocalizations.xboardAwaitingReply,
        color: Colors.amber.shade800,
        background: Colors.amber.withValues(alpha: 0.12),
        icon: Icons.mark_chat_unread,
      );
    default:
      return _ChipMeta(
        label: appLocalizations.xboardUnknownReplyStatus,
        color: theme.colorScheme.primary,
        background: theme.colorScheme.primary.withValues(alpha: 0.12),
        icon: Icons.help_outline,
      );
  }
}
