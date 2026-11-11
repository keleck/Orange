import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/invite/widgets/qr_code_widget.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';

class InviteQrCard extends ConsumerStatefulWidget {
  const InviteQrCard({super.key});

  @override
  ConsumerState<InviteQrCard> createState() => _InviteQrCardState();
}

class _InviteQrCardState extends ConsumerState<InviteQrCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(inviteProvider);
    final codes = inviteState.hasInviteData ? inviteState.inviteData!.codes : [];
    final baseUrl = _getSdkBaseUrl();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: _glassmorphicDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  appLocalizations.myInviteQr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                if (codes.isNotEmpty) ...[
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: codes.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final code = codes[index];
                        final inviteUrl = baseUrl.isNotEmpty
                            ? '$baseUrl/#/register?code=${code.code}'
                            : '';
                        return Column(
                          children: [
                            QrCodeWidget(
                              data: inviteUrl,
                              size: 200,
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              code.code,
                              style:
                                  Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (codes.length > 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(codes.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentIndex == index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Builder(
                    builder: (context) {
                      final currentCode = codes[_currentIndex];
                      final inviteUrl = baseUrl.isNotEmpty
                          ? '$baseUrl/#/register?code=${currentCode.code}'
                          : '';
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _saveQrCode(context, inviteUrl),
                            icon: const Icon(Icons.save_alt, color: Colors.white),
                            label: Text(
                              appLocalizations.saveQr,
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _copyToClipboard(context, inviteUrl),
                            icon: const Icon(Icons.link, color: Colors.white),
                            label: Text(
                              appLocalizations.copyInviteLink,
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: inviteState.isGenerating
                        ? null
                        : () {
                            ref.read(inviteProvider.notifier).generateInviteCode();
                          },
                    icon: inviteState.isGenerating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                    : const Icon(Icons.add_circle_outline),
                  label: const Text("生成邀请码"),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ] else if (inviteState.isLoading || inviteState.isGenerating) ...[
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        appLocalizations.generatingInviteCode,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "暂无邀请码",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          ref.read(inviteProvider.notifier).generateInviteCode();
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("生成邀请码"),
                      ),
                    ],
                  ),
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassmorphicDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.primary.withValues(alpha: 0.08),
          theme.colorScheme.primary.withValues(alpha: 0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.shadowColor.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: theme.shadowColor.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    XBoardNotification.showSuccess(appLocalizations.copiedToClipboard);
  }

  void _saveQrCode(BuildContext context, String inviteUrl) {
    XBoardNotification.showInfo(appLocalizations.saveQrCodeFeature);
  }

  String _getSdkBaseUrl() {
    try {
      return XBoardConfig.panelUrl ?? '';
    } catch (e) {
      return '';
    }
  }
}