import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/overwrite/overwrite.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class EditProxiesView extends ConsumerStatefulWidget {
  const EditProxiesView({super.key});

  @override
  ConsumerState<EditProxiesView> createState() => _EditProxiesViewState();
}

class _EditProxiesViewState extends ConsumerState<EditProxiesView>
    with UniqueKeyStateMixin, OverwriteStageFlowMixin<EditProxiesView> {
  @override
  void initState() {
    super.initState();
    listenForStageChanges(
      tag: 'EditProxiesViewState_handleRealRemove',
      apply: (state, staged) {
        final next = List<String>.from(state.proxies ?? []);
        next.removeWhere((item) => staged.contains(item));
        return state.copyWith(proxies: next);
      },
    );
  }

  void _handleToAddProxiesView() {
    Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => const _AddProxiesView()));
  }

  Widget _buildItem({
    required String proxyName,
    required String? proxyType,
    required int index,
    required int length,
    required ItemPosition position,
    required bool dismiss,
  }) {
    return OverwriteDismissItem(
      key: ValueKey(proxyName),
      title: proxyName,
      subtitle:
          proxyType ??
          (RuleTarget.baseTargets.contains(proxyName)
              ? proxyName.toLowerCase()
              : null),
      position: position,
      dismiss: dismiss,
      index: index,
      isValidOf: (ref, profileId, title) {
        return ref.watch(
          customOverwriteTargetIsValidProvider(profileId, title),
        );
      },
      invalidMessageOf: (context, title) {
        return context.appLocalizations.invalidProxy(title);
      },
      onRemove: () => handleStage(proxyName),
      onDismissed: () {
        handleRealStage(
          tag: 'EditProxiesViewState_handleRealRemove',
          apply: (state, staged) {
            final next = List<String>.from(state.proxies ?? []);
            next.removeWhere((item) => staged.contains(item));
            return state.copyWith(proxies: next);
          },
        );
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    ref.read(proxyGroupProvider.notifier).update((state) {
      final nextItems = (state.proxies ?? []).copyAndReorder(
        oldIndex,
        newIndex,
      );
      return state.copyWith(proxies: nextItems);
    });
  }

  void _handleChangeIncludeAllProxies() {
    ref
        .read(proxyGroupProvider.notifier)
        .update(
          (state) => state.copyWith(
            includeAllProxies: !(state.includeAllProxies ?? false),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final vm2 = ref.watch(
      proxyGroupProvider.select(
        (state) => VM2(state.includeAllProxies ?? false, state.proxies ?? []),
      ),
    );
    final dismissItems = ref.watch(itemsProvider(key));
    final includeAllProxies = vm2.a;
    final proxyNames = vm2.b;
    final proxyTypeMap =
        ref.watch(
          clashConfigProvider(
            profileId,
          ).select((state) => state.value?.proxyTypeMap),
        ) ??
        {};
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final height = isBottomSheet
        ? ref.read(viewSizeProvider).height * 0.85
        : double.maxFinite;
    return SizedBox(
      height: height,
      child: AdaptiveSheetScaffold(
        title: appLocalizations.editProxy,
        sheetTransparentToolBar: true,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: context.sheetTopPadding + 8),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: CommonCard(
                  radius: 20,
                  type: CommonCardType.filled,
                  child: ListItem.toggle(
                    minTileHeight: 54,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(appLocalizations.includeAllProxies),
                        CommonMinIconButtonTheme(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              globalState.showMessage(
                                title: appLocalizations.tip,
                                message: TextSpan(
                                  text: appLocalizations.includeAllProxiesTip,
                                ),
                                cancelable: false,
                              );
                            },
                            icon: Icon(
                              size: 16.ap,
                              Icons.info_outline,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    value: includeAllProxies,
                    onChanged: (_) {
                      _handleChangeIncludeAllProxies();
                    },
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: InfoHeader(
                  info: Info(label: appLocalizations.proxies),
                  actions: [
                    CommonMinFilledButtonTheme(
                      child: FilledButton.tonal(
                        onPressed: _handleToAddProxiesView,
                        child: Text(appLocalizations.add),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (proxyNames.isNotEmpty)
              SliverReorderableList(
                itemBuilder: (_, index) {
                  final proxyName = proxyNames[index];
                  final position = ItemPosition.calculateVisualPosition(
                    index,
                    proxyNames,
                    dismissItems,
                  );
                  return _buildItem(
                    position: position,
                    dismiss: dismissItems.contains(proxyName),
                    proxyName: proxyName,
                    proxyType: proxyTypeMap[proxyName],
                    index: index,
                    length: proxyNames.length,
                  );
                },
                itemCount: proxyNames.length,
                proxyDecorator: (child, index, animation) {
                  final proxyName = proxyNames[index];
                  final position = ItemPosition.calculateVisualPosition(
                    index,
                    proxyNames,
                    dismissItems,
                  );
                  return commonProxyDecorator(
                    _buildItem(
                      position: position,
                      dismiss: dismissItems.contains(proxyName),
                      proxyName: proxyName,
                      proxyType: proxyTypeMap[proxyName],
                      index: index,
                      length: proxyNames.length,
                    ),
                    index,
                    animation,
                  );
                },
                onReorderItem: (int oldIndex, int newIndex) {
                  _handleReorder(oldIndex, newIndex);
                },
              )
            else
              SliverFillRemaining(
                child: NullStatus(label: appLocalizations.proxiesEmpty),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _AddProxiesView extends ConsumerStatefulWidget {
  const _AddProxiesView();

  @override
  ConsumerState<_AddProxiesView> createState() => _AddProxiesViewState();
}

class _AddProxiesViewState extends ConsumerState<_AddProxiesView>
    with UniqueKeyStateMixin, OverwriteStageFlowMixin<_AddProxiesView> {
  @override
  void initState() {
    super.initState();
    for (final scene in ['groups', 'proxies', 'targets']) {
      listenForStageChanges(
        tag: 'AddProxiesViewState_handleRealAdd_$scene',
        scene: scene,
        duration: const Duration(milliseconds: 350),
        apply: (state, staged) {
          return state.copyWith(proxies: [...state.proxies ?? [], ...staged]);
        },
      );
    }
  }

  Widget _buildItem({
    required String title,
    required String subtitle,
    required ItemPosition position,
    required bool dismiss,
    required VoidCallback onAdd,
  }) {
    return ExternalDismissible(
      effect: ExternalDismissibleEffect.resize,
      key: ValueKey(title),
      dismiss: dismiss,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ItemPositionProvider(
          position: position,
          child: DecorationListItem(
            minVerticalPadding: 8,
            title: TooltipText(
              text: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            subtitle: Text(subtitle),
            trailing: CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final height = isBottomSheet
        ? ref.read(viewSizeProvider).height * 0.8
        : double.maxFinite;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final dismissGroups = ref.watch(itemsProvider('${key}_groups'));
    final dismissProxies = ref.watch(itemsProvider('${key}_proxies'));
    final dismissTargets = ref.watch(itemsProvider('${key}_targets'));
    final excludeProxyNames = ref
        .watch(
          proxyGroupProvider.select((state) {
            return VM(<String>{...?state.proxies, state.name});
          }),
        )
        .a;
    final vm2 = ref.watch(
      customOverwriteDateProvider(profileId).select((state) {
        final filteredProxies = <Proxy>[];
        final filteredGroups = <ProxyGroup>[];
        for (final item in state.proxies) {
          if (!excludeProxyNames.contains(item.name)) {
            filteredProxies.add(item);
          }
        }
        for (final item in state.proxyGroups) {
          if (!excludeProxyNames.contains(item.name)) {
            filteredGroups.add(item);
          }
        }
        return VM2(filteredProxies, filteredGroups);
      }),
    );
    final proxies = vm2.a;
    final proxyGroups = vm2.b;
    final targets = <String>[];
    for (final item in RuleTarget.baseTargets) {
      if (!excludeProxyNames.contains(item)) {
        targets.add(item);
      }
    }
    final groupNames = proxyGroups.map((item) => item.name).toList();
    final proxyNames = proxies.map((item) => item.name).toList();
    return SizedBox(
      height: height,
      child: AdaptiveSheetScaffold(
        sheetTransparentToolBar: true,
        title: appLocalizations.addProxies,
        body: proxies.isEmpty && proxyGroups.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.sheetTopPadding),
                  ),
                  if (targets.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(
                          info: Info(label: appLocalizations.basicStrategy),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final target = targets[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          targets,
                          dismissTargets,
                        );
                        return _buildItem(
                          title: target,
                          subtitle: target.toLowerCase(),
                          position: position,
                          dismiss: dismissTargets.contains(target),
                          onAdd: () {
                            handleStage(target, 'targets');
                          },
                        );
                      }, childCount: targets.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                  if (proxyGroups.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(
                          info: Info(label: appLocalizations.proxyGroup),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final proxyGroup = proxyGroups[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          groupNames,
                          dismissGroups,
                        );
                        return _buildItem(
                          title: proxyGroup.name,
                          subtitle: proxyGroup.type.value,
                          position: position,
                          dismiss: dismissGroups.contains(proxyGroup.name),
                          onAdd: () {
                            handleStage(proxyGroup.name, 'groups');
                          },
                        );
                      }, childCount: proxyGroups.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                  if (proxies.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(
                          info: Info(label: appLocalizations.proxies),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final proxy = proxies[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          proxyNames,
                          dismissProxies,
                        );
                        return _buildItem(
                          title: proxy.name,
                          subtitle: proxy.type,
                          position: position,
                          dismiss: dismissProxies.contains(proxy.name),
                          onAdd: () {
                            handleStage(proxy.name, 'proxies');
                          },
                        );
                      }, childCount: proxies.length),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
      ),
    );
  }
}
