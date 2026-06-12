import 'dart:io';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/payment/pages/plan_purchase_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/glass_container.dart';
import '../services/subscription_status_service.dart';
import 'package:fl_clash/l10n/l10n.dart';
class SubscriptionUsageCard extends ConsumerWidget {
  final DomainSubscription? subscriptionInfo;
  final DomainUser? userInfo;
  final fl_models.SubscriptionInfo? profileSubscriptionInfo;
  const SubscriptionUsageCard({
    super.key,
    this.subscriptionInfo,
    this.userInfo,
    this.profileSubscriptionInfo,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(xboardUserProvider);
    SubscriptionStatusResult? subscriptionStatus;
    if (userState.isAuthenticated && subscriptionInfo != null) {
      subscriptionStatus = subscriptionStatusService.checkSubscriptionStatus(
        userState: userState,
        profileSubscriptionInfo: profileSubscriptionInfo,
      );
    }
    if (profileSubscriptionInfo == null && userInfo == null && subscriptionInfo == null) {
      return _buildEmptyCard(theme, context);
    }
    if (subscriptionStatus != null && 
        (subscriptionStatus.type == SubscriptionStatusType.expired || 
         subscriptionStatus.type == SubscriptionStatusType.exhausted ||
         subscriptionStatus.type == SubscriptionStatusType.noSubscription)) {
      return _buildStatusCard(subscriptionStatus, theme, context);
    }
    return _buildUsageCard(theme, context);
  }
  Widget _buildEmptyCard(ThemeData theme, BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      opacity: 0.05,
      blur: 10,
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).xboardNoSubscriptionInfo,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context).xboardLoginToViewSubscription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildStatusCard(SubscriptionStatusResult statusResult, ThemeData theme, BuildContext context) {
    IconData statusIcon;
    Color statusColor;
    String statusText;
    String statusDetail;
    switch (statusResult.type) {
      case SubscriptionStatusType.noSubscription:
        statusIcon = Icons.card_giftcard;
        statusColor = Colors.blue.shade600;
        statusText = AppLocalizations.of(context).xboardNoAvailableSubscription;
        statusDetail = AppLocalizations.of(context).xboardPurchaseSubscriptionToUse;
        break;
      case SubscriptionStatusType.expired:
        statusIcon = Icons.schedule;
        statusColor = Colors.red.shade600;
        statusText = AppLocalizations.of(context).xboardSubscriptionExpired;
        statusDetail = statusResult.getDetailMessage(context) ?? AppLocalizations.of(context).xboardRenewToContinue;
        break;
      case SubscriptionStatusType.exhausted:
        statusIcon = Icons.data_usage;
        statusColor = Colors.orange.shade600;
        statusText = AppLocalizations.of(context).xboardTrafficExhausted;
        statusDetail = statusResult.getDetailMessage(context) ?? AppLocalizations.of(context).xboardBuyMoreTrafficOrUpgrade;
        break;
      default:
        statusIcon = Icons.info;
        statusColor = theme.colorScheme.primary;
        statusText = statusResult.getMessage(context);
        statusDetail = statusResult.getDetailMessage(context) ?? '';
    }
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      opacity: 0.05,
      blur: 10,
      gradientColors: [
        statusColor.withValues(alpha: 0.05),
        statusColor.withValues(alpha: 0.01),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDetail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Consumer(
                builder: (context, ref, child) {
                  final userState = ref.watch(xboardUserProvider);
                  return IconButton(
                    onPressed: userState.isLoading ? null : () async {
                      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
                    },
                    icon: userState.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: statusColor,
                          ),
                        )
                      : Icon(
                          Icons.refresh,
                          color: statusColor,
                          size: 20,
                        ),
                    tooltip: '刷新订阅信息',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(20, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ],
          ),
          if (statusResult.expiredAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppLocalizations.of(context).xboardExpiryTime}: ${_formatDateTime(statusResult.expiredAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 续费按钮
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await _handleRenewAction(context, ref);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.shopping_bag, size: 18),
                  label: Text(_getRenewButtonText(statusResult.type, context)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  String _getRenewButtonText(SubscriptionStatusType type, BuildContext context) {
    switch (type) {
      case SubscriptionStatusType.noSubscription:
        return AppLocalizations.of(context).xboardPurchasePlan;
      case SubscriptionStatusType.expired:
        return AppLocalizations.of(context).xboardRenewPlan;
      case SubscriptionStatusType.exhausted:
        return AppLocalizations.of(context).xboardPurchaseTraffic;
      default:
        return AppLocalizations.of(context).xboardPurchasePlan;
    }
  }
  
  Future<void> _handleRenewAction(BuildContext context, WidgetRef ref) async {
    // 先尝试从 provider 获取已加载的订阅信息
    var subscriptionInfo = ref.read(subscriptionInfoProvider);
    int? currentPlanId = subscriptionInfo?.planId;
    
    // 如果 planId 为空或为0，则刷新订阅信息
    if (currentPlanId == null || currentPlanId == 0) {
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
      
      // 检查 context 是否仍然有效
      if (!context.mounted) return;
      
      // 重新获取
      subscriptionInfo = ref.read(subscriptionInfoProvider);
      currentPlanId = subscriptionInfo?.planId;
    }
    
    if (currentPlanId != null && currentPlanId != 0) {
      // 确保套餐列表已加载
      var plans = ref.read(xboardSubscriptionProvider);
      if (plans.isEmpty) {
        await ref.read(xboardSubscriptionProvider.notifier).loadPlans();
        plans = ref.read(xboardSubscriptionProvider);
      }
      
      // 再次检查 context 是否仍然有效
      if (!context.mounted) return;
      
      DomainPlan? currentPlan;
      try {
        currentPlan = plans.firstWhere((plan) => plan.id == currentPlanId);
      } catch (e) {
        currentPlan = null;
      }
      
      if (currentPlan != null) {
        // 直接跳转到购买页面（续费）
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlanPurchasePage(plan: currentPlan!),
          ),
        );
        return;
      }
    }
    
    // 检查 context 是否仍然有效
    if (!context.mounted) return;
    
    // 没找到套餐：跳转到套餐列表页面
    context.push('/plans');
  }
  Widget _buildUsageCard(ThemeData theme, BuildContext context) {
    final progress = _getProgressValue();
    final usedTraffic = _getUsedTraffic();
    final totalTraffic = _getTotalTraffic();
    final remainingDays = _calculateRemainingDays();
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      opacity: 0.05,
      blur: 10,
      gradientColors: [
        theme.colorScheme.primary.withValues(alpha: 0.05),
        theme.colorScheme.secondary.withValues(alpha: 0.02),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${(progress * 100).toInt()}% ${AppLocalizations.of(context).xboardUsed}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Consumer(
                builder: (context, ref, child) {
                  final userState = ref.watch(xboardUserProvider);
                  return IconButton(
                    onPressed: userState.isLoading ? null : () async {
                      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
                    },
                    icon: userState.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.refresh,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                    tooltip: '刷新订阅信息',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(20, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutExpo,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(value, theme),
                  ),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildStatItem(
                  icon: Icons.cloud_download,
                  label: AppLocalizations.of(context).xboardUsedTraffic,
                  value: _formatBytes(usedTraffic),
                  subtitle: '/ ${_formatBytes(totalTraffic)}',
                  theme: theme,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.schedule,
                  label: AppLocalizations.of(context).xboardValidityPeriod,
                  value: remainingDays == -1 
                      ? AppLocalizations.of(context).xboardNoExpiration 
                      : '$remainingDays',
                  subtitle: remainingDays == -1 
                      ? '' 
                      : AppLocalizations.of(context).xboardDays,
                  theme: theme,
                ),
              ),
            ],
          ),
          if (remainingDays != -1 && remainingDays <= 5) ...[
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await _handleRenewAction(context, ref);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.shopping_bag, size: 18),
                    label: Text(AppLocalizations.of(context).xboardRenewPlan),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  String _formatBytes(double bytes) {
    if (bytes < 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes;
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    if (size >= 100) {
      return '${size.toStringAsFixed(0)} ${units[unitIndex]}';
    } else if (size >= 10) {
      return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
    } else {
      return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
    }
  }
  int _calculateRemainingDays() {
    // 1. 优先检查 Profile Subscription Info (来自订阅链接头部)
    if (profileSubscriptionInfo != null) {
      // expire 为 0 表示长期有效
      if (profileSubscriptionInfo!.expire == 0) {
        return -1;
      }
      if (profileSubscriptionInfo!.expire != null) {
        final expiredAt = DateTime.fromMillisecondsSinceEpoch(profileSubscriptionInfo!.expire * 1000);
        final now = DateTime.now();
        return expiredAt.difference(now).inDays.clamp(0, double.infinity).toInt();
      }
    }

    // 2. 检查 Domain Subscription Info (来自 API)
    if (subscriptionInfo != null) {
      // expiredAt 为 null 表示长期有效
      if (subscriptionInfo!.expiredAt == null) {
        return -1;
      }
      final now = DateTime.now();
      return subscriptionInfo!.expiredAt!.difference(now).inDays.clamp(0, double.infinity).toInt();
    }

    return 0;
  }
  double _getProgressValue() {
    if (profileSubscriptionInfo != null && profileSubscriptionInfo!.total > 0) {
      final used = profileSubscriptionInfo!.upload + profileSubscriptionInfo!.download;
      return (used / profileSubscriptionInfo!.total).clamp(0.0, 1.0);
    }
    return 0.0;
  }
  double _getUsedTraffic() {
    if (profileSubscriptionInfo != null) {
      return (profileSubscriptionInfo!.upload + profileSubscriptionInfo!.download).toDouble();
    }
    return 0;
  }
  double _getTotalTraffic() {
    if (profileSubscriptionInfo != null && profileSubscriptionInfo!.total > 0) {
      return profileSubscriptionInfo!.total.toDouble();
    }
    return userInfo?.transferLimit?.toDouble() ?? 0;
  }
  Color _getProgressColor(double progress, ThemeData theme) {
    if (progress >= 0.9) {
      return Colors.red.shade400;
    } else if (progress >= 0.7) {
      return Colors.orange.shade400;
    } else {
      return theme.colorScheme.primary;
    }
  }
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}