import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/custom/proxy_providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import 'icon.dart';
import 'proxies.dart';

class CustomProxyGroupsView extends ConsumerWidget {
  final int profileId;

  const CustomProxyGroupsView(this.profileId, {super.key});

  void _handleReorder(
    WidgetRef ref,
    int profileId,
    int oldIndex,
    int newIndex,
  ) {
    ref.read(proxyGroupsProvider(profileId).notifier).order(oldIndex, newIndex);
  }

  void _handleEditProxyGroup(
    BuildContext context,
    ProxyGroup proxyGroup,
    int index,
  ) {
    showSheet(
      context: context,
      props: SheetProps(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        maxWidth: double.maxFinite,
      ),
      builder: (context) {
        return ProfileIdProvider(
          profileId: profileId,
          child: ProviderScope(
            overrides: [
              proxyGroupProvider.overrideWithBuild((_, _) => proxyGroup),
            ],
            child: AddOrEditProxyGroupNestedSheet(),
          ),
        );
      },
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required ProxyGroup proxyGroup,
    required int index,
    required int total,
    required VoidCallback onPressed,
  }) {
    final position = ItemPosition.get(index, total);
    return ItemPositionProvider(
      key: ValueKey(proxyGroup.name),
      position: position,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: DecorationListItem(
          onPressed: onPressed,
          contentPadding: EdgeInsets.only(left: 16, right: 0),
          minVerticalPadding: 8,
          leading: SizedBox.square(
            dimension: 32,
            child: IconTheme.merge(
              data: IconThemeData(size: 32),
              child: CommonTargetIcon(src: proxyGroup.icon ?? ''),
            ),
          ),
          title: TooltipText(
            text: Text(
              proxyGroup.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Text(proxyGroup.type.name),
          trailing: ReorderableDelayedDragStartListener(
            index: index,
            child: Container(
              color: Colors.transparent,
              padding: EdgeInsets.all(16),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ),
      ),
    );
  }

  void _handleAdd(BuildContext context) {
    showSheet(
      context: context,
      props: SheetProps(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        maxWidth: double.maxFinite,
      ),
      builder: (context) {
        return ProfileIdProvider(
          profileId: profileId,
          child: ProviderScope(
            overrides: [
              proxyGroupProvider.overrideWithBuild(
                (_, _) =>
                    ProxyGroup(id: -1, name: '', type: GroupType.Selector),
              ),
            ],
            child: AddOrEditProxyGroupNestedSheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyGroups = ref.watch(proxyGroupsProvider(profileId)).value ?? [];
    return CommonScaffold(
      title: appLocalizations.proxyGroup,
      actions: [
        CommonMinFilledButtonTheme(
          child: FilledButton(
            onPressed: () {
              _handleAdd(context);
            },
            child: Text(appLocalizations.add),
          ),
        ),
        SizedBox(width: 8),
      ],
      body: proxyGroups.isEmpty
          ? NullStatus(label: appLocalizations.proxyGroupEmpty)
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.symmetric(vertical: 12).copyWith(bottom: 24),
              itemBuilder: (context, index) {
                final proxyGroup = proxyGroups[index];
                return _buildItem(
                  context: context,
                  proxyGroup: proxyGroup,
                  total: proxyGroups.length,
                  index: index,
                  onPressed: () {
                    _handleEditProxyGroup(context, proxyGroup, index);
                  },
                );
              },
              proxyDecorator: (child, index, animation) {
                final proxyGroup = proxyGroups[index];
                return commonProxyDecorator(
                  _buildItem(
                    context: context,
                    proxyGroup: proxyGroup,
                    total: proxyGroups.length,
                    index: index,
                    onPressed: () {
                      _handleEditProxyGroup(context, proxyGroup, index);
                    },
                  ),
                  index,
                  animation,
                );
              },
              itemCount: proxyGroups.length,
              onReorder: (oldIndex, newIndex) {
                _handleReorder(ref, profileId, oldIndex, newIndex);
              },
            ),
    );
  }
}

bool _handleSaveProxyGroup(BuildContext context, WidgetRef ref) {
  final proxyGroup = ref.read(proxyGroupProvider);
  if (proxyGroup.name.isEmpty) {
    globalState.showMessage(
      message: TextSpan(text: appLocalizations.proxyGroupNameEmpty),
      cancelable: false,
    );
    return false;
  }
  final profileId = ProfileIdProvider.of(context)!.profileId;
  final ProxyGroup newProxyGroup;
  if (proxyGroup.id == -1) {
    newProxyGroup = proxyGroup.copyWith(id: snowflake.id);
  } else {
    newProxyGroup = proxyGroup;
  }
  final isRepeat = ref
      .read(proxyGroupsProvider(profileId).notifier)
      .put(newProxyGroup);
  if (isRepeat == false) {
    globalState.showMessage(
      message: TextSpan(text: appLocalizations.proxyGroupNameDuplicate),
      cancelable: false,
    );
    return false;
  } else {
    return true;
  }
}

class AddOrEditProxyGroupNestedSheet extends ConsumerStatefulWidget {
  const AddOrEditProxyGroupNestedSheet({super.key});

  @override
  ConsumerState<AddOrEditProxyGroupNestedSheet> createState() =>
      _AddOrEditProxyGroupNestedSheetState();
}

class _AddOrEditProxyGroupNestedSheetState
    extends ConsumerState<AddOrEditProxyGroupNestedSheet> {
  final GlobalKey<NavigatorState> _nestedNavigatorKey = GlobalKey();
  late final ProxyGroup _originProxyGroup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _originProxyGroup = ref.read(proxyGroupProvider);
    });
  }

  Future<void> _handleClose() async {
    final state = _nestedNavigatorKey.currentState;
    if (state != null && state.canPop()) {
      final res = await globalState.showMessage(
        message: TextSpan(text: appLocalizations.confirmExitWindow),
      );
      if (res != true) {
        return;
      }
    }
    if (context.mounted) {
      _handleExit();
    }
  }

  Future<void> _handleExit() async {
    final proxyGroup = ref.read(proxyGroupProvider);
    if (_originProxyGroup == proxyGroup) {
      Navigator.of(context).pop();
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.dataChangedSave),
    );
    if (!mounted) {
      return;
    }
    if (res != true) {
      Navigator.of(context).pop();
      return;
    }
    if (_handleSaveProxyGroup(context, ref)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePop() async {
    final state = _nestedNavigatorKey.currentState;
    if (state != null && state.canPop()) {
      state.pop();
    } else {
      _handleExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nestedNavigator = Navigator(
      key: _nestedNavigatorKey,
      onGenerateInitialRoutes: (navigator, initialRoute) {
        return [
          PagedSheetRoute(
            builder: (context) {
              return _EditProxyGroupView();
            },
          ),
        ];
      },
    );
    final sheetProvider = SheetProvider.of(context);
    return CommonPopScope(
      onPop: (_) async {
        _handlePop();
        return false;
      },
      child: sheetProvider!.copyWith(
        nestedNavigatorPop: ([data]) {
          Navigator.of(context).pop(data);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () async {
                  _handleClose();
                },
              ),
            ),
            SizedBox(
              width: sheetProvider.type == SheetType.sideSheet ? 400 : null,
              child: SheetViewport(
                child: PagedSheet(
                  decoration: MaterialSheetDecoration(
                    size: SheetSize.stretch,
                    color: sheetProvider.type == SheetType.bottomSheet
                        ? context.colorScheme.surfaceContainerLow
                        : context.colorScheme.surface,
                    borderRadius: sheetProvider.type == SheetType.bottomSheet
                        ? BorderRadius.vertical(top: Radius.circular(28))
                        : BorderRadius.zero,
                    clipBehavior: Clip.antiAlias,
                  ),
                  navigator: nestedNavigator,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProxyGroupView extends ConsumerStatefulWidget {
  const _EditProxyGroupView();

  @override
  ConsumerState createState() => _EditProxyGroupViewState();
}

class _EditProxyGroupViewState extends ConsumerState<_EditProxyGroupView> {
  Future<void> _showTypeOptions(GroupType type) async {
    final value = await globalState.showCommonDialog<GroupType>(
      child: OptionsDialog<GroupType>(
        title: appLocalizations.proxyType,
        options: GroupType.values,
        textBuilder: (item) => item.name,
        value: type,
      ),
    );
    if (value == null) {
      return;
    }
    ref
        .read(proxyGroupProvider.notifier)
        .update((state) => state.copyWith(type: value));
  }

  Future<void> _showIconEdit(String? icon) async {
    final value = await Navigator.of(
      context,
    ).push<String>(PagedSheetRoute(builder: (context) => IconEditView(icon)));
    if (value == null) {
      return;
    }
    ref
        .read(proxyGroupProvider.notifier)
        .update((state) => state.copyWith(icon: value));
  }

  Widget _buildItem({
    required Widget title,
    Widget? trailing,
    final VoidCallback? onPressed,
  }) {
    return DecorationListItem(
      onPressed: onPressed,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 16,
        children: [
          title,
          if (trailing != null)
            Flexible(
              child: IconTheme(
                data: IconThemeData(
                  size: 16,
                  color: context.colorScheme.onSurface.opacity60,
                ),
                child: Container(
                  alignment: Alignment.centerRight,
                  height: globalState.measure.bodyLargeHeight + 24,
                  child: trailing,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleToProxiesView() {
    Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => EditProxiesView()));
  }

  void _handleToProvidersView() {
    Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => EditProxyProvidersView()));
  }

  Widget _buildProvidersItem(bool includeAllProviders, List<String> use) {
    return _buildItem(
      title: Text(appLocalizations.selectProxyProviders),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          !includeAllProviders
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    constraints: BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    height: globalState.measure.bodySmallHeight + 6,
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: Text(
                      textAlign: TextAlign.center,
                      '${use.length}',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                )
              : Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.greenAccent.shade200,
                ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
      onPressed: _handleToProvidersView,
    );
  }

  Widget _buildFilterItem(String? filter) {
    return _buildItem(
      title: Text(appLocalizations.proxyFilter),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: filter,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(filter: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildMaxFailedTimesItem(int? maxFailedTimes) {
    return _buildItem(
      title: Text(appLocalizations.maxFailedTimes),
      trailing: TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.end,
        initialValue: maxFailedTimes?.toString(),
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update(
                (state) => state.copyWith(maxFailedTimes: int.tryParse(value)),
              );
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildUrlItem(String? url) {
    return _buildItem(
      title: Text(appLocalizations.testUrl),
      trailing: TextFormField(
        keyboardType: TextInputType.url,
        textAlign: TextAlign.end,
        initialValue: url,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(url: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildIntervalItem(int? interval) {
    return _buildItem(
      title: Text(appLocalizations.testInterval),
      trailing: TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.end,
        initialValue: interval?.toString(),
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(interval: int.tryParse(value)));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildExcludeFilterItem(String? excludeFilter) {
    return _buildItem(
      title: Text(appLocalizations.excludeProxyFilter),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: excludeFilter,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(excludeFilter: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildExcludeTypeItem(String? type) {
    return _buildItem(
      title: Text(appLocalizations.excludeType),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: type,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(excludeType: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildExpectedStatusItem(String? expectedStatus) {
    return _buildItem(
      title: Text(appLocalizations.expectedStatus),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: expectedStatus,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(expectedStatus: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.optional,
        ),
      ),
    );
  }

  Widget _buildProxiesItem(bool includeAllProxies, List<String> proxies) {
    return _buildItem(
      title: Text(appLocalizations.selectProxies),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          !includeAllProxies
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    constraints: BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    height: globalState.measure.bodySmallHeight + 6,
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: Text(
                      textAlign: TextAlign.center,
                      '${proxies.length}',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                )
              : Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.greenAccent.shade200,
                ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
      onPressed: _handleToProxiesView,
    );
  }

  Widget _buildTypeItem(GroupType type) {
    return _buildItem(
      title: Text(appLocalizations.proxyType),
      onPressed: () {
        _showTypeOptions(type);
      },
      trailing: Text(type.name),
    );
  }

  Widget _buildIconItem(String? icon) {
    return _buildItem(
      title: Text(appLocalizations.icon),
      onPressed: () {
        _showIconEdit(icon);
      },
      trailing: TooltipText(
        text: Text(
          icon ?? appLocalizations.optional,
          maxLines: 1,
          style: context.textTheme.bodyLarge?.copyWith(
            color: icon == null ? context.colorScheme.onSurfaceVariant : null,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildNameItem(String name) {
    return _buildItem(
      title: Text(appLocalizations.name),
      trailing: TextFormField(
        initialValue: name,
        keyboardType: TextInputType.name,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(name: value));
        },
        onFieldSubmitted: (_) {
          _handleSave();
        },
        textAlign: TextAlign.end,
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: appLocalizations.inputProxyGroupName,
        ),
      ),
    );
  }

  Widget _buildHiddenItem(bool? hidden) {
    void handleChangeHidden() {
      ref
          .read(proxyGroupProvider.notifier)
          .update((state) => state.copyWith(hidden: !(hidden ?? false)));
    }

    return _buildItem(
      title: Text(appLocalizations.hideFromList),
      onPressed: handleChangeHidden,
      trailing: Switch(
        value: hidden ?? false,
        onChanged: (_) {
          handleChangeHidden();
        },
      ),
    );
  }

  Widget _buildLazyItem(bool? lazy) {
    void handleChangeLazy() {
      ref
          .read(proxyGroupProvider.notifier)
          .update((state) => state.copyWith(lazy: !(lazy ?? false)));
    }

    return _buildItem(
      title: Text(appLocalizations.testWhenUsed),
      onPressed: handleChangeLazy,
      trailing: Switch(
        value: lazy ?? false,
        onChanged: (_) {
          handleChangeLazy();
        },
      ),
    );
  }

  Widget _buildDisableUDPItem(bool? disableUDP) {
    void handleChangeDisableUDP() {
      ref
          .read(proxyGroupProvider.notifier)
          .update(
            (state) => state.copyWith(disableUDP: !(disableUDP ?? false)),
          );
    }

    return _buildItem(
      title: Text(appLocalizations.disableUDP),
      onPressed: handleChangeDisableUDP,
      trailing: Switch(
        value: disableUDP ?? false,
        onChanged: (_) {
          handleChangeDisableUDP();
        },
      ),
    );
  }

  Future<void> _handleDelete(int profileId, String name) async {
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.confirmDeleteProxyGroup),
    );
    if (res == true && mounted) {
      ref.read(proxyGroupsProvider(profileId).notifier).del(name);
      context.safeNestedPop();
    }
  }

  Future<void> _handleSave() async {
    if (_handleSaveProxyGroup(context, ref)) {
      context.safeNestedPop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final proxyGroup = ref.watch(proxyGroupProvider);
    final height = ref.watch(
      viewSizeProvider.select(
        (state) => isBottomSheet ? state.height * 0.65 : double.maxFinite,
      ),
    );
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      actions: [IconButtonData(icon: Icons.check, onPressed: _handleSave)],
      body: SizedBox(
        height: height,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: 20, top: context.sheetTopPadding),
          children: [
            generateSectionV3(
              title: appLocalizations.general,
              items: [
                _buildNameItem(proxyGroup.name),
                _buildTypeItem(proxyGroup.type),
                _buildIconItem(proxyGroup.icon),
                _buildHiddenItem(proxyGroup.hidden),
                _buildDisableUDPItem(proxyGroup.disableUDP),
              ],
            ),
            generateSectionV3(
              title: appLocalizations.proxies,
              items: [
                _buildProxiesItem(
                  proxyGroup.includeAllProxies ?? false,
                  proxyGroup.proxies ?? [],
                ),
                _buildProvidersItem(
                  proxyGroup.includeAllProviders ?? false,
                  proxyGroup.use ?? [],
                ),
                _buildFilterItem(proxyGroup.filter),
                _buildExcludeFilterItem(proxyGroup.excludeFilter),
                _buildExcludeTypeItem(proxyGroup.excludeType),
                _buildExpectedStatusItem(proxyGroup.expectedStatus),
              ],
            ),
            generateSectionV3(
              title: appLocalizations.other,
              items: [
                _buildUrlItem(proxyGroup.url),
                _buildMaxFailedTimesItem(proxyGroup.maxFailedTimes),
                _buildLazyItem(proxyGroup.lazy),
                _buildIntervalItem(proxyGroup.interval),
              ],
            ),
            generateSectionV3(
              title: appLocalizations.action,
              items: [
                if (proxyGroup.id != -1)
                  _buildItem(
                    title: Text(
                      appLocalizations.delete,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                    onPressed: () {
                      _handleDelete(profileId, proxyGroup.name);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      title: proxyGroup.id == -1
          ? appLocalizations.addProxyGroup
          : appLocalizations.editProxyGroup,
    );
  }
}
