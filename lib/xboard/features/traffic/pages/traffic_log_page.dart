import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/traffic/providers/traffic_log_provider.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:intl/intl.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/l10n/l10n.dart';

class TrafficLogPage extends ConsumerWidget {
  const TrafficLogPage({super.key});

  Map<String, dynamic> _formatBytesWithUnit(int bytes) {
    if (bytes < 1024) {
      return {'value': bytes.toString(), 'unit': 'B'};
    }
    if (bytes < 1024 * 1024) {
      return {'value': (bytes / 1024).toStringAsFixed(2), 'unit': 'KB'};
    }
    if (bytes < 1024 * 1024 * 1024) {
      return {'value': (bytes / 1024 / 1024).toStringAsFixed(2), 'unit': 'MB'};
    }
    return {
      'value': (bytes / 1024 / 1024 / 1024).toStringAsFixed(2),
      'unit': 'GB'
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(trafficLogProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: AppColors.getBackgroundDecoration(),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: Text(AppLocalizations.of(context).xboardTrafficDetails),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            centerTitle: true,
          ),
          // 可滚动内容
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.data_usage_outlined,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无流量记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      16, 8, 16, 100), // 增加底部 padding 避免被导航栏遮挡
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogCard(context, log);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '加载失败',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$err',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, TrafficLog log) {
    final primary = Theme.of(context).colorScheme.primary;
    final date = DateTime.fromMillisecondsSinceEpoch(log.recordAt * 1000);
    final total = log.upload + log.download;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday =
        date.difference(now).inDays == -1 && date.day == now.day - 1;

    String formatDate() {
      if (isToday) {
        return '今天 ${DateFormat('HH:mm').format(date)}';
      } else if (isYesterday) {
        return '昨天 ${DateFormat('HH:mm').format(date)}';
      }
      return DateFormat('MM-dd HH:mm').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                formatDate(),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '×${log.serverRate}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrafficItem(
                context,
                Icons.arrow_upward_rounded,
                '上传',
                log.upload,
                const Color(0xFFFFB86B),
              ),
              const _TrafficDivider(),
              _buildTrafficItem(
                context,
                Icons.arrow_downward_rounded,
                '下载',
                log.download,
                const Color(0xFF5FD3A0),
              ),
              const _TrafficDivider(),
              _buildTrafficItem(
                context,
                Icons.import_export_rounded,
                '总计',
                total,
                primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficItem(
    BuildContext context,
    IconData icon,
    String label,
    int bytes,
    Color color,
  ) {
    final formatted = _formatBytesWithUnit(bytes);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.42),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatted['value'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                formatted['unit'],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.4),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrafficDivider extends StatelessWidget {
  const _TrafficDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}
