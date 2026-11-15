import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/user/widgets/wallet_card.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/l10n/l10n.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: AppColors.backgroundDecoration(context),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: Text(AppLocalizations.of(context).xboardMyWallet),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
          ),
          // 可滚动内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 100), // 增加底部 padding 避免被导航栏遮挡
              child: Column(
                children: [
                  const WalletCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
