import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/user_menu_widget.dart';
import 'package:fl_clash/xboard/features/invite/widgets/error_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/invite_rules_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/invite_qr_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/invite_stats_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/wallet_details_card.dart';
import 'package:fl_clash/xboard/features/invite/widgets/commission_history_card.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> 
    with AutomaticKeepAliveClientMixin {
  bool _hasInitialized = false;
  
  @override
  bool get wantKeepAlive => true;  // 保持页面状态，防止重建
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasInitialized) return;
      _hasInitialized = true;
      
      await ref.read(inviteProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // 必须调用，配合 AutomaticKeepAliveClientMixin
    
    final appLocalizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(appLocalizations.invite),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: AppColors.getBackgroundDecoration(),
        child: Padding(
          // AppBar 悬浮在 body 之上，顶部留白需等于「状态栏 + 工具栏」
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
          ),
          child: Consumer(
            builder: (_, ref, __) {
              return RefreshIndicator(
              onRefresh: () => ref.read(inviteProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // 增加底部 padding 避免被导航栏遮挡
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ErrorCard(),
                    
                    const InviteRulesCard(),
                    const SizedBox(height: 16),
                    
                    const InviteQrCard(),
                    const SizedBox(height: 16),
                    
                    const InviteStatsCard(),
                    const SizedBox(height: 16),
                    
                    const WalletDetailsCard(),
                    const SizedBox(height: 16),
                    
                    const CommissionHistoryCard(),
                  ],
                ),
              ),
            );
            },
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃装饰 - 返回 BoxDecoration
BoxDecoration glassmorphicDecoration(BuildContext context) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.035),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.07),
    ),
  );
}

/// 液态玻璃包装widget
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: glassmorphicDecoration(context),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}