import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';

/// 「应用访问控制」独立页面
///
/// 复用 FlClash 原有的 AccessView（应用列表 + 勾选 + 全局开关），
/// 外面补一个与全站一致的深色 Scaffold 和标题栏。
class AccessControlPage extends StatelessWidget {
  const AccessControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppColors.backgroundDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).appAccessControl),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        ),
        body: const AccessView(),
      ),
    );
  }
}
