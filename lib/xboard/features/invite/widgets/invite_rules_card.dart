import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/common/app_localizations.dart';

class InviteRulesCard extends ConsumerWidget {
  const InviteRulesCard({super.key});

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
                Row(
                  children: [
                    Icon(Icons.rule,
                        color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 8),
                    Text(
                      appLocalizations.inviteRules,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '• ${appLocalizations.inviteRegisterReward}\n'
                  '• ${appLocalizations.friendInviteReward}\n'
                  '• ${appLocalizations.currentCommissionRate(inviteState.commissionRate.toString())}\n'
                  '• ${appLocalizations.commissionSettled}\n'
                  '• ${appLocalizations.withdrawalAvailable}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
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
