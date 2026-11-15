import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
// import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/xboard/features/payment/pages/plans.dart';
import 'package:fl_clash/xboard/features/subscription/pages/xboard_home_page.dart';
import 'package:fl_clash/xboard/features/user/pages/user_center_page.dart';
import 'package:flutter/material.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    final items = [
      // 首页
      const NavigationItem(
        icon: Icon(Icons.home),
        label: PageLabel.xboard,
        view: XBoardHomePage(
          key: GlobalObjectKey(
            PageLabel.xboard,
          ),
        ),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      // 套餐
      const NavigationItem(
        icon: Icon(Icons.shopping_cart),
        label: PageLabel.plans,
        view: PlansView(
          key: GlobalObjectKey(
            PageLabel.plans,
          ),
        ),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      // 我的（个人中心）
      const NavigationItem(
        icon: Icon(Icons.person),
        label: PageLabel.userCenter,
        view: UserCenterPage(
          key: GlobalObjectKey(
            PageLabel.userCenter,
          ),
        ),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
    debugPrint(
        '[Navigation] getItems 返回 ${items.length} 个导航项: ${items.map((e) => e.label.name).toList()}');
    return items;
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
