import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';

import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_checker.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/payment/pages/plan_purchase_page.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/shared/pages/node_selector_page.dart';
import 'package:fl_clash/xboard/features/notice/pages/notice_list_page.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK, NoticeModel;
import 'package:flutter_html/flutter_html.dart';
import 'package:fl_clash/xboard/core/core.dart';
import '../../shared/widgets/glass_container.dart';
import '../widgets/core_status_button.dart';
import '../widgets/subscription_usage_card.dart';
import '../widgets/xboard_connect_button.dart';
import 'package:fl_clash/widgets/app_colors.dart';

final _logger = FileLogger('xboard_home_page.dart');
class XBoardHomePage extends ConsumerStatefulWidget {
  const XBoardHomePage({super.key});
  @override
  ConsumerState<XBoardHomePage> createState() => _XBoardHomePageState();
}
class _XBoardHomePageState extends ConsumerState<XBoardHomePage> 
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late AnimationController _refreshController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _tunLoadingController;
  late AnimationController _nodeLoadingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _nodeLoadingOpacity;
  
  bool _hasInitialized = false;
  bool _hasStartedLatencyTesting = false;
  bool _hasCheckedSubscriptionStatus = false;
  bool _isTunLoading = false;
  bool _showTrafficHint = true;
  bool _isManualRefresh = false;  // 标记是否为手动刷新（仅手动刷新时触发测速）
  
  @override
  bool get wantKeepAlive => true;  // 保持页面状态，防止重建
  
  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
    );
    _tunLoadingController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
    );
    _nodeLoadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _nodeLoadingOpacity = CurvedAnimation(
      parent: _nodeLoadingController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasInitialized) return;
      _hasInitialized = true;
      final userState = ref.read(xboardUserProvider);
      if (userState.isAuthenticated) {
        // 等待订阅导入完成后再检查订阅状态
        _waitForSubscriptionImportThenCheck();
        // 加载首页弹窗通知
        _loadAndShowPopupNotices();
      }
      autoLatencyService.initialize(ref);
      _waitForGroupsAndStartTesting();
      
      // 初始化动画状态
      if (ref.read(runTimeProvider) != null) {
        _pulseController.repeat();
      }
    });
    
    // 监听运行状态控制呼吸动画
    ref.listenManual(runTimeProvider.select((state) => state != null), (prev, isStart) {
      if (isStart) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    ref.listenManual(xboardUserProvider, (previous, next) {
      if (next.errorMessage == 'TOKEN_EXPIRED') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTokenExpiredDialog();
        });
      }
    });
    
    // 监听用户信息变化，如果被封禁则自动退出登录
    ref.listenManual(userInfoProvider, (previous, next) {
      if (next != null && next.banned && (previous?.banned != true)) {
        _logger.info('检测到账号被封禁，执行自动退出登录');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleAccountBanned();
        });
      }
    });
    
    // 监听订阅导入完成事件
    ref.listenManual(profileImportProvider, (previous, next) {
      // 从导入中变为完成（成功或失败）
      if (previous?.isImporting == true && !next.isImporting) {
        if (!_hasCheckedSubscriptionStatus) {
          _hasCheckedSubscriptionStatus = true;
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            subscriptionStatusChecker.checkSubscriptionStatusOnStartup(context, ref);
            // 仅在手动刷新时触发测速
            if (_isManualRefresh) {
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted) {
                  _logger.info('手动刷新导入完成，触发自动测速');
                  _performInitialLatencyTest();
                  _isManualRefresh = false;  // 重置标志
                }
              });
            }
          }
        });
      }
    });
    
    ref.listenManual(currentProfileProvider, (previous, next) {
      if (previous?.label != next?.label && previous != null) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            autoLatencyService.testCurrentNode(forceTest: true);
          }
        });
      }
    });
    ref.listenManual(groupsProvider, (previous, next) {
      if ((previous?.isEmpty ?? true) && next.isNotEmpty && !_hasStartedLatencyTesting) {
        _hasStartedLatencyTesting = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _performInitialLatencyTest();
          }
        });
      }
    });
    
    // 监听订阅有效期变化，当到期时间有变化时重新显示提示
    ref.listenManual(
      subscriptionInfoProvider.select((sub) => sub?.expiredAt),
      (previous, current) {
        // 当到期时间发生变化时，重新显示提示
        if (previous != current && current != null && mounted) {
          // 检查是否即将到期
          final isExpiringSoon = current.difference(DateTime.now()).inDays <= 7;
          if (isExpiringSoon) {
            setState(() => _showTrafficHint = true);
          }
        }
      },
    );
    
    // 监听流量百分比变化，在80%、90%、100%时重新显示提示
    ref.listenManual(
      subscriptionInfoProvider.select((sub) => sub?.usagePercentage),
      (previous, current) {
        if (current == null) return;
        final prevPercentage = previous ?? 0;
        
        // 检查是否跨越了关键阶段：80%、90%、100%
        final reachedStages = <double>[];
        if (prevPercentage < 80 && current >= 80) reachedStages.add(80);
        if (prevPercentage < 90 && current >= 90) reachedStages.add(90);
        if (prevPercentage < 100 && current >= 100) reachedStages.add(100);
        
        // 如果达到了任何关键阶段，重新显示提示
        if (reachedStages.isNotEmpty && mounted) {
          setState(() => _showTrafficHint = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _tunLoadingController.dispose();
    _nodeLoadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // 必须调用，配合 AutomaticKeepAliveClientMixin
    
    // 根据操作系统平台判断设备类型
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 直接返回内容，外层 CommonScaffold 已有统一渐变背景
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: AppColors.getBackgroundDecoration(),
      child: Stack(
        children: [
          Column(
            children: [
              // 整体下移，增加顶部间距（安卓减少间距）
              SizedBox(height: isDesktop ? 220 : 220),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      // 主连接按钮
                      _buildCentralConnectButton(context, ref),
                      const SizedBox(height: 30),
                      // 当前节点卡片
                      _buildCurrentNodeCard(context, ref),
                    ],
                  ),
                ),
              ),
              // 为悬浮导航栏留出空间
              const SizedBox(height: 100), // 增加底部空间避免被导航栏遮挡
            ],
          ),
          // 流量使用提示（顶部中间）
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: _buildTrafficUsageHint(context, ref),
          ),
          // 左上角工单等待回复提醒
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _buildTicketReminder(context, ref),
          ),
          // 右上角通知按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _buildNotificationButton(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, double horizontalPadding) {
    final userInfo = ref.userInfo;
    final theme = Theme.of(context);
    
    if (userInfo == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(50),
            padding: const EdgeInsets.all(2),
            blur: 5,
            opacity: 0.2,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: NetworkImage(userInfo.avatarUrl),
              onBackgroundImageError: (_, __) {},
              child: Text(
                userInfo.email.isNotEmpty ? userInfo.email.substring(0, 1).toUpperCase() : 'U',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).welcomeBack ?? 'Welcome Back',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userInfo.email.split('@').first,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 计算节点是否正在加载
  bool _calculateIsNodeLoading(WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final importState = ref.watch(profileImportProvider);
    
    if (groups.isEmpty || importState.isImporting) {
      return true;
    }
    
    final selectedMap = ref.watch(selectedMapProvider);
    final mode = ref.watch(patchClashConfigProvider.select((state) => state.mode));
    
    Group? currentGroup;
    if (mode == Mode.global) {
      currentGroup = groups.firstWhere(
        (group) => group.name == GroupName.GLOBAL.name,
        orElse: () => groups.first,
      );
    } else if (mode == Mode.rule) {
      for (final group in groups) {
        if (group.hidden == true) continue;
        if (group.name == GroupName.GLOBAL.name) continue;
        final selectedProxyName = selectedMap[group.name];
        if (selectedProxyName != null && selectedProxyName.isNotEmpty) {
          currentGroup = group;
          break;
        }
      }
      if (currentGroup == null) {
        currentGroup = groups.firstWhere(
          (group) => group.hidden != true && group.name != GroupName.GLOBAL.name,
          orElse: () => groups.first,
        );
      }
    }
    
    return currentGroup == null || currentGroup.all.isEmpty;
  }

  // 中央大按钮
  Widget _buildCentralConnectButton(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final isStart = ref.watch(runTimeProvider.select((state) => state != null));
    
    // 检查订阅状态
    final domainSubscription = ref.watch(subscriptionInfoProvider);
    final userState = ref.watch(xboardUserProvider);
    final isExpired = domainSubscription?.isExpired ?? false;
    final isTrafficExhausted = domainSubscription?.isTrafficExhausted ?? false;
    
    // 检查节点加载状态
    final isNodeLoading = _calculateIsNodeLoading(ref);
    
    // 刷新订阅过程中不检查流量和过期状态，避免误导用户
    final isRefreshing = userState.isLoading;
    
    // 如果账号过期、流量耗尽或节点正在加载，禁用连接按钮
    // 但刷新过程中不因为流量或过期状态禁用
    final isDisabled = isRefreshing 
        ? isNodeLoading 
        : (isExpired || isTrafficExhausted || isNodeLoading);
    
    // 节点加载失败时不隐藏按钮，而是显示加载状态
    if (!state.isInit) {
      return Container();
    }

    return GestureDetector(
      onTap: isDisabled ? null : () {
        globalState.appController.updateStatus(!isStart);
      },
      onTapDown: isDisabled ? null : (_) => _scaleController.reverse(),
      onTapUp: isDisabled ? null : (_) => _scaleController.forward(),
      onTapCancel: isDisabled ? null : () => _scaleController.forward(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isStart)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (index) {
                    final delay = index * 0.5;
                    final value = (_pulseController.value + delay) % 1.0;
                    final scale = 1.0 + (value * 0.5); // 1.0 -> 1.5
                    final opacity = (1.0 - value).clamp(0.0, 1.0);
                    
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green.withValues(alpha: opacity * 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isDisabled
                        ? [
                            Colors.grey.shade400,
                            Colors.grey.shade600,
                          ]
                        : isStart
                            ? [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ]
                            : [
                                const Color(0xFF4A5568), // 更亮的灰蓝色
                                const Color(0xFF2D3748), // 中等灰蓝色
                              ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDisabled
                          ? Colors.black.withValues(alpha: 0.2)
                          : isStart 
                              ? Colors.green.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDisabled ? Icons.block : Icons.power_settings_new,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isRefreshing
                          ? '刷新中...'
                          : isNodeLoading
                              ? '加载中...'
                              : isDisabled 
                                  ? (isExpired ? '账号已过期' : '流量已耗尽')
                                  : (isStart ? '已连接' : '未连接'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
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

  // 当前节点卡片
  Widget _buildCurrentNodeCard(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final mode = ref.watch(patchClashConfigProvider.select((state) => state.mode));
    final tunEnable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    final userState = ref.watch(xboardUserProvider);
    final domainSubscription = ref.watch(subscriptionInfoProvider);
    final profileSubscriptionInfo = ref.watch(currentProfileProvider)?.subscriptionInfo;
    final importState = ref.watch(profileImportProvider);
    final subscriptionStatus = subscriptionStatusService.checkSubscriptionStatus(
      userState: userState,
      profileSubscriptionInfo: profileSubscriptionInfo,
      isRefreshing: userState.isLoading,
    );
    // 获取实时流量数据
    final traffics = ref.watch(trafficsProvider);
    final lastTraffic = traffics.length > 0 ? traffics[traffics.length - 1] : null;
    
    // 检查流量是否耗尽（达到100%）
    final bool isTrafficExhausted = domainSubscription?.isTrafficExhausted ?? false;
    
    // 只有真正过期后才显示购买按钮（精确到时间点）
    final bool isExpired = domainSubscription?.isExpired ?? false;
    
    // 检查是否即将过期（7天内）
    final bool isExpiringSoon = domainSubscription?.isExpiringSoon ?? false;
    
    // 流量耗尽且未过期时，显示续费按钮购买流量
    final bool shouldShowPurchaseButton = isExpired || (isTrafficExhausted && !isExpired);
    
    // 只在流量耗尽但账号未过期时，才显示"提前开启流量周期"按钮（作为备选）
    final bool shouldShowFetchTransferButton = false; // 暂时禁用，优先引导用户购买流量
    
    Group? currentGroup;
    String displayName = '未选择';
    
    if (groups.isNotEmpty) {
      if (mode == Mode.global) {
        currentGroup = groups.firstWhere(
          (group) => group.name == GroupName.GLOBAL.name,
          orElse: () => groups.first,
        );
      } else if (mode == Mode.rule) {
        for (final group in groups) {
          if (group.hidden == true) continue;
          if (group.name == GroupName.GLOBAL.name) continue;
          final selectedProxyName = selectedMap[group.name];
          if (selectedProxyName != null && selectedProxyName.isNotEmpty) {
            currentGroup = group;
            break;
          }
        }
        if (currentGroup == null) {
          currentGroup = groups.firstWhere(
            (group) => group.hidden != true && group.name != GroupName.GLOBAL.name,
            orElse: () => groups.first,
          );
        }
      }
      
      if (currentGroup != null) {
        final selectedProxyName = selectedMap[currentGroup.name];
        if (selectedProxyName != null && selectedProxyName.isNotEmpty) {
          displayName = selectedProxyName;
        } else if (currentGroup.now != null && currentGroup.now!.isNotEmpty) {
          displayName = currentGroup.now!;
        }
      }
    }

    final bool isNodeLoading = _calculateIsNodeLoading(ref);
    final bool hasImportError = importState.lastResult?.isSuccess == false;
    final bool isNodeInteractive = !shouldShowPurchaseButton && !isNodeLoading;
    if (isNodeLoading && !_nodeLoadingController.isAnimating) {
      _nodeLoadingController.repeat(reverse: true);
    } else if (!isNodeLoading && _nodeLoadingController.isAnimating) {
      _nodeLoadingController.stop();
      _nodeLoadingController.reset();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 内核状态指示灯：紧挨「规则」按钮，单击重启内核
                      CoreStatusButton(
                        compact: MediaQuery.sizeOf(context).width < 420,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 120,
                        height: 32,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                AnimatedAlign(
                                  alignment: mode == Mode.rule ? Alignment.centerLeft : Alignment.centerRight,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  child: Container(
                                    width: (constraints.maxWidth - 4) / 2,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade600,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: isNodeLoading ? null : () {
                                          globalState.appController.changeMode(Mode.rule);
                                        },
                                        child: Center(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 200),
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: isNodeLoading 
                                                  ? 0.4
                                                  : (mode == Mode.rule ? 1.0 : 0.6),
                                              ),
                                              fontSize: 12,
                                              fontWeight: mode == Mode.rule
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                            child: const Text('规则'),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: isNodeLoading ? null : () {
                                          globalState.appController.changeMode(Mode.global);
                                        },
                                        child: Center(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 200),
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: isNodeLoading 
                                                  ? 0.4
                                                  : (mode == Mode.global ? 1.0 : 0.6),
                                              ),
                                              fontSize: 12,
                                              fontWeight: mode == Mode.global
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                            child: const Text('全局'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (!Platform.isAndroid) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isTunLoading || isNodeLoading ? null : () async {
                            setState(() => _isTunLoading = true);
                            _tunLoadingController.repeat();
                            try {
                              await globalState.appController.updateTun();
                            } finally {
                              if (mounted) {
                                _tunLoadingController.stop();
                                _tunLoadingController.reset();
                                setState(() => _isTunLoading = false);
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isNodeLoading 
                                ? Colors.grey.shade600
                                : _isTunLoading
                                  ? Colors.orange.shade600
                                  : tunEnable 
                                    ? Colors.green.shade600
                                    : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isNodeLoading 
                                  ? Colors.grey.shade400
                                  : _isTunLoading
                                    ? Colors.orange.shade400
                                    : tunEnable 
                                      ? Colors.green.shade400
                                      : Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isNodeLoading 
                                    ? Colors.grey.withValues(alpha: 0.2)
                                    : _isTunLoading
                                      ? Colors.orange.withValues(alpha: 0.4)
                                      : tunEnable 
                                        ? Colors.green.withValues(alpha: 0.4)
                                        : Colors.transparent,
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isTunLoading
                                  ? RotationTransition(
                                      turns: _tunLoadingController,
                                      child: Icon(
                                        Icons.sync_rounded,
                                        size: 14,
                                        color: Colors.white.withValues(
                                          alpha: isNodeLoading ? 0.5 : 1.0,
                                        ),
                                      ),
                                    )
                                  : AnimatedOpacity(
                                      duration: const Duration(milliseconds: 200),
                                      opacity: isNodeLoading ? 0.4 : (tunEnable ? 1.0 : 0.6),
                                      child: const Icon(
                                        Icons.vpn_key_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                const SizedBox(width: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: isNodeLoading ? 0.4 : (_isTunLoading ? 1.0 : (tunEnable ? 1.0 : 0.6))
                                    ),
                                    fontSize: 12,
                                    fontWeight: _isTunLoading || tunEnable 
                                      ? FontWeight.w600 
                                      : FontWeight.w500,
                                  ),
                                  child: Text(_isTunLoading ? '加载中..' : 'TUN'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: RotationTransition(
                    turns: _refreshController,
                    child: IconButton(
                      onPressed: () async {
                        if (_refreshController.isAnimating) return;
                        _refreshController.repeat();
                        try {
                          // 标记为手动刷新，使得导入完成后会触发测速
                          _isManualRefresh = true;
                          // 先断开连接
                          final isStart = ref.read(runTimeProvider.select((state) => state != null));
                          if (isStart) {
                            await globalState.appController.updateStatus(false);
                            // 等待断开连接完成
                            await Future.delayed(const Duration(seconds: 1));
                          }
                          // 然后刷新订阅信息
                          await subscriptionStatusChecker.forceRefreshSubscriptionInfo(
                            context,
                            ref,
                          );
                        } finally {
                          if (context.mounted) {
                            _refreshController.stop();
                            _refreshController.reset();
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 20),
                      color: Colors.white,
                      tooltip: '刷新订阅',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: isNodeInteractive ? () {
            _showProxySelector(context, ref);
          } : null,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpiringSoon 
                  ? const Color.fromARGB(255, 255, 110, 38).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.2),
                width: isExpiringSoon ? 1.5 : 1,
              ),
            ),
            child: shouldShowPurchaseButton
                ? Center(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade600,
                            Colors.blue.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _navigateToPlans(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.card_giftcard_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      domainSubscription?.planId != null && domainSubscription!.planId != 0
                                          ? '续费套餐'
                                          : AppLocalizations.of(context).xboardPurchasePlan,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                if (domainSubscription?.expiredAt != null && isExpired) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '已于 ${_formatExpiredDate(domainSubscription!.expiredAt!)} 到期',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (isTrafficExhausted && !isExpired) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '流量已用尽，续费可获得更多流量',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : shouldShowFetchTransferButton
                    ? Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade600,
                                Colors.orange.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _handleFetchTransfer(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.fast_forward_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          '确定开启下一个流量周期？',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '流量已用尽，可提前透支下月流量',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: hasImportError && groups.isEmpty
                            ? Row(
                                key: const ValueKey('node-error'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    importState.message ?? '获取节点失败',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : isNodeLoading
                            ? Row(
                                key: const ValueKey('node-loading'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FadeTransition(
                                    opacity: _nodeLoadingOpacity,
                                    child: Text(
                                      AppLocalizations.of(context).xboardLoadingNodes,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('node-loaded'),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.public,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 当前节点标签 + 流量显示
                                        Row(
                                          children: [
                                            Text(
                                              '当前节点',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (lastTraffic != null) ...[
                                              const SizedBox(width: 8),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_upward,
                                                    size: 11,
                                                    color: Colors.green.shade400,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    lastTraffic.up.shortShow,
                                                    style: TextStyle(
                                                      color: Colors.green.shade400,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 8),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_downward,
                                                    size: 11,
                                                    color: Colors.blue.shade400,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    lastTraffic.down.shortShow,
                                                    style: TextStyle(
                                                      color: Colors.blue.shade400,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // 节点名称 + 延迟
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (currentGroup != null && displayName != '未选择')
                                              Consumer(
                                                builder: (context, ref, _) {
                                                  final delay = ref.watch(getDelayProvider(
                                                    proxyName: displayName,
                                                    testUrl: currentGroup?.testUrl,
                                                  ));
                                                  
                                                  if (delay == null || delay == 0) return const SizedBox.shrink();
                                                  final delayColor = utils.getDelayColor(delay) ?? Colors.green;
                                                  
                                                  return Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: delayColor.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: delayColor.withValues(alpha: 0.3),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '${delay}ms',
                                                      style: TextStyle(
                                                        color: delayColor,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        height: 1.1,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NoticeListPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建工单等待回复提醒按钮
  Widget _buildTicketReminder(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(getTicketsProvider);
    
    return ticketsAsync.when(
      data: (tickets) {
        // 计算等待回复且处理中的工单数量 (reply_status = 1 且 status = 0)
        final pendingCount = tickets
          .where((ticket) => ticket.replyStatus == 1 && ticket.status == 0)
          .length;
        
        // 如果没有等待回复的工单，不显示
        if (pendingCount == 0) {
          return const SizedBox.shrink();
        }
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // 跳转到工单列表页面
                context.go('/user/tickets');
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail_outline,
                      color: Colors.red.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pendingCount.toString(),
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// 构建流量使用提示
  Widget _buildTrafficUsageHint(BuildContext context, WidgetRef ref) {
    final domainSubscription = ref.watch(subscriptionInfoProvider);
    
    // 计算流量使用百分比
    final trafficPercentage = domainSubscription?.usagePercentage ?? 0;
    final isExpiringSoon = domainSubscription?.isExpiringSoon ?? false;
    
    // 低于70%且不是即将到期，不显示；或用户关闭了提示
    if ((trafficPercentage < 70 && !isExpiringSoon) || !_showTrafficHint) {
      return const SizedBox.shrink();
    }
    
    // 根据条件返回不同的提示
    // 如果即将到期，优先显示到期提示；否则显示流量提示
    final hintData = isExpiringSoon
        ? _getExpiringHint(domainSubscription)
        : _getTrafficHint(trafficPercentage);
    
    return Center(
      child: AnimatedOpacity(
        opacity: _showTrafficHint ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: AnimatedSlide(
          offset: _showTrafficHint ? Offset.zero : const Offset(0, -0.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  hintData['color'].withValues(alpha: 0.2),
                  hintData['color'].withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hintData['color'].withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hintData['color'].withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hintData['icon'],
                      color: hintData['color'],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hintData['title'],
                            style: TextStyle(
                              color: hintData['color'],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hintData['message'],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 右上角关闭按钮
                Positioned(
                  right: -2,
                  top: -4,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _showTrafficHint = false);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 获取即将到期的提示信息
  Map<String, dynamic> _getExpiringHint(DomainSubscription? subscription) {
    if (subscription?.expiredAt == null) {
      return {
        'title': '⏰ 订阅即将到期',
        'message': '请及时续费！',
        'icon': Icons.schedule_rounded,
        'color': Colors.purple,
      };
    }
    
    final now = DateTime.now();
    final expiredAt = subscription!.expiredAt!;
    final difference = expiredAt.difference(now);
    
    // 如果已经过期
    if (difference.isNegative) {
      return {
        'title': '❌ 订阅已过期',
        'message': '您的订阅已过期，请立即续费！',
        'icon': Icons.cancel_rounded,
        'color': Colors.red,
      };
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    
    String timeStr = '';
    if (days > 0) {
      timeStr = '$days 天 $hours 小时 $minutes 分钟';
    } else if (hours > 0) {
      timeStr = '$hours 小时 $minutes 分钟';
    } else {
      timeStr = '$minutes 分钟';
    }
    
    return {
      'title': '⏰ 订阅即将到期',
      'message': '还剩 $timeStr，记得及时续费！',
      'icon': Icons.schedule_rounded,
      'color': Colors.purple,
    };
  }

  /// 根据流量百分比获取提示信息
  Map<String, dynamic> _getTrafficHint(double percentage) {
    if (percentage >= 100) {
      return {
        'title': '💾 流量已用尽！',
        'message': '您的流量已达到100%，赶快续费吧！',
        'icon': Icons.storage_rounded,
        'color': Colors.red,
      };
    } else if (percentage >= 90) {
      return {
        'title': '⚠️ 流量即将耗尽',
        'message': '您的流量已使用90%，请准备续费！',
        'icon': Icons.warning_rounded,
        'color': Colors.orange,
      };
    } else if (percentage >= 80) {
      return {
        'title': '📊 流量使用较多',
        'message': '您的流量已使用80%，注意节省使用哦~',
        'icon': Icons.info_rounded,
        'color': Colors.amber,
      };
    } else {
      return {
        'title': '📡 流量使用中',
        'message': '您的流量已使用70%，还有充足空间~',
        'icon': Icons.cloud_upload_rounded,
        'color': Colors.blue,
      };
    }
  }

  Widget _buildUsageSection() {
    return Consumer(
      builder: (context, ref, child) {
        final userInfo = ref.userInfo;
        final subscriptionInfo = ref.subscriptionInfo;
        final currentProfile = ref.watch(currentProfileProvider);
        return SubscriptionUsageCard(
          subscriptionInfo: subscriptionInfo,
          userInfo: userInfo,
          profileSubscriptionInfo: currentProfile?.subscriptionInfo,
        );
      },
    );
  }
  Widget _buildConnectionSection() {
    return Consumer(
      builder: (context, ref, child) {
        return const XBoardConnectButton(isFloating: false);
      },
    );
  }

  /// 等待订阅导入完成后再检查订阅状态（备用方案）
  /// 如果3秒后还没有触发导入完成监听器，则主动检查
  void _waitForSubscriptionImportThenCheck() async {
    await Future.delayed(const Duration(seconds: 3));
    
    // 如果已经通过监听器检查过了，就不再检查
    if (_hasCheckedSubscriptionStatus) {
      return;
    }
    
    _hasCheckedSubscriptionStatus = true;
    if (mounted) {
      subscriptionStatusChecker.checkSubscriptionStatusOnStartup(context, ref);
    }
  }
  
  void _showTokenExpiredDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(appLocalizations.xboardTokenExpiredTitle),
        content: Text(appLocalizations.xboardTokenExpiredContent),
        actions: [
          TextButton(
            onPressed: () async {
              // 先关闭对话框
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              
              // 在下一帧执行，避免widget已dispose的问题
              if (!mounted) return;
              
              try {
                final userNotifier = ref.read(xboardUserProvider.notifier);
                // 清除错误状态
                userNotifier.clearTokenExpiredError();
                // 处理 Token 过期（清除数据）
                await userNotifier.handleTokenExpired();
                
                // 使用 go_router 导航到登录页（会清除所有路由）
                if (mounted && context.mounted) {
                  context.go('/login');
                }
              } catch (e) {
                _logger.info('处理token过期时出错: $e');
              }
            },
            child: Text(appLocalizations.xboardRelogin),
          ),
        ],
      ),
    );
  }

  /// 处理账号被封禁的情况，自动退出登录
  void _handleAccountBanned() {
    if (!mounted) return;
    
    _logger.info('显示账号被封禁对话框');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('账号已被封禁'),
        content: const Text('您的账号已被封禁，无法继续使用。'),
        actions: [
          TextButton(
            onPressed: () async {
              _logger.info('用户点击确认，执行退出登录');
              
              // 先关闭对话框
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              
              // 检查state widget是否还有效
              if (!mounted) return;
              
              try {
                final userNotifier = ref.read(xboardUserProvider.notifier);
                // 执行退出登录
                await userNotifier.handleTokenExpired();
                _logger.info('退出登录成功');
              } catch (e) {
                _logger.info('退出登录出错: $e');
              }
              
              // 导航到登录页
              if (mounted && context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _waitForGroupsAndStartTesting() {
    if (_hasStartedLatencyTesting) {
      return;
    }
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final groups = ref.read(groupsProvider);
        if (groups.isNotEmpty && !_hasStartedLatencyTesting) {
          timer.cancel();
          _hasStartedLatencyTesting = true;
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _performInitialLatencyTest();
            }
          });
        }
      } catch (e) {
      }
    });
  }
  void _performInitialLatencyTest() {
    if (!mounted) return;
    autoLatencyService.testCurrentNode();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final userState = ref.read(xboardUserProvider);
        if (userState.isAuthenticated) {
          autoLatencyService.testCurrentGroupNodes();
        }
      }
    });
  }

  void _showProxySelector(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NodeSelectorPage(),
      ),
    );
  }

  Future<void> _navigateToPlans(BuildContext context) async {
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final domainSubscription = ref.read(subscriptionInfoProvider);
    final currentPlanId = domainSubscription?.planId;
    
    // 如果有订阅记录（planId），直接跳转到该套餐的购买页面
    if (currentPlanId != null && currentPlanId != 0) {
      // 确保套餐列表已加载
      var plans = ref.read(xboardSubscriptionProvider);
      if (plans.isEmpty) {
        await ref.read(xboardSubscriptionProvider.notifier).loadPlans();
        plans = ref.read(xboardSubscriptionProvider);
      }
      
      DomainPlan? currentPlan;
      try {
        currentPlan = plans.firstWhere((plan) => plan.id == currentPlanId);
      } catch (e) {
        currentPlan = null;
      }
      
      if (currentPlan != null && context.mounted) {
        // 直接导航到购买页面（导入 PlanPurchasePage）
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlanPurchasePage(plan: currentPlan!),
          ),
        );
        return;
      }
    }
    
    // 没有订阅记录或未找到套餐：跳转到套餐列表页面
    if (context.mounted) {
      if (isDesktop) {
        context.go('/plans');
      } else {
        context.push('/plans');
      }
    }
  }

  String _formatExpiredDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
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
        // 刷新用户信息
        await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('流量周期已重置'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('操作失败，请稍后重试'),
            backgroundColor: Colors.red,
          ),
        );
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// 加载并显示首页弹窗通知
  void _loadAndShowPopupNotices() async {
    try {
      final notices = await XBoardSDK.instance.notice.getNotices();
      if (!mounted) return;
      
      final popupNotices = notices.where((notice) => _isPopupNotice(notice)).toList();
      
      if (popupNotices.isNotEmpty) {
        // 延迟显示，确保页面已完全加载
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && context.mounted) {
            _showNextPopupNotice(popupNotices, 0);
          }
        });
      }
    } catch (e) {
      _logger.info('加载首页通知失败: $e');
    }
  }

  /// 检查通知是否为弹窗类型
  bool _isPopupNotice(NoticeModel notice) {
    if (notice.tags == null || notice.tags!.isEmpty) return false;
    return notice.tags!.any((tag) => tag.toLowerCase().contains('弹窗') || tag.toLowerCase().contains('popup'));
  }

  /// 依次显示弹窗通知
  void _showNextPopupNotice(List<NoticeModel> popupNotices, int index) {
    if (index >= popupNotices.length || !mounted) return;
    
    final notice = popupNotices[index];
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth > 600 ? 600 : double.infinity,
                maxHeight: screenHeight * 0.85,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          // 使用统一的背景色
                          AppColors.gradientColor1,
                          AppColors.gradientColor3,
                          AppColors.gradientColor4,
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.blue.withValues(alpha: 0.1),
                        ],
                  stops: isDark ? [0.0, 0.5, 1.0] : null,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? AppColors.gradientColor1.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppColors.gradientColor1.withValues(alpha: 0.6)
                        : Colors.blue.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.surfaceContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              notice.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _formatNoticeDate(notice.createdAt),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          Html(
                            data: notice.content,
                            style: {
                              "body": Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                                fontSize: FontSize(Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14),
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                              ),
                              "p": Style(
                                margin: Margins(top: Margin.zero(), bottom: Margin(8)),
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (index < popupNotices.length - 1) ...[
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                _showNextPopupNotice(popupNotices, index + 1);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '下一条',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '关闭',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
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
            ),
          ),
        ),
      ),
    );
  }

  /// 格式化通知日期
  String _formatNoticeDate(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
} 