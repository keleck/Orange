import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK;
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:fl_clash/xboard/features/update_check/widgets/update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class UserCenterPage extends ConsumerStatefulWidget {
  const UserCenterPage({super.key});

  @override
  ConsumerState<UserCenterPage> createState() => _UserCenterPageState();
}

class _UserCenterPageState extends ConsumerState<UserCenterPage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: AppColors.getBackgroundDecoration(),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: const Text('我的'),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/user/settings'),
              ),
            ],
          ),
          // 可滚动内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // 底部增加 padding 避免被导航栏遮挡
              children: [
              _buildTrafficUsageCard(context),
              const SizedBox(height: 16),
              _buildSectionHeader(context, '快捷入口', icon: Icons.grid_view_rounded),
              const SizedBox(height: 12),
              // 垂直列表样式的快捷入口 - 包装在一个容器中
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.people,
                      title: '邀请好友',
                      subtitle: '邀请好友获得佣金',
                      tone: _TileTone.neutral,
                      onTap: () => context.push('/user/invite'),
                    ),
                    _ActionTile(
                      icon: Icons.receipt_long,
                      title: '订单记录',
                      subtitle: '查看历史订单',
                      tone: _TileTone.neutral,
                      onTap: () => context.push('/user/orders'),
                    ),
                    _ActionTile(
                      icon: Icons.data_usage,
                      title: '流量明细',
                      subtitle: '查看每日流量使用',
                      tone: _TileTone.neutral,
                      onTap: () => context.push('/user/traffic-log'),
                    ),
                    if (XBoardConfig.showWallet)
                      _ActionTile(
                        icon: Icons.account_balance_wallet,
                        title: '我的钱包',
                        subtitle: '余额与充值管理',
                        tone: _TileTone.neutral,
                        onTap: () => context.push('/user/wallet'),
                      ),
                    _ActionTile(
                      icon: Icons.support_agent,
                      title: '我的工单',
                      subtitle: '工单、官网、高阶功能等',
                      tone: _TileTone.neutral,
                      onTap: () => context.push('/user/tickets'),
                    ),
                    _ActionTile(
                      icon: Icons.headset_mic,
                      title: '在线客服',
                      subtitle: '即时咨询与帮助',
                      tone: _TileTone.neutral,
                      onTap: () => context.push('/user/support'),
                    ),
                    if (_shouldShowTelegram())
                      _ActionTile(
                        icon: Icons.telegram,
                        title: 'Telegram 讨论组',
                        subtitle: '加入社区交流讨论',
                        tone: _TileTone.neutral,
                        onTap: () => _openTelegramLink(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildGiftCardSection(context),
              const SizedBox(height: 12),
              _buildWebsiteAndUpdateSection(context),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade500.withOpacity(0.9),
                      Colors.red.shade500.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade500.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const LogoutDialog(),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.18),
                            ),
                            child: const Icon(Icons.logout, size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '退出登录',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '安全退出当前账号',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.9)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildTrafficUsageCard(BuildContext context) {
    // 优先使用 XBoard 用户状态中的订阅信息（实时API数据）
    final domainSubscription = ref.watch(subscriptionInfoProvider);
    
    // 降级使用 Profile 中的订阅信息（Profile Header解析数据）
    final currentProfile = ref.watch(currentProfileProvider);
    final profileSubscriptionInfo = currentProfile?.subscriptionInfo;

    int used = 0;
    int total = 0;
    DateTime? expireDate;
    bool hasData = false;
    int? planId;

    if (domainSubscription != null) {
      used = domainSubscription.uploadedBytes + domainSubscription.downloadedBytes;
      total = domainSubscription.transferLimit;
      expireDate = domainSubscription.expiredAt;
      planId = domainSubscription.planId;
      hasData = true;
    } else if (profileSubscriptionInfo != null) {
      used = profileSubscriptionInfo.upload + profileSubscriptionInfo.download;
      total = profileSubscriptionInfo.total;
      hasData = true;
      if (profileSubscriptionInfo.expire != 0) {
         expireDate = DateTime.fromMillisecondsSinceEpoch(profileSubscriptionInfo.expire * 1000);
      }
    }

    if (!hasData) {
      return const SizedBox.shrink();
    }

    // Handle infinite/unknown total
    final totalStr = total > 0 ? _formatBytes(total.toDouble()) : '∞';
    final usedStr = _formatBytes(used.toDouble());
    
    String expireStr = '长期有效';
    bool isExpired = false;
    bool isExpiringSoon = false;
    
    if (expireDate != null) {
       expireStr = '${expireDate.year}-${expireDate.month.toString().padLeft(2,'0')}-${expireDate.day.toString().padLeft(2,'0')}';
       // check if expired
       final now = DateTime.now();
       if (expireDate.isBefore(now)) {
         expireStr += ' (已过期)';
         isExpired = true;
       } else {
         // Check if expiring within 24 hours
         if (expireDate.difference(now).inHours < 24) {
           isExpiringSoon = true;
           expireStr = '${expireDate.year}-${expireDate.month.toString().padLeft(2,'0')}-${expireDate.day.toString().padLeft(2,'0')} ${expireDate.hour.toString().padLeft(2,'0')}:${expireDate.minute.toString().padLeft(2,'0')}';
         }
       }
    }

    if (isExpired) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        child: Icon(
                          Icons.account_circle,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final userInfo = ref.watch(userInfoProvider);
                            return Text(
                              userInfo?.email ?? '用户账户',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '当前状态',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '无可用套餐',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () {
                if (planId != null) {
                  context.push('/plans?planId=$planId');
                } else {
                  context.push('/plans');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('购买套餐'),
            ),
          ],
        ),
      );
    }
    
    if (isExpiringSoon) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.account_circle,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final userInfo = ref.watch(userInfoProvider);
                      return Text(
                        userInfo?.email ?? '用户账户',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time_filled_rounded, 
                  color: Colors.orange.shade300,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '套餐将在明天过期，请立即续费以免影响使用',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '过期时间',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expireStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () {
                    if (planId != null) {
                      context.push('/plans?planId=$planId');
                    } else {
                      context.push('/plans');
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('续费套餐'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Calculate progress (0.0 to 1.0)
    double progress = total > 0 ? (used / total) : 0.0;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    final theme = Theme.of(context);
    final bool isTrafficWarning = progress >= 1.0; // 流量达到100%
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isTrafficWarning 
            ? Colors.red.withOpacity(0.3)
            : Colors.white.withOpacity(0.15),
          width: isTrafficWarning ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账户',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Consumer(
                      builder: (context, ref, child) {
                        final userInfo = ref.watch(userInfoProvider);
                        return Text(
                          userInfo?.email ?? '用户账户',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: Colors.white.withOpacity(0.1),
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已用流量',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        text: usedStr,
                        style: TextStyle(
                          color: isTrafficWarning 
                            ? Colors.red.shade300
                            : Colors.green.shade300,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                        ),
                        children: [
                          TextSpan(
                            text: ' / $totalStr',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.white.withOpacity(0.15),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '有效期至',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expireStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Animated Progress Bar
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                // Use ClipRRect/AntiAlias or just alignment/width control
                child: FractionallySizedBox(
                  widthFactor: value < 0.01 && value > 0 ? 0.01 : value, // Min width text or logical handling
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isTrafficWarning
                          ? [
                              theme.colorScheme.error.withValues(alpha: 0.6),
                              theme.colorScheme.error,
                            ]
                          : [
                              theme.colorScheme.primary.withValues(alpha: 0.6),
                              theme.colorScheme.primary,
                            ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                         BoxShadow(
                           color: isTrafficWarning
                             ? theme.colorScheme.error.withValues(alpha: 0.25)
                             : theme.colorScheme.primary.withValues(alpha: 0.25),
                           blurRadius: 8,
                           spreadRadius: 0,
                           offset: const Offset(0, 2),
                         ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // 流量预警提示和透支按钮
          if (isTrafficWarning) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '流量即将用尽，可透支下月流量继续使用',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  _handleFetchTransfer(context);
                },
                child: const Text(
                  '提前透支下月流量',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  Widget _buildSectionHeader(BuildContext context, String title, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  bool _shouldShowTelegram() {
    final telegramLink = XBoardConfig.telegramDiscussLink;
    return telegramLink != null && telegramLink.isNotEmpty;
  }

  Future<void> _openTelegramLink(BuildContext context) async {
    final telegramLink = XBoardConfig.telegramDiscussLink;
    if (telegramLink == null || telegramLink.isEmpty) {
      return;
    }
    
    final uri = Uri.parse(telegramLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      XBoardNotification.showError('无法打开链接');
    }
  }

  Widget _buildGiftCardSection(BuildContext context) {
    if (!XBoardConfig.showGiftCard) {
      return const SizedBox.shrink();
    }
    return _GiftCardRedeemWidget();
  }

  Widget _buildTelegramSection(BuildContext context) {
    final telegramLink = XBoardConfig.telegramDiscussLink;
    
    // 如果没有配置 Telegram 链接,则不显示
    if (telegramLink == null || telegramLink.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _ActionTile(
      icon: Icons.telegram,
      title: 'Telegram 讨论组',
      subtitle: '加入社区交流讨论',
      tone: _TileTone.neutral,
      onTap: () async {
        final uri = Uri.parse(telegramLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          XBoardNotification.showError('无法打开链接');
        }
      },
    );
  }

  Widget _buildWebsiteAndUpdateSection(BuildContext context) {
    final websiteUrl = XBoardConfig.websiteUrl;
    final updateState = ref.watch(updateCheckProvider);
    
    return Row(
      children: [
        // 左边：官网地址
        Expanded(
          child: _SmallActionTile(
            icon: Icons.language,
            title: '官网',
            onTap: () async {
              if (websiteUrl == null || websiteUrl.isEmpty) {
                XBoardNotification.showError('未配置官网地址');
                return;
              }
              final uri = Uri.parse(websiteUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                XBoardNotification.showError('无法打开链接');
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // 右边：更新检查
        Expanded(
          child: _SmallActionTile(
            icon: Icons.system_update,
            title: '检查更新',
            badge: updateState.hasUpdate ? '新' : null,
            isLoading: updateState.isChecking,
            onTap: () async {
              await ref.read(updateCheckProvider.notifier).checkForUpdates();
              final state = ref.read(updateCheckProvider);
              if (state.hasUpdate) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => UpdateDialog(state: state),
                  );
                }
              } else if (state.error != null) {
                XBoardNotification.showError('检查更新失败');
              } else {
                XBoardNotification.showSuccess('已是最新版本');
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleFetchTransfer(BuildContext context) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提前开启流量周期'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确认要提前开启下个月的流量周期吗？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '注意事项',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 此操作会立即重置当前流量\n'
                    '• 会影响下次流量重置时间\n'
                    '• 部分套餐可能不支持此功能',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认开启'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 显示加载提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('正在重置流量周期...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final success = await XBoardSDK.instance.user.fetchTransfer();
      
      // 移除加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      if (success && context.mounted) {
        // 刷新订阅信息
        await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
        XBoardNotification.showSuccess('流量周期已重置');
      } else if (context.mounted) {
        XBoardNotification.showError('操作失败，请稍后重试');
      }
    } catch (e) {
      // 移除加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      if (context.mounted) {
        String errorMessage = '操作失败';
        final errorStr = e.toString();
        
        // 提取错误信息
        if (errorStr.contains('Renewal is not allowed')) {
          errorMessage = '当前套餐不支持提前开启流量周期';
        } else if (errorStr.contains('not allowed')) {
          errorMessage = '不允许执行此操作，请检查套餐状态';
        } else if (errorStr.contains('insufficient')) {
          errorMessage = '余额不足，无法执行此操作';
        } else {
          errorMessage = '操作失败: ${errorStr.length > 50 ? errorStr.substring(0, 50) : errorStr}';
        }
        
        XBoardNotification.showError(errorMessage);
      }
    }
  }
}

class _GiftCardRedeemWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GiftCardRedeemWidget> createState() => _GiftCardRedeemWidgetState();
}

class _GiftCardRedeemWidgetState extends ConsumerState<_GiftCardRedeemWidget> {
  bool _isExpanded = false;
  final _codeController = TextEditingController();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeemGiftCard() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      XBoardNotification.showError('请输入礼品卡兑换码');
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      // 调用礼品卡兑换 API
      await XBoardSDK.instance.coupon.redeemGiftCard(code);
      
      if (mounted) {
        XBoardNotification.showSuccess('礼品卡兑换成功！');
        _codeController.clear();
        setState(() => _isExpanded = false);
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError('兑换失败：${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = [
      Colors.white.withOpacity(0.15),
      Colors.white.withOpacity(0.1),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  _CircleIcon(
                    icon: Icons.card_giftcard,
                    background: Colors.white.withOpacity(0.15),
                    iconColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '礼品卡兑换',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '充值余额或解锁权益',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      hintText: '请输入礼品卡兑换码',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixIcon: Icon(Icons.code, color: Colors.white.withOpacity(0.7)),
                    ),
                    style: const TextStyle(color: Colors.white),
                    enabled: !_isRedeeming,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isRedeeming ? null : _redeemGiftCard,
                      child: _isRedeeming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('立即兑换'),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _SmallActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final bool isLoading;
  final VoidCallback onTap;

  const _SmallActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final _TileTone tone;
  final VoidCallback onTap;
  final bool compact;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.tone,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme, tone, danger: danger);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero, // 移除圆角，使其更像列表项
        child: Ink(
          decoration: BoxDecoration(
            gradient: palette.gradient,
            borderRadius: BorderRadius.zero, // 移除圆角
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.05), // 底部分隔线
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          child: Row(
            children: [
              _CircleIcon(
                icon: icon,
                background: palette.iconBackground,
                iconColor: palette.iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: palette.subtextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textColor.withOpacity(0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color? iconColor;

  const _CircleIcon({required this.icon, required this.background, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
      ),
      child: Icon(icon, size: 18, color: iconColor ?? Colors.white),
    );
  }
}

enum _TileTone { neutral, subtle, danger }

class _Palette {
  final Gradient gradient;
  final List<BoxShadow>? shadow;
  final BoxBorder? border;
  final Color textColor;
  final Color subtextColor;
  final Color iconBackground;
  final Color iconColor;

  _Palette({
    required this.gradient,
    required this.textColor,
    required this.subtextColor,
    required this.iconBackground,
    required this.iconColor,
    this.shadow,
    this.border,
  });
}

_Palette _palette(ThemeData theme, _TileTone tone, {bool danger = false}) {
  switch (tone) {
    case _TileTone.danger:
      final base = Colors.red.shade500;
      return _Palette(
        gradient: LinearGradient(
          colors: [base.withOpacity(0.9), base.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shadow: [
          BoxShadow(
            color: base.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        textColor: Colors.white,
        subtextColor: Colors.white.withOpacity(0.85),
        iconBackground: Colors.white.withOpacity(0.18),
        iconColor: Colors.white,
      );
    case _TileTone.subtle:
      return _Palette(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
          ],
        ),
        border: null,
        shadow: null,
        textColor: Colors.white,
        subtextColor: Colors.white.withOpacity(0.6),
        iconBackground: Colors.white.withOpacity(0.12),
        iconColor: Colors.white,
      );
    case _TileTone.neutral:
      return _Palette(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
          ],
        ),
        border: null,
        shadow: null,
        textColor: Colors.white,
        subtextColor: Colors.white.withOpacity(0.6),
        iconBackground: Colors.white.withOpacity(0.12),
        iconColor: Colors.white,
      );
  }
}

