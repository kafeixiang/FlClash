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

class EditProxyProvidersView extends ConsumerStatefulWidget {
  const EditProxyProvidersView({super.key});

  @override
  ConsumerState<EditProxyProvidersView> createState() =>
      _EditProxyProvidersViewState();
}

class _EditProxyProvidersViewState extends ConsumerState<EditProxyProvidersView>
    with UniqueKeyStateMixin, OverwriteStageFlowMixin<EditProxyProvidersView> {
  @override
  void initState() {
    super.initState();
    listenForStageChanges(
      tag: 'EditProxyProvidersViewState_handleRealRemove',
      apply: (state, staged) {
        final next = List<String>.from(state.use ?? []);
        next.removeWhere((item) => staged.contains(item));
        return state.copyWith(use: next);
      },
    );
  }

  void _handleToAddProxyProvidersView() {
    Navigator.of(context).push(
      PagedSheetRoute(builder: (context) => const _AddProxyProvidersView()),
    );
  }

  Widget _buildItem({
    required String providerName,
    required int index,
    required int length,
    required ItemPosition position,
    required bool dismiss,
  }) {
    return OverwriteDismissItem(
      key: ValueKey(providerName),
      title: providerName,
      position: position,
      dismiss: dismiss,
      index: index,
      dragIconPadding: 16,
      isValidOf: (ref, profileId, title) {
        return ref.watch(
          customOverwriteProxyProviderIsValidProvider(profileId, title),
        );
      },
      invalidMessageOf: (context, title) {
        return context.appLocalizations.invalidProxyProvider(title);
      },
      onRemove: () => handleStage(providerName),
      onDismissed: () {
        handleRealStage(
          tag: 'EditProxyProvidersViewState_handleRealRemove',
          apply: (state, staged) {
            final next = List<String>.from(state.use ?? []);
            next.removeWhere((item) => staged.contains(item));
            return state.copyWith(use: next);
          },
        );
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    ref.read(proxyGroupProvider.notifier).update((state) {
      final nextItems = (state.use ?? []).copyAndReorder(oldIndex, newIndex);
      return state.copyWith(use: nextItems);
    });
  }

  void _handleChangeIncludeAllProxyProviders() {
    ref
        .read(proxyGroupProvider.notifier)
        .update(
          (state) => state.copyWith(
            includeAllProviders: !(state.includeAllProviders ?? false),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final vm2 = ref.watch(
      proxyGroupProvider.select(
        (state) => VM2(state.includeAllProviders ?? false, state.use ?? []),
      ),
    );
    final dismissItems = ref.watch(itemsProvider(key));
    final includeAllProxyProviders = vm2.a;
    final proxyProviderNames = vm2.b;
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
                        Text(appLocalizations.includeAllProxyProviders),
                        CommonMinIconButtonTheme(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              globalState.showMessage(
                                title: appLocalizations.tip,
                                message: TextSpan(
                                  text: appLocalizations
                                      .includeAllProxyProvidersTip,
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
                    value: includeAllProxyProviders,
                    onChanged: (_) {
                      _handleChangeIncludeAllProxyProviders();
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
                  info: Info(label: appLocalizations.proxyProviders),
                  actions: [
                    CommonMinFilledButtonTheme(
                      child: FilledButton.tonal(
                        onPressed: _handleToAddProxyProvidersView,
                        child: Text(appLocalizations.add),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (proxyProviderNames.isNotEmpty)
              SliverReorderableList(
                itemBuilder: (_, index) {
                  final providerName = proxyProviderNames[index];
                  final position = ItemPosition.calculateVisualPosition(
                    index,
                    proxyProviderNames,
                    dismissItems,
                  );
                  return _buildItem(
                    position: position,
                    dismiss: dismissItems.contains(providerName),
                    providerName: providerName,
                    index: index,
                    length: proxyProviderNames.length,
                  );
                },
                itemCount: proxyProviderNames.length,
                proxyDecorator: (child, index, animation) {
                  final providerName = proxyProviderNames[index];
                  final position = ItemPosition.calculateVisualPosition(
                    index,
                    proxyProviderNames,
                    dismissItems,
                  );
                  return commonProxyDecorator(
                    _buildItem(
                      position: position,
                      dismiss: dismissItems.contains(providerName),
                      providerName: providerName,
                      index: index,
                      length: proxyProviderNames.length,
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
                hasScrollBody: false,
                child: NullStatus(label: appLocalizations.proxyProvidersEmpty),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _AddProxyProvidersView extends ConsumerStatefulWidget {
  const _AddProxyProvidersView();

  @override
  ConsumerState<_AddProxyProvidersView> createState() =>
      _AddProxyProvidersViewState();
}

class _AddProxyProvidersViewState extends ConsumerState<_AddProxyProvidersView>
    with UniqueKeyStateMixin, OverwriteStageFlowMixin<_AddProxyProvidersView> {
  @override
  void initState() {
    super.initState();
    listenForStageChanges(
      tag: 'AddProxyProvidersViewState_handleRealAdd',
      duration: const Duration(milliseconds: 350),
      apply: (state, staged) {
        return state.copyWith(use: [...state.use ?? [], ...staged]);
      },
    );
  }

  Widget _buildItem({
    required String title,
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
            title: Text(title),
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
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final dismissProxyProviders = ref.watch(itemsProvider(key));
    final allProxyProviders = ref
        .watch(
          clashConfigProvider(
            profileId,
          ).select((state) => VM(state.value?.proxyProviders ?? [])),
        )
        .a;
    final excludeProxyProviderNames = ref
        .watch(
          proxyGroupProvider.select((state) {
            return VM([...?state.use]);
          }),
        )
        .a;
    final providerNames = allProxyProviders
        .where((item) => !excludeProxyProviderNames.contains(item))
        .toList();
    final height = isBottomSheet
        ? ref.read(viewSizeProvider).height * 0.80
        : double.maxFinite;
    return SizedBox(
      height: height,
      child: AdaptiveSheetScaffold(
        sheetTransparentToolBar: true,
        title: appLocalizations.addProxyProviders,
        body: providerNames.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.sheetTopPadding),
                  ),
                  if (providerNames.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(
                          info: Info(label: appLocalizations.proxyProviders),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final providerName = providerNames[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          providerNames,
                          dismissProxyProviders,
                        );
                        return _buildItem(
                          title: providerName,
                          position: position,
                          dismiss: dismissProxyProviders.contains(providerName),
                          onAdd: () {
                            handleStage(providerName);
                          },
                        );
                      }, childCount: providerNames.length),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
