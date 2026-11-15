import 'dart:ui';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'plan_purchase_page.dart';
import '../widgets/plan_description_widget.dart';
import '../widgets/sliding_filter_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/common/app_localizations.dart';

class PlansView extends ConsumerStatefulWidget {
  const PlansView({super.key});
  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  DomainPlan? _selectedPlan; // 桌面端选中的套餐
  bool _hasCheckedUrlParams = false; // 标记是否已检查URL参数
  int _selectedFilter = 0; // 0: 全部, 1: 周期性, 2: 一次性

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subscriptionNotifier =
          ref.read(xboardSubscriptionProvider.notifier);
      subscriptionNotifier.autoRefreshIfNeeded();

      // 检查URL参数中是否有planId
      _checkUrlParams();
    });
  }

  void _checkUrlParams() {
    // 每次检查前允许重置检查状态，前提是plan列表有变化等情况
    // 但为了避免死循环，这里只在列表非空时才认为是一次有效检查

    // 获取URL参数
    final state = GoRouterState.of(context);
    final planIdStr = state.uri.queryParameters['planId'];

    // 如果没有参数，直接返回，不做任何操作
    if (planIdStr == null) {
      _hasCheckedUrlParams = true;
      return;
    }

    // 如果已经检查过且当前有选中的套餐，说明已经处理过了，跳过
    if (_hasCheckedUrlParams && _selectedPlan != null) return;

    final planId = int.tryParse(planIdStr);
    if (planId == null) {
      _hasCheckedUrlParams = true;
      return;
    }

    // 尝试查找对应的套餐
    final plans = ref.read(xboardSubscriptionProvider);

    // 如果套餐列表为空，直接返回，等待列表加载后重试
    if (plans.isEmpty) return;

    _hasCheckedUrlParams = true; // 列表不为空，标记为已检查

    DomainPlan? plan;
    try {
      plan = plans.firstWhere((p) => p.id == planId);
    } catch (e) {
      plan = null;
    }

    if (plan != null) {
      // 既然要直接跳转，无论桌面还是移动端，都直接在 setState 中设置 _selectedPlan
      // 对于移动端，我们修改 build 方法，使其直接渲染 PlanPurchasePage 而不是 Push
      // 这样就避免了中间页面的闪烁
      setState(() {
        _selectedPlan = plan;
      });
    }
  }

  Future<void> _refreshPlans() async {
    final subscriptionNotifier = ref.read(xboardSubscriptionProvider.notifier);
    await subscriptionNotifier.refreshPlans();
  }

  void _backToPlans() {
    setState(() {
      _selectedPlan = null;
    });

    // 移动端：如果返回，需要清除 URL 参数，否则刷新又会跳进去
    // 但 GoRouter 对于同一个 path 的修改可能比较麻烦，
    // 这里简单处理：当用户点击返回时，我们只是清除 _selectedPlan
    // 为了防止 listen 监听到变化再次触发 _checkUrlParams，_hasCheckedUrlParams 保持 true
  }

  String _formatPrice(double? price) {
    if (price == null) return '-';
    return '¥${price.toStringAsFixed(2)}';
  }

  String _formatTraffic(double transferEnable) {
    if (transferEnable >= 1024) {
      return '${(transferEnable / 1024).toStringAsFixed(1)}TB';
    }
    return '${transferEnable.toStringAsFixed(0)}GB';
  }

  String _getLowestPrice(DomainPlan plan) {
    List<double> prices = [];
    if (plan.monthlyPrice != null) prices.add(plan.monthlyPrice!);
    if (plan.quarterlyPrice != null) prices.add(plan.quarterlyPrice!);
    if (plan.halfYearlyPrice != null) prices.add(plan.halfYearlyPrice!);
    if (plan.yearlyPrice != null) prices.add(plan.yearlyPrice!);
    if (plan.twoYearPrice != null) prices.add(plan.twoYearPrice!);
    if (plan.threeYearPrice != null) prices.add(plan.threeYearPrice!);
    if (plan.onetimePrice != null) prices.add(plan.onetimePrice!);
    if (prices.isEmpty) return '-';
    final lowestPrice = prices.reduce((a, b) => a < b ? a : b);
    return _formatPrice(lowestPrice);
  }

  String _getSpeedLimitText(DomainPlan plan) {
    if (plan.speedLimit == null) {
      return AppLocalizations.of(context).xboardUnlimited; // 不限速
    }
    return '${plan.speedLimit} Mbps';
  }

  Widget _buildPlanCard(DomainPlan plan) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: isDesktop
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.fg(context).withValues(alpha: 0.15),
                AppColors.surface(context, 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.fg(context).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fg(context),
                          ),
                        ),
                      ),
                      if (plan.hasPrice)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            _getLowestPrice(plan),
                            style: TextStyle(
                              color: AppColors.fg(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 8 : 12),
                  Row(
                    children: [
                      Icon(
                        Icons.data_usage,
                        size: 16,
                        color: AppColors.fg(context).withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppLocalizations.of(context).xboardTraffic}: ${_formatTraffic(plan.transferQuota.toDouble())}',
                        style: TextStyle(
                          color: AppColors.fg(context).withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.speed,
                        size: 16,
                        color: AppColors.fg(context).withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppLocalizations.of(context).xboardSpeedLimit}: ${_getSpeedLimitText(plan)}',
                        style: TextStyle(
                          color: AppColors.fg(context).withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  if (plan.description != null) ...[
                    SizedBox(height: isDesktop ? 8 : 12),
                    PlanDescriptionWidget(content: plan.description!),
                  ],
                  SizedBox(height: isDesktop ? 12 : 20),
                  if (plan.hasPrice)
                    _buildPremiumPurchaseButton(plan, isDesktop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建高级感购买按钮
  Widget _buildPremiumPurchaseButton(DomainPlan plan, bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      child: StatefulBuilder(
        builder: (context, setState) {
          return MouseRegion(
            onEnter: (_) => setState(() {}),
            onExit: (_) => setState(() {}),
            child: GestureDetector(
              onTapDown: (_) => setState(() {}),
              onTapUp: (_) => setState(() {}),
              onTapCancel: () => setState(() {}),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToPurchase(plan),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isDesktop ? 12 : 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_rounded,
                            color: AppColors.fg(context),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            appLocalizations.xboardBuyNow,
                            style: TextStyle(
                              color: AppColors.fg(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: 0.5,
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
        },
      ),
    );
  }

  void _navigateToPurchase(DomainPlan plan) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    if (isDesktop) {
      // 桌面端：内嵌显示
      setState(() {
        _selectedPlan = plan;
      });
    } else {
      // 移动端：使用 Navigator.push 导航，自动有返回按钮
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlanPurchasePage(plan: plan),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听套餐列表变化，处理URL参数跳转
    ref.listen(xboardSubscriptionProvider, (_, __) => _checkUrlParams());

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    final showPurchasePage = _selectedPlan != null;

    final scaffold = Scaffold(
      extendBodyBehindAppBar: true,
      appBar: showPurchasePage
          ? AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _backToPlans,
                tooltip: AppLocalizations.of(context).xboardBack,
              ),
              title: Text(appLocalizations.xboardPurchaseSubscription),
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
            )
          : isDesktop
              ? null
              : AppBar(
                  title: Text(appLocalizations.xboardPlanInfo),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                ),
      body: showPurchasePage
          ? PlanPurchasePage(
              plan: _selectedPlan!,
              embedded: true,
              onBack: _backToPlans,
            )
          : Container(
              decoration: AppColors.backgroundDecoration(context),
              child: Padding(
                // AppBar 悬浮在 body 之上，顶部留白需等于「状态栏 + 工具栏」
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight,
                ),
                child: RefreshIndicator(
                  onRefresh: _refreshPlans,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final plans = ref.watch(xboardSubscriptionProvider);
                      final uiState = ref.watch(userUIStateProvider);

                      Widget buildScrollableCenter(Widget child) {
                        return LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(child: child),
                            ),
                          ),
                        );
                      }

                      if (uiState.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (uiState.errorMessage != null) {
                        return buildScrollableCenter(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                appLocalizations.xboardLoadingFailed,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                uiState.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refreshPlans,
                                child: Text(appLocalizations.xboardRetry),
                              ),
                            ],
                          ),
                        );
                      }
                      if (plans.isEmpty) {
                        return buildScrollableCenter(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                appLocalizations.xboardNoSubscriptionInfo,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // 过滤套餐
                      var filteredPlans = plans;
                      if (_selectedFilter == 1) {
                        // 周期性：有任意周期性价格
                        filteredPlans = plans
                            .where((p) =>
                                (p.monthlyPrice != null &&
                                    p.monthlyPrice! > 0) ||
                                (p.quarterlyPrice != null &&
                                    p.quarterlyPrice! > 0) ||
                                (p.halfYearlyPrice != null &&
                                    p.halfYearlyPrice! > 0) ||
                                (p.yearlyPrice != null && p.yearlyPrice! > 0) ||
                                (p.twoYearPrice != null &&
                                    p.twoYearPrice! > 0) ||
                                (p.threeYearPrice != null &&
                                    p.threeYearPrice! > 0))
                            .toList();
                      } else if (_selectedFilter == 2) {
                        // 一次性：有一次性价格
                        filteredPlans = plans
                            .where((p) =>
                                p.onetimePrice != null && p.onetimePrice! > 0)
                            .toList();
                      }

                      final screenWidth = MediaQuery.of(context).size.width;
                      final isDesktop = screenWidth > 768;

                      Widget filterWidget = SlidingFilterButton(
                        selectedIndex: _selectedFilter,
                        onChanged: (newIndex) {
                          setState(() {
                            _selectedFilter = newIndex;
                          });
                        },
                        labels: [
                          appLocalizations.xboardAllFilter,
                          appLocalizations.xboardRecurring,
                          appLocalizations.xboardOneTimePayment
                        ],
                      );

                      if (isDesktop) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Center(child: filterWidget),
                              ),
                              if (filteredPlans.isEmpty)
                                Center(
                                    child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(AppLocalizations.of(context)
                                      .xboardNoPlansInCategory),
                                ))
                              else
                                Center(
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    alignment: WrapAlignment.center,
                                    children: filteredPlans.map((plan) {
                                      return SizedBox(
                                        width: 350, // 固定宽度
                                        child: _buildPlanCard(plan),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      } else {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16.0, horizontal: 16.0),
                              child: Center(child: filterWidget),
                            ),
                            Expanded(
                              child: filteredPlans.isEmpty
                                  ? Center(
                                      child: Text(AppLocalizations.of(context)
                                          .xboardNoPlansInCategory))
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(
                                          bottom: 100), // 增加底部 padding 避免被导航栏遮挡
                                      itemCount: filteredPlans.length,
                                      itemBuilder: (context, index) {
                                        return _buildPlanCard(
                                            filteredPlans[index]);
                                      },
                                    ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
    );

    // 移动端需要拦截返回按钮，桌面端直接返回 scaffold
    if (isDesktop) {
      return scaffold;
    } else {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          if (_selectedPlan != null) {
            _backToPlans();
            return;
          }

          context.go('/');
        },
        child: scaffold,
      );
    }
  }
}
