import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/stat_item_widget.dart';
import 'package:fl_clash/common/app_localizations.dart';

class InviteStatsCard extends ConsumerWidget {
  const InviteStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteState = ref.watch(inviteProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: _glassmorphicDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appLocalizations.inviteStats,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (inviteState.isLoading && !inviteState.hasInviteData)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: StatItemWidget(
                          title: appLocalizations.totalInvites,
                          value: '${inviteState.totalInvites}',
                          icon: Icons.people,
                        ),
                      ),
                      Expanded(
                        child: StatItemWidget(
                          title: appLocalizations.commissionRate,
                          value: '${inviteState.commissionRate}%',
                          icon: Icons.percent,
                        ),
                      ),
                      Expanded(
                        child: StatItemWidget(
                          title: appLocalizations.totalCommission,
                          value: inviteState.formattedCommission,
                          icon: Icons.monetization_on,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassmorphicDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}
