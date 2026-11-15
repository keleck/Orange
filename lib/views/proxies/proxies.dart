import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/proxies/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common.dart';
import 'setting.dart';
import 'tab.dart';
import 'package:fl_clash/common/app_localizations.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> with PageMixin {
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();
  bool _hasProviders = false;
  bool _isTab = false;

  _handleRefresh() async {
    final providers = ref.read(providersProvider);
    final providersNotifier = ref.read(providersProvider.notifier);
    if (providers.isNotEmpty) {
      final updateProviders = providers.map<Future>(
        (provider) async {
          providersNotifier.setProvider(
            provider.copyWith(isUpdating: true),
          );
          await clashCore.updateExternalProvider(
            providerName: provider.name,
          );
          providersNotifier.setProvider(
            await clashCore.getExternalProvider(provider.name),
          );
        },
      );
      await Future.wait(updateProviders);
    }
    await globalState.appController.updateGroups();
    final groups = ref.read(groupsProvider);
    final proxies = <Proxy>[];
    for (final group in groups) {
      if (group.all.isNotEmpty) {
        proxies.addAll(group.all);
      }
    }
    final uniqueProxies = {for (var p in proxies) p.name: p}.values.toList();
    if (uniqueProxies.isNotEmpty) {
      await delayTest(uniqueProxies);
    }
  }

  @override
  get actions => [
        if (_isTab)
          IconButton(
            onPressed: () {
              _proxiesTabKey.currentState?.scrollToGroupSelected();
            },
            icon: Icon(
              Icons.adjust,
              weight: 1,
            ),
          ),
        IconButton(
          onPressed: () {
            _handleRefresh();
          },
          icon: const Icon(Icons.refresh),
        ),
        CommonPopupBox(
          targetBuilder: (open) {
            return IconButton(
              onPressed: () {
                open(
                  offset: Offset(0, 20),
                );
              },
              icon: Icon(
                Icons.more_vert,
              ),
            );
          },
          popup: CommonPopupMenu(
            items: [
              PopupMenuItemData(
                icon: Icons.tune,
                label: appLocalizations.settings,
                onPressed: () {
                  showSheet(
                    context: context,
                    props: SheetProps(
                      isScrollControlled: true,
                    ),
                    builder: (_, type) {
                      return AdaptiveSheetScaffold(
                        type: type,
                        body: const ProxiesSetting(),
                        title: appLocalizations.settings,
                      );
                    },
                  );
                },
              ),
              if (_hasProviders)
                PopupMenuItemData(
                  icon: Icons.poll_outlined,
                  label: appLocalizations.providers,
                  onPressed: () {
                    showExtend(
                      context,
                      builder: (_, type) {
                        return ProvidersView(
                          type: type,
                        );
                      },
                    );
                  },
                ),
              if (!_isTab)
                PopupMenuItemData(
                  icon: Icons.style_outlined,
                  label: appLocalizations.iconConfiguration,
                  onPressed: () {
                    showExtend(
                      context,
                      builder: (_, type) {
                        return AdaptiveSheetScaffold(
                          type: type,
                          body: const _IconConfigView(),
                          title: appLocalizations.iconConfiguration,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        )
      ];

  @override
  get onSearch => (value) {
        ref.read(proxiesQueryProvider.notifier).value = value;
      };

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(proxiesQueryProvider.notifier).value = "";
      }
    });
  }

  @override
  get floatingActionButton => null;

  @override
  void initState() {
    [
      if (_hasProviders)
        IconButton(
          onPressed: () {
            showExtend(
              context,
              builder: (_, type) {
                return ProvidersView(
                  type: type,
                );
              },
            );
          },
          icon: const Icon(
            Icons.poll_outlined,
          ),
        ),
      _isTab
          ? IconButton(
              onPressed: () {
                _proxiesTabKey.currentState?.scrollToGroupSelected();
              },
              icon: const Icon(
                Icons.adjust_outlined,
              ),
            )
          : IconButton(
              onPressed: () {
                showExtend(
                  context,
                  builder: (_, type) {
                    return AdaptiveSheetScaffold(
                      type: type,
                      body: const _IconConfigView(),
                      title: appLocalizations.iconConfiguration,
                    );
                  },
                );
              },
              icon: const Icon(
                Icons.style_outlined,
              ),
            ),
      IconButton(
        onPressed: () {
          showSheet(
            context: context,
            props: SheetProps(
              isScrollControlled: true,
            ),
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                body: const ProxiesSetting(),
                title: appLocalizations.settings,
              );
            },
          );
        },
        icon: const Icon(
          Icons.tune,
        ),
      )
    ];
    ref.listenManual(
      proxiesActionsStateProvider,
      fireImmediately: true,
      (prev, next) {
        if (prev == next) {
          return;
        }
        _hasProviders = next.hasProviders;
        _isTab = next.type == ProxiesType.tab;
        initPageState();
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => state.type,
      ),
    );
    final content = switch (proxiesType) {
      ProxiesType.tab => ProxiesTabView(
          key: _proxiesTabKey,
        ),
      ProxiesType.list => const ProxiesListView(),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.colorScheme.surfaceVariant.opacity10,
            context.colorScheme.surface,
          ],
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: content is ProxiesTabView
            ? KeyedSubtree(
                key: const ValueKey('tab-view'),
                child: content,
              )
            : KeyedSubtree(
                key: const ValueKey('list-view'),
                child: content,
              ),
      ),
    );
  }
}

class _IconConfigView extends ConsumerWidget {
  const _IconConfigView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconMap = ref.watch(proxiesStyleSettingProvider.select(
      (state) => state.iconMap,
    ));
    return MapInputPage(
      title: appLocalizations.iconConfiguration,
      map: iconMap,
      keyLabel: appLocalizations.regExp,
      valueLabel: appLocalizations.icon,
      titleBuilder: (item) => Text(item.key),
      leadingBuilder: (item) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: CommonTargetIcon(
          src: item.value,
          size: 42,
        ),
      ),
      subtitleBuilder: (item) => Text(
        item.value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onChange: (value) {
        ref.read(proxiesStyleSettingProvider.notifier).updateState(
              (state) => state.copyWith(
                iconMap: value,
              ),
            );
      },
    );
  }
}
