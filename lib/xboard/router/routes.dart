import 'package:fl_clash/xboard/features/user/pages/user_center_page.dart';
import 'package:fl_clash/xboard/features/user/pages/wallet_page.dart';
import 'package:fl_clash/xboard/features/user/pages/settings_page.dart';
import 'package:fl_clash/xboard/features/subscription/pages/xboard_home_page.dart';
import 'package:fl_clash/xboard/features/subscription/pages/subscription_page.dart';
import 'package:fl_clash/xboard/features/payment/pages/plans.dart';
import 'package:fl_clash/xboard/features/payment/pages/plan_purchase_page.dart';
import 'package:fl_clash/xboard/features/payment/pages/payment_gateway_page.dart';
import 'package:fl_clash/xboard/features/invite/pages/invite_page.dart';
import 'package:fl_clash/xboard/features/order/pages/order_page.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/xboard/features/traffic/pages/traffic_log_page.dart';
import 'package:fl_clash/xboard/features/auth/pages/login_page.dart';
import 'package:fl_clash/xboard/features/ticket/pages/tickets_page.dart';
import 'package:fl_clash/xboard/features/ticket/pages/create_ticket_page.dart';
import 'package:fl_clash/xboard/features/ticket/pages/ticket_detail_page.dart';
import 'package:fl_clash/xboard/features/crisp_support/pages/crisp_support_page.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'page_transitions.dart';
import 'shell_layout.dart';

/// XBoard 路由定义
/// 使用 go_router 实现类型安全的声明式路由

// 路由列表
final List<RouteBase> routes = [
  // StatefulShellRoute - 包含侧边栏的主框架，保持各分支状态
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return AdaptiveShellLayout(child: navigationShell);
    },
    branches: [
      // 首页分支
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: XBoardHomePage(),
            ),
          ),
        ],
      ),

      // 套餐列表分支
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/plans',
            name: 'plans',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlansView(),
            ),
          ),
        ],
      ),

      // 订单列表分支
      // StatefulShellBranch(
      //   routes: [
      //     GoRoute(
      //       path: '/orders',
      //       name: 'orders',
      //       pageBuilder: (context, state) => const NoTransitionPage(
      //         child: OrderPage(),
      //       ),
      //     ),
      //   ],
      // ),

      // // 流量明细分支
      // StatefulShellBranch(
      //   routes: [
      //     GoRoute(
      //       path: '/traffic-log',
      //       name: 'traffic_log',
      //       pageBuilder: (context, state) => const NoTransitionPage(
      //         child: TrafficLogPage(),
      //       ),
      //     ),
      //   ],
      // ),

      // // 在线客服分支
      // StatefulShellBranch(
      //   routes: [
      //     GoRoute(
      //       path: '/support',
      //       name: 'support',
      //       pageBuilder: (context, state) => const NoTransitionPage(
      //         child: OnlineSupportPage(),
      //       ),
      //     ),
      //   ],
      // ),

      // // 邀请页面分支
      // StatefulShellBranch(
      //   routes: [
      //     GoRoute(
      //       path: '/invite',
      //       name: 'invite',
      //       pageBuilder: (context, state) => const NoTransitionPage(
      //         child: InvitePage(),
      //       ),
      //     ),
      //   ],
      // ),

      // 用户中心分支
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/user',
            name: 'user',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UserCenterPage(),
            ),
            routes: [
              GoRoute(
                path: 'orders',
                name: 'orders',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: OrderPage(),
                ),
              ),
              GoRoute(
                path: 'traffic-log',
                name: 'traffic_log',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: TrafficLogPage(),
                ),
              ),
              GoRoute(
                path: 'support',
                name: 'support',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: CrispSupportPage(),
                ),
              ),
              GoRoute(
                path: 'invite',
                name: 'invite',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: InvitePage(),
                ),
              ),
              GoRoute(
                path: 'wallet',
                name: 'wallet',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: WalletPage(),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'settings',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: SettingsPage(),
                ),
              ),
              GoRoute(
                path: 'tickets',
                name: 'tickets',
                pageBuilder: (context, state) => const SlideFadePage(
                  child: TicketsPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    name: 'create_ticket',
                    pageBuilder: (context, state) => const MaterialPage(
                      child: CreateTicketPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'ticket_detail',
                    pageBuilder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return MaterialPage(
                        child: TicketDetailPage(ticketId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),

  // 套餐购买页面（全屏，不在 Shell 内）
  GoRoute(
    path: '/plans/purchase',
    name: 'plan_purchase',
    pageBuilder: (context, state) {
      final plan = state.extra as DomainPlan;
      return MaterialPage(
        child: PlanPurchasePage(plan: plan),
      );
    },
  ),

  // 支付网关页面
  GoRoute(
    path: '/payment/gateway',
    name: 'payment_gateway',
    pageBuilder: (context, state) {
      final params = state.extra as Map<String, dynamic>?;
      return MaterialPage(
        child: PaymentGatewayPage(
          paymentUrl: params?['paymentUrl'] as String? ?? '',
          tradeNo: params?['tradeNo'] as String? ?? '',
        ),
      );
    },
  ),
  // 订阅详情页面
  GoRoute(
    path: '/subscription',
    name: 'subscription',
    pageBuilder: (context, state) => const MaterialPage(
      child: SubscriptionPage(),
    ),
  ),

  // 登录页面
  GoRoute(
    path: '/login',
    name: 'login',
    pageBuilder: (context, state) => const MaterialPage(
      child: LoginPage(),
    ),
  ),

  // 加载页面
  GoRoute(
    path: '/loading',
    name: 'loading',
    pageBuilder: (context, state) => MaterialPage(
      child: Container(
        decoration: AppColors.getBackgroundDecoration(),
        child: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
          backgroundColor: Colors.transparent,
        ),
      ),
    ),
  ),
];

/// 不带过渡动画的 Page
class NoTransitionPage<T> extends Page<T> {
  const NoTransitionPage({
    required this.child,
    super.key,
    super.name,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}
