import 'dart:ui';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/latency/widgets/latency_indicator.dart';
import 'package:fl_clash/xboard/features/shared/widgets/service_status_card.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/app_colors.dart';

/// 节点选择页面 - 模仿截图风格
class NodeSelectorPage extends ConsumerStatefulWidget {
  const NodeSelectorPage({super.key});

  @override
  ConsumerState<NodeSelectorPage> createState() => _NodeSelectorPageState();
}

class _NodeSelectorPageState extends ConsumerState<NodeSelectorPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groups = ref.watch(groupsProvider);
    final mode =
        ref.watch(patchClashConfigProvider.select((state) => state.mode));
    final selectedMap = ref.watch(selectedMapProvider);

    // 获取当前组
    Group? currentGroup = _getCurrentGroup(groups, mode, selectedMap);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context, currentGroup),
      body: Container(
        decoration: AppColors.backgroundDecoration(context),
        child: Padding(
          // AppBar 悬浮在 body 之上，顶部留白必须等于「状态栏 + 工具栏」，
          // 写死 70 会在状态栏较高的机型上让内容压到标题上。
          // 底部同理：外层 shell 用了 extendBody，导航栏高度会体现在
          // MediaQuery.padding.bottom 里，需要让列表停在导航栏上方。
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Column(
            children: [
              // 服务状态卡片（替代原来的「当前节点」卡片）
              // nodeName 用于感知节点切换：组名不变时也能触发重新探测
              if (currentGroup != null && currentGroup.all.isNotEmpty)
                ServiceStatusCard(
                  proxyName: currentGroup.name,
                  nodeName: currentGroup.getCurrentSelectedName(
                    selectedMap[currentGroup.name] ?? '',
                  ),
                ),
              // 用剩余空间自适应，写死高度会在不同屏幕上溢出到导航栏下面
              Expanded(
                child: _buildNodeList(context, currentGroup, selectedMap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Group? currentGroup) {
    final theme = Theme.of(context);
    final selectedMap = ref.watch(selectedMapProvider);

    String title = AppLocalizations.of(context).xboardProxy;
    if (currentGroup != null) {
      final selectedProxyName = selectedMap[currentGroup.name] ?? "";
      String realNodeName =
          currentGroup.getCurrentSelectedName(selectedProxyName);
      if (realNodeName.isEmpty && currentGroup.all.isNotEmpty) {
        realNodeName = currentGroup.all.first.name;
      }
      title = '${currentGroup.name} -> $realNodeName';
    }

    return AppBar(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.close,
          color: theme.colorScheme.onSurface,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () async {
            // 批量测延迟
            final groups = ref.read(groupsProvider);
            if (groups.isNotEmpty) {
              final currentGroup = _getCurrentGroup(
                groups,
                ref.read(
                    patchClashConfigProvider.select((state) => state.mode)),
                ref.read(selectedMapProvider),
              );
              if (currentGroup != null && currentGroup.all.isNotEmpty) {
                await delayTest(currentGroup.all, currentGroup.testUrl);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildNodeList(BuildContext context, Group? currentGroup,
      Map<String, String> selectedMap) {
    if (currentGroup == null || currentGroup.all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.router_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).xboardNoAvailableNodes,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final allGroups = ref.watch(groupsProvider);

    // 如果选中的是 URLTest 或 Fallback 组，需要找到原始的规则组
    Group? displayGroup = currentGroup;
    if (currentGroup.type == GroupType.URLTest ||
        currentGroup.type == GroupType.Fallback) {
      // 从选中的特殊组返回到原始规则组
      for (final group in allGroups) {
        if (group.hidden == true) continue;
        if (group.name == GroupName.GLOBAL.name) continue;
        if (group.type == GroupType.URLTest || group.type == GroupType.Fallback)
          continue;

        // 检查这个规则组是否引用了当前选中的特殊组
        final selectedProxyName = selectedMap[group.name];
        if (selectedProxyName == currentGroup.name) {
          displayGroup = group;
          break;
        }
      }

      // 如果没找到，就用第一个规则组
      if (displayGroup == currentGroup) {
        try {
          displayGroup = allGroups.firstWhere(
            (group) =>
                group.hidden != true &&
                group.name != GroupName.GLOBAL.name &&
                group.type != GroupType.URLTest &&
                group.type != GroupType.Fallback,
          );
        } catch (e) {
          displayGroup = currentGroup;
        }
      }
    }

    // 确保 displayGroup 不为 null
    if (displayGroup == null) {
      displayGroup = currentGroup;
    }

    final selectedProxyName = selectedMap[displayGroup.name] ?? "";
    final realNodeName = displayGroup.getCurrentSelectedName(selectedProxyName);

    // 过滤掉 Selector 类型的组引用，但保留 URLTest 和 Fallback 等特殊节点
    final filteredProxies = displayGroup.all.where((proxy) {
      // 查找是否存在同名的组
      Group? referencedGroup;
      try {
        referencedGroup = allGroups.firstWhere((g) => g.name == proxy.name);
      } catch (e) {
        referencedGroup = null;
      }

      if (referencedGroup != null) {
        // 如果找到同名组，只在它是 Selector 类型时才过滤（即过滤掉普通组引用）
        // 但保留 URLTest 和 Fallback 等特殊节点
        return referencedGroup.type != GroupType.Selector;
      }

      // 如果没有同名组，说明这是真实代理节点，保留
      return true;
    }).toList();

    if (filteredProxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.router_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).xboardNoAvailableNodes,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filteredProxies.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.surface(context, 0.1),
            ),
            itemBuilder: (context, index) {
              final proxy = filteredProxies[index];
              final isSelected = proxy.name == realNodeName;

              return _buildNodeItem(
                context,
                proxy: proxy,
                groupName: displayGroup?.name ?? currentGroup.name,
                isSelected: isSelected,
                testUrl: displayGroup?.testUrl ?? currentGroup.testUrl,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNodeItem(
    BuildContext context, {
    required Proxy proxy,
    required String groupName,
    required bool isSelected,
    String? testUrl,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final appController = globalState.appController;
          final mode =
              ref.read(patchClashConfigProvider.select((state) => state.mode));

          // 更新规则模式下的选择
          appController.updateCurrentSelectedMap(
            groupName,
            proxy.name,
          );
          await appController.changeProxy(
            groupName: groupName,
            proxyName: proxy.name,
          );

          // 如果是规则模式，同时将节点同步到全局模式的 GLOBAL 组
          if (mode == Mode.rule) {
            appController.updateCurrentSelectedMap(
              GroupName.GLOBAL.name,
              proxy.name,
            );
            await appController.changeProxy(
              groupName: GroupName.GLOBAL.name,
              proxyName: proxy.name,
            );
          }

          if (mounted) {
            setState(() {});
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Colors.blue.withValues(alpha: 0.2),
                      Colors.blue.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // 国旗图标
              Container(
                width: 32,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.fg(context).withValues(alpha: 0.15),
                      AppColors.surface(context, 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.fg(context).withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getCountryFlag(proxy.name),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 节点名称和协议
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      proxy.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.fg(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      proxy.type,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.fg(context).withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 延迟显示
              _buildLatencyWidget(proxy, testUrl),
              // 选中指示器
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Colors.green.shade400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatencyWidget(Proxy proxy, String? testUrl) {
    final url = testUrl ?? ref.read(appSettingProvider).testUrl;
    final delayState = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: url,
    ));

    // 单击延迟徽标只测这一个节点，互不影响
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => delayTest([proxy], url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: LatencyIndicator(
          delayValue: delayState,
        ),
      ),
    );
  }

  String _getCountryFlag(String nodeName) {
    final lowerName = nodeName.toLowerCase();

    // 亚洲
    if (lowerName.contains('hk') ||
        lowerName.contains('hong kong') ||
        lowerName.contains('香港')) {
      return '🇭🇰';
    } else if (lowerName.contains('tw') ||
        lowerName.contains('taiwan') ||
        lowerName.contains('台湾')) {
      return '🇨🇳';
    } else if (lowerName.contains('sg') ||
        lowerName.contains('singapore') ||
        lowerName.contains('新加坡')) {
      return '🇸🇬';
    } else if (lowerName.contains('jp') ||
        lowerName.contains('japan') ||
        lowerName.contains('日本')) {
      return '🇯🇵';
    } else if (lowerName.contains('kr') ||
        lowerName.contains('korea') ||
        lowerName.contains('韩国') ||
        lowerName.contains('south korea')) {
      return '🇰🇷';
    } else if (lowerName.contains('kp') ||
        lowerName.contains('north korea') ||
        lowerName.contains('朝鲜')) {
      return '🇰🇵';
    } else if (lowerName.contains('th') ||
        lowerName.contains('thailand') ||
        lowerName.contains('泰国')) {
      return '🇹🇭';
    } else if (lowerName.contains('kh') ||
        lowerName.contains('cambodia') ||
        lowerName.contains('柬埔寨')) {
      return '🇰🇭';
    } else if (lowerName.contains('la') ||
        lowerName.contains('laos') ||
        lowerName.contains('老挝')) {
      return '🇱🇦';
    } else if (lowerName.contains('vn') ||
        lowerName.contains('vietnam') ||
        lowerName.contains('越南')) {
      return '🇻🇳';
    } else if (lowerName.contains('my') ||
        lowerName.contains('malaysia') ||
        lowerName.contains('马来西亚')) {
      return '🇲🇾';
    } else if (lowerName.contains('ph') ||
        lowerName.contains('philippines') ||
        lowerName.contains('菲律宾')) {
      return '🇵🇭';
    } else if (lowerName.contains('id') ||
        lowerName.contains('indonesia') ||
        lowerName.contains('印度尼西亚')) {
      return '🇮🇩';
    } else if (lowerName.contains('in') ||
        lowerName.contains('india') ||
        lowerName.contains('印度')) {
      return '🇮🇳';
    } else if (lowerName.contains('pk') ||
        lowerName.contains('pakistan') ||
        lowerName.contains('巴基斯坦')) {
      return '🇵🇰';
    } else if (lowerName.contains('bd') ||
        lowerName.contains('bangladesh') ||
        lowerName.contains('孟加拉')) {
      return '🇧🇩';
    } else if (lowerName.contains('lk') ||
        lowerName.contains('sri lanka') ||
        lowerName.contains('斯里兰卡')) {
      return '🇱🇰';
    } else if (lowerName.contains('mm') ||
        lowerName.contains('myanmar') ||
        lowerName.contains('缅甸')) {
      return '🇲🇲';
    } else if (lowerName.contains('cn') ||
        lowerName.contains('china') ||
        lowerName.contains('中国')) {
      return '🇨🇳';
    } else if (lowerName.contains('mo') ||
        lowerName.contains('macau') ||
        lowerName.contains('澳门')) {
      return '🇲🇴';
    } else if (lowerName.contains('mn') ||
        lowerName.contains('mongolia') ||
        lowerName.contains('蒙古')) {
      return '🇲🇳';
    }

    // 欧洲
    else if (lowerName.contains('de') ||
        lowerName.contains('germany') ||
        lowerName.contains('德国')) {
      return '🇩🇪';
    } else if (lowerName.contains('fr') ||
        lowerName.contains('france') ||
        lowerName.contains('法国')) {
      return '🇫🇷';
    } else if (lowerName.contains('uk') ||
        lowerName.contains('britain') ||
        lowerName.contains('england') ||
        lowerName.contains('英国')) {
      return '🇬🇧';
    } else if (lowerName.contains('ie') ||
        lowerName.contains('ireland') ||
        lowerName.contains('爱尔兰')) {
      return '🇮🇪';
    } else if (lowerName.contains('it') ||
        lowerName.contains('italy') ||
        lowerName.contains('意大利')) {
      return '🇮🇹';
    } else if (lowerName.contains('es') ||
        lowerName.contains('spain') ||
        lowerName.contains('西班牙')) {
      return '🇪🇸';
    } else if (lowerName.contains('pt') ||
        lowerName.contains('portugal') ||
        lowerName.contains('葡萄牙')) {
      return '🇵🇹';
    } else if (lowerName.contains('nl') ||
        lowerName.contains('netherlands') ||
        lowerName.contains('荷兰')) {
      return '🇳🇱';
    } else if (lowerName.contains('be') ||
        lowerName.contains('belgium') ||
        lowerName.contains('比利时')) {
      return '🇧🇪';
    } else if (lowerName.contains('ch') ||
        lowerName.contains('switzerland') ||
        lowerName.contains('瑞士')) {
      return '🇨🇭';
    } else if (lowerName.contains('se') ||
        lowerName.contains('sweden') ||
        lowerName.contains('瑞典')) {
      return '🇸🇪';
    } else if (lowerName.contains('no') ||
        lowerName.contains('norway') ||
        lowerName.contains('挪威')) {
      return '🇳🇴';
    } else if (lowerName.contains('dk') ||
        lowerName.contains('denmark') ||
        lowerName.contains('丹麦')) {
      return '🇩🇰';
    } else if (lowerName.contains('fi') ||
        lowerName.contains('finland') ||
        lowerName.contains('芬兰')) {
      return '🇫🇮';
    } else if (lowerName.contains('pl') ||
        lowerName.contains('poland') ||
        lowerName.contains('波兰')) {
      return '🇵🇱';
    } else if (lowerName.contains('cz') ||
        lowerName.contains('czech') ||
        lowerName.contains('捷克')) {
      return '🇨🇿';
    } else if (lowerName.contains('sk') ||
        lowerName.contains('slovakia') ||
        lowerName.contains('斯洛伐克')) {
      return '🇸🇰';
    } else if (lowerName.contains('hu') ||
        lowerName.contains('hungary') ||
        lowerName.contains('匈牙利')) {
      return '🇭🇺';
    } else if (lowerName.contains('ro') ||
        lowerName.contains('romania') ||
        lowerName.contains('罗马尼亚')) {
      return '🇷🇴';
    } else if (lowerName.contains('bg') ||
        lowerName.contains('bulgaria') ||
        lowerName.contains('保加利亚')) {
      return '🇧🇬';
    } else if (lowerName.contains('gr') ||
        lowerName.contains('greece') ||
        lowerName.contains('希腊')) {
      return '🇬🇷';
    } else if (lowerName.contains('at') ||
        lowerName.contains('austria') ||
        lowerName.contains('奥地利')) {
      return '🇦🇹';
    } else if (lowerName.contains('ru') ||
        lowerName.contains('russia') ||
        lowerName.contains('俄罗斯')) {
      return '🇷🇺';
    } else if (lowerName.contains('ua') ||
        lowerName.contains('ukraine') ||
        lowerName.contains('乌克兰')) {
      return '🇺🇦';
    } else if (lowerName.contains('by') ||
        lowerName.contains('belarus') ||
        lowerName.contains('白俄罗斯')) {
      return '🇧🇾';
    } else if (lowerName.contains('tr') ||
        lowerName.contains('turkey') ||
        lowerName.contains('土耳其')) {
      return '🇹🇷';
    }

    // 北美洲
    else if (lowerName.contains('us') ||
        lowerName.contains('united states') ||
        lowerName.contains('美国')) {
      return '🇺🇸';
    } else if (lowerName.contains('ca') ||
        lowerName.contains('canada') ||
        lowerName.contains('加拿大')) {
      return '🇨🇦';
    } else if (lowerName.contains('mx') ||
        lowerName.contains('mexico') ||
        lowerName.contains('墨西哥')) {
      return '🇲🇽';
    }

    // 南美洲
    else if (lowerName.contains('br') ||
        lowerName.contains('brazil') ||
        lowerName.contains('巴西')) {
      return '🇧🇷';
    } else if (lowerName.contains('ar') ||
        lowerName.contains('argentina') ||
        lowerName.contains('阿根廷')) {
      return '🇦🇷';
    } else if (lowerName.contains('cl') ||
        lowerName.contains('chile') ||
        lowerName.contains('智利')) {
      return '🇨🇱';
    } else if (lowerName.contains('pe') ||
        lowerName.contains('peru') ||
        lowerName.contains('秘鲁')) {
      return '🇵🇪';
    } else if (lowerName.contains('co') ||
        lowerName.contains('colombia') ||
        lowerName.contains('哥伦比亚')) {
      return '🇨🇴';
    } else if (lowerName.contains('ve') ||
        lowerName.contains('venezuela') ||
        lowerName.contains('委内瑞拉')) {
      return '🇻🇪';
    }

    // 非洲
    else if (lowerName.contains('za') ||
        lowerName.contains('south africa') ||
        lowerName.contains('南非')) {
      return '🇿🇦';
    } else if (lowerName.contains('eg') ||
        lowerName.contains('egypt') ||
        lowerName.contains('埃及')) {
      return '🇪🇬';
    } else if (lowerName.contains('ng') ||
        lowerName.contains('nigeria') ||
        lowerName.contains('尼日利亚')) {
      return '🇳🇬';
    } else if (lowerName.contains('ke') ||
        lowerName.contains('kenya') ||
        lowerName.contains('肯尼亚')) {
      return '🇰🇪';
    } else if (lowerName.contains('tz') ||
        lowerName.contains('tanzania') ||
        lowerName.contains('坦桑尼亚')) {
      return '🇹🇿';
    }

    // 大洋洲
    else if (lowerName.contains('au') ||
        lowerName.contains('australia') ||
        lowerName.contains('澳大利亚')) {
      return '🇦🇺';
    } else if (lowerName.contains('nz') ||
        lowerName.contains('new zealand') ||
        lowerName.contains('新西兰')) {
      return '🇳🇿';
    }

    // 中东
    else if (lowerName.contains('ae') ||
        lowerName.contains('emirates') ||
        lowerName.contains('阿联酋')) {
      return '🇦🇪';
    } else if (lowerName.contains('sa') ||
        lowerName.contains('saudi') ||
        lowerName.contains('沙特')) {
      return '🇸🇦';
    } else if (lowerName.contains('il') ||
        lowerName.contains('israel') ||
        lowerName.contains('以色列')) {
      return '🇮🇱';
    } else if (lowerName.contains('ir') ||
        lowerName.contains('iran') ||
        lowerName.contains('伊朗')) {
      return '🇮🇷';
    } else if (lowerName.contains('iq') ||
        lowerName.contains('iraq') ||
        lowerName.contains('伊拉克')) {
      return '🇮🇶';
    }

    return '🌐';
  }

  Group? _getCurrentGroup(
      List<Group> groups, Mode mode, Map<String, String> selectedMap) {
    if (groups.isEmpty) return null;

    Group? currentGroup;

    if (mode == Mode.global) {
      currentGroup = groups.firstWhere(
        (group) => group.name == GroupName.GLOBAL.name,
        orElse: () => groups.first,
      );
    } else if (mode == Mode.rule) {
      for (final group in groups) {
        if (group.hidden == true) continue;
        if (group.name == GroupName.GLOBAL.name) continue;

        final selectedProxyName = selectedMap[group.name];
        if (selectedProxyName != null && selectedProxyName.isNotEmpty) {
          final referencedGroup = groups.firstWhere(
            (g) => g.name == selectedProxyName,
            orElse: () => group,
          );

          if (referencedGroup.name == selectedProxyName &&
              referencedGroup.type == GroupType.URLTest) {
            currentGroup = referencedGroup;
            break;
          } else {
            currentGroup = group;
            break;
          }
        }
      }

      if (currentGroup == null) {
        currentGroup = groups.firstWhere(
          (group) =>
              group.hidden != true && group.name != GroupName.GLOBAL.name,
          orElse: () => groups.first,
        );

        if (currentGroup.now != null && currentGroup.now!.isNotEmpty) {
          final nowValue = currentGroup.now!;
          final referencedGroup = groups.firstWhere(
            (g) => g.name == nowValue,
            orElse: () => currentGroup!,
          );

          if (referencedGroup.name == nowValue &&
              referencedGroup.type == GroupType.URLTest) {
            currentGroup = referencedGroup;
          }
        }
      }
    }

    return currentGroup;
  }
}
