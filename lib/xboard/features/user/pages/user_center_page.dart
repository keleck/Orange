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
import 'package:fl_clash/xboard/features/shared/widgets/app_icon_tile.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';

class UserCenterPage extends ConsumerStatefulWidget {
  const UserCenterPage({super.key});

  @override
  ConsumerState<UserCenterPage> createState() => _UserCenterPageState();
}

class _UserCenterPageState extends ConsumerState<UserCenterPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppColors.backgroundDecoration(context),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: Text(AppLocalizations.of(context).xboardMine),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: () => context.push('/user/settings'),
              ),
            ],
          ),
          // 可滚动内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 100), // 底部增加 padding 避免被导航栏遮挡
              children: [
                _buildTrafficUsageCard(context),
                SizedBox(height: 16),
                _buildSectionHeader(context, appLocalizations.xboardQuickAccess,
                    icon: Icons.grid_view_rounded),
                const SizedBox(height: 12),
                // 垂直列表样式的快捷入口 - 包装在一个容器中
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.fg(context).withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.fg(context).withValues(alpha: 0.07),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.palette_rounded,
                        title: appLocalizations.themeMode,
                        tone: _TileTone.neutral,
                        color: AppIconColors.purple,
                        trailing: const _ThemeModeToggle(),
                        onTap: () {},
                      ),
                      _ActionTile(
                        icon: Icons.people,
                        title: AppLocalizations.of(context).xboardInviteFriends,
                        subtitle: AppLocalizations.of(context)
                            .xboardInviteFriendsEarn,
                        tone: _TileTone.neutral,
                        color: AppIconColors.purple,
                        onTap: () => context.push('/user/invite'),
                      ),
                      _ActionTile(
                        icon: Icons.receipt_long,
                        title: AppLocalizations.of(context).xboardOrderHistory,
                        subtitle:
                            AppLocalizations.of(context).xboardViewOrderHistory,
                        tone: _TileTone.neutral,
                        color: AppIconColors.blue,
                        onTap: () => context.push('/user/orders'),
                      ),
                      _ActionTile(
                        icon: Icons.data_usage,
                        title:
                            AppLocalizations.of(context).xboardTrafficDetails,
                        subtitle:
                            AppLocalizations.of(context).xboardViewDailyUsage,
                        tone: _TileTone.neutral,
                        color: AppIconColors.teal,
                        onTap: () => context.push('/user/traffic-log'),
                      ),
                      if (XBoardConfig.showWallet)
                        _ActionTile(
                          icon: Icons.account_balance_wallet,
                          title: AppLocalizations.of(context).xboardMyWallet,
                          subtitle: AppLocalizations.of(context)
                              .xboardBalanceAndTopup,
                          tone: _TileTone.neutral,
                          color: AppIconColors.blue,
                          onTap: () => context.push('/user/wallet'),
                        ),
                      _ActionTile(
                        icon: Icons.support_agent,
                        title: AppLocalizations.of(context).xboardMyTickets,
                        subtitle:
                            AppLocalizations.of(context).xboardTicketsAndMore,
                        tone: _TileTone.neutral,
                        color: AppIconColors.green,
                        onTap: () => context.push('/user/tickets'),
                      ),
                      _ActionTile(
                        icon: Icons.headset_mic,
                        title: AppLocalizations.of(context).onlineSupport,
                        subtitle:
                            AppLocalizations.of(context).xboardInstantSupport,
                        tone: _TileTone.neutral,
                        color: AppIconColors.purple,
                        onTap: () => context.push('/user/support'),
                      ),
                      if (_shouldShowTelegram())
                        _ActionTile(
                          icon: Icons.telegram,
                          title:
                              AppLocalizations.of(context).xboardTelegramGroup,
                          subtitle:
                              AppLocalizations.of(context).xboardJoinCommunity,
                          tone: _TileTone.neutral,
                          color: AppIconColors.blue,
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
                    color: AppColors.fg(context).withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.fg(context).withValues(alpha: 0.07),
                    ),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appLocalizations.xboardLogout,
                                    style: TextStyle(
                                      color: AppColors.fg(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    appLocalizations.xboardLogoutHint,
                                    style: TextStyle(
                                      color: AppColors.fg(context)
                                          .withOpacity(0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.fg(context).withOpacity(0.9)),
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
    final primary = Theme.of(context).colorScheme.primary;

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
      used =
          domainSubscription.uploadedBytes + domainSubscription.downloadedBytes;
      total = domainSubscription.transferLimit;
      expireDate = domainSubscription.expiredAt;
      planId = domainSubscription.planId;
      hasData = true;
    } else if (profileSubscriptionInfo != null) {
      used = profileSubscriptionInfo.upload + profileSubscriptionInfo.download;
      total = profileSubscriptionInfo.total;
      hasData = true;
      if (profileSubscriptionInfo.expire != 0) {
        expireDate = DateTime.fromMillisecondsSinceEpoch(
          profileSubscriptionInfo.expire * 1000,
        );
      }
    }

    if (!hasData) {
      return const SizedBox.shrink();
    }

    final totalStr = total > 0 ? _formatBytes(total.toDouble()) : '∞';
    final usedStr = _formatBytes(used.toDouble());
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    String expireStr = appLocalizations.infiniteTime;
    bool isExpired = false;
    bool isExpiringSoon = false;
    if (expireDate != null) {
      expireStr =
          '${expireDate.year}-${expireDate.month.toString().padLeft(2, '0')}-${expireDate.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      if (expireDate.isBefore(now)) {
        isExpired = true;
      } else if (expireDate.difference(now).inHours < 24) {
        isExpiringSoon = true;
      }
    }

    final email = ref.watch(userInfoProvider)?.email ??
        appLocalizations.xboardUserAccount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.cardGradientColors(context, accent: primary),
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.fg(context).withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: AppColors.fg(context),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLocalizations.xboardAccount,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.fg(context).withValues(alpha: 0.42),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.fg(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B6B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    appLocalizations.xboardExpired,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B6B),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.fg(context).withValues(alpha: 0.06),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已用流量',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.fg(context).withValues(alpha: 0.42),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            usedStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color:
                                  isExpired ? const Color(0xFFFF6B6B) : primary,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        Text(
                          ' / $totalStr',
                          style: TextStyle(
                            fontSize: 11.5,
                            color:
                                AppColors.fg(context).withValues(alpha: 0.38),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppColors.fg(context).withValues(alpha: 0.07),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLocalizations.xboardValidUntil,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.fg(context).withValues(alpha: 0.42),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isExpiringSoon ? '$expireStr 到期' : expireStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isExpiringSoon
                            ? const Color(0xFFFFC061)
                            : AppColors.fg(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: AppColors.fg(context).withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isExpired ? const Color(0xFFFF6B6B) : primary,
                ),
              ),
            ),
          ],
          if (isExpired || isExpiringSoon) ...[
            const SizedBox(height: 13),
            GestureDetector(
              onTap: () {
                if (planId != null) {
                  context.push('/plans?planId=$planId');
                } else {
                  context.push('/plans');
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  appLocalizations.xboardPurchaseSubscription,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg(context),
                    decoration: TextDecoration.none,
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

  Widget _buildSectionHeader(BuildContext context, String title,
      {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.fg(context)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.fg(context),
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
      XBoardNotification.showError(appLocalizations.xboardCannotOpenLink);
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
      title: AppLocalizations.of(context).xboardTelegramGroup,
      subtitle: AppLocalizations.of(context).xboardJoinCommunity,
      tone: _TileTone.neutral,
      onTap: () async {
        final uri = Uri.parse(telegramLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          XBoardNotification.showError(appLocalizations.xboardCannotOpenLink);
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
            title: AppLocalizations.of(context).xboardWebsite,
            iconColor: AppIconColors.blue,
            onTap: () async {
              if (websiteUrl == null || websiteUrl.isEmpty) {
                XBoardNotification.showError(
                    appLocalizations.xboardWebsiteNotConfigured);
                return;
              }
              final uri = Uri.parse(websiteUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                XBoardNotification.showError(
                    appLocalizations.xboardCannotOpenLink);
              }
            },
          ),
        ),
        SizedBox(width: 12),
        // 右边：更新检查
        Expanded(
          child: _SmallActionTile(
            icon: Icons.system_update,
            title: AppLocalizations.of(context).checkUpdate,
            iconColor: AppIconColors.teal,
            badge:
                updateState.hasUpdate ? appLocalizations.xboardNewBadge : null,
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
                XBoardNotification.showError(
                    appLocalizations.xboardUpdateCheckFailed);
              } else {
                XBoardNotification.showSuccess(
                    appLocalizations.xboardAlreadyLatest);
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
        title: Text(AppLocalizations.of(context).xboardStartDataCycleEarly),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).xboardConfirmStartDataCycle),
            SizedBox(height: 12),
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
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      SizedBox(width: 6),
                      Text(
                        appLocalizations.xboardNotes,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    appLocalizations.xboardResetCycleNotes,
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
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).xboardConfirmStart),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 显示加载提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.fg(context)),
              ),
              SizedBox(width: 12),
              Text(AppLocalizations.of(context).xboardResettingDataCycle),
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
        XBoardNotification.showSuccess(appLocalizations.xboardDataCycleReset);
      } else if (context.mounted) {
        XBoardNotification.showError(
            appLocalizations.xboardOperationFailedRetry);
      }
    } catch (e) {
      // 移除加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (context.mounted) {
        String errorMessage = appLocalizations.xboardOperationFailed;
        final errorStr = e.toString();

        // 提取错误信息
        if (errorStr.contains('Renewal is not allowed')) {
          errorMessage = appLocalizations.xboardCycleNotSupported;
        } else if (errorStr.contains('not allowed')) {
          errorMessage = appLocalizations.xboardOperationNotAllowed;
        } else if (errorStr.contains('insufficient')) {
          errorMessage = '余额不足，无法执行此操作';
        } else {
          errorMessage =
              '操作失败: ${errorStr.length > 50 ? errorStr.substring(0, 50) : errorStr}';
        }

        XBoardNotification.showError(errorMessage);
      }
    }
  }
}

class _GiftCardRedeemWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GiftCardRedeemWidget> createState() =>
      _GiftCardRedeemWidgetState();
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
      XBoardNotification.showError(appLocalizations.xboardEnterGiftCardCode);
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      // 调用礼品卡兑换 API
      await XBoardSDK.instance.coupon.redeemGiftCard(code);

      if (mounted) {
        XBoardNotification.showSuccess(
            appLocalizations.xboardGiftCardRedeemSuccess);
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
      AppColors.fg(context).withOpacity(0.15),
      AppColors.fg(context).withOpacity(0.1),
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
        border: Border.all(color: AppColors.fg(context).withOpacity(0.15)),
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
                  AppIconTile(
                    icon: Icons.card_giftcard,
                    color: AppIconColors.purple,
                    size: 42,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appLocalizations.xboardGiftCardRedeem,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.fg(context),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        appLocalizations.xboardTopupOrUnlock,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.fg(context).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        color: AppColors.fg(context).withOpacity(0.7)),
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
                      fillColor: AppColors.fg(context).withOpacity(0.1),
                      hintText:
                          AppLocalizations.of(context).xboardEnterGiftCardCode,
                      hintStyle: TextStyle(
                          color: AppColors.fg(context).withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.fg(context).withOpacity(0.15)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      prefixIcon: Icon(Icons.code,
                          color: AppColors.fg(context).withOpacity(0.7)),
                    ),
                    style: TextStyle(color: AppColors.fg(context)),
                    enabled: !_isRedeeming,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: AppColors.fg(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isRedeeming ? null : _redeemGiftCard,
                      child: _isRedeeming
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.fg(context),
                              ),
                            )
                          : Text(AppLocalizations.of(context).xboardRedeemNow),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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
  final Color iconColor;

  const _SmallActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
    this.isLoading = false,
    this.iconColor = AppIconColors.blue,
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
            color: AppColors.fg(context).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fg(context).withOpacity(0.15)),
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
                    color: AppColors.fg(context),
                  ),
                )
              else
                AppIconTile(icon: icon, color: iconColor, size: 30),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.fg(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: AppColors.fg(context),
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
  final Color color;
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.tone,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.danger = false,
    this.color = AppIconColors.blue,
    this.trailing,
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
                color: AppColors.fg(context).withOpacity(0.05), // 底部分隔线
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 13,
            horizontal: 14,
          ),
          child: Row(
            children: [
              AppIconTile(
                icon: icon,
                color: color,
                size: 42,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: palette.subtextColor,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right,
                    color: palette.textColor.withOpacity(0.5), size: 20),
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

  const _CircleIcon(
      {required this.icon, required this.background, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: iconColor ?? AppColors.fg(context)),
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
  // 统一成主题色系的浅色图标块，不再按 tone 变出多种彩色渐变
  final primary = theme.colorScheme.primary;
  final isDanger = tone == _TileTone.danger || danger;
  final accent = isDanger ? const Color(0xFFFF6B6B) : primary;
  return _Palette(
    gradient: const LinearGradient(
      colors: [Colors.transparent, Colors.transparent],
    ),
    shadow: null,
    border: null,
    textColor: AppColors.fgOf(theme),
    subtextColor: AppColors.fgOf(theme).withValues(alpha: 0.45),
    iconBackground: accent.withValues(alpha: 0.12),
    iconColor: accent,
  );
}

/// 主题模式三段切换（跟随系统 / 白天 / 夜晚）
class _ThemeModeToggle extends ConsumerWidget {
  const _ThemeModeToggle();

  static const _items = <(ThemeMode, IconData)>[
    (ThemeMode.system, Icons.brightness_auto_rounded),
    (ThemeMode.light, Icons.light_mode_outlined),
    (ThemeMode.dark, Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeSettingProvider.select((s) => s.themeMode));
    final isDark = AppColors.isDark(context);
    final trackColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFF1F5);
    final selectedBg =
        isDark ? Colors.white.withValues(alpha: 0.18) : Colors.white;
    final activeColor = isDark ? Colors.white : const Color(0xFF1B1B1F);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF9AA0A6);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in _items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith(themeMode: item.$1),
                    );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: mode == item.$1 ? selectedBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: mode == item.$1 && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.$2,
                  size: 16,
                  color: mode == item.$1 ? activeColor : inactiveColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
