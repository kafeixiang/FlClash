import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_edit.dart';

class CustomProxiesView extends ConsumerStatefulWidget {
  const CustomProxiesView({super.key});

  @override
  ConsumerState createState() => _CustomProxiesViewState();
}

class _CustomProxiesViewState extends ConsumerState<CustomProxiesView> {
  late final ClashProvidersAction _providersAction;
  final _seenNames = <String>{};
  List<CustomProxy>? _opened;
  List<CustomProxy>? _latest;
  final _searchTexts = Expando<String>();
  var _query = SearchQuery('');
  String? _type;
  var _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _providersAction = ref.read(clashProvidersActionProvider.notifier);
    ref.listenManual(customProxiesProvider, (_, next) {
      final proxies = next.value;
      if (proxies == null) {
        return;
      }
      _seenNames.addAll([for (final proxy in proxies) proxy.name]);
      _opened ??= proxies;
      _latest = proxies;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    if (!customProxiesEquality.equals(_opened, _latest)) {
      unawaited(_providersAction.applyIfProxiesNamed(_seenNames));
    }
    super.dispose();
  }

  void _handleReorder(int oldIndex, int newIndex) {
    ref.read(customProxiesProvider.notifier).order(oldIndex, newIndex);
  }

  void _handleSearch(String query) {
    setState(() {
      _query = SearchQuery(query);
    });
  }

  void _handleType(String? type) {
    setState(() {
      _type = type;
    });
  }

  void _handleToggleSelected(int id) {
    setState(() {
      _selected = {..._selected}..addOrRemove(id);
    });
  }

  void _handleSelectAll(Set<int> ids) {
    setState(() {
      _selected = _selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleDelete(Set<int> ids, {required Set<int> kept}) async {
    final appLocalizations = context.appLocalizations;
    final message = await _deleteMessage(
      ref,
      ids,
      appLocalizations.deleteMultipTip(appLocalizations.proxies),
    );
    if (!mounted) {
      return;
    }
    final res = await dialogs.showMessage(message: TextSpan(text: message));
    if (res != true || !mounted) {
      return;
    }
    ref.read(customProxiesProvider.notifier).delAll(ids);
    setState(() {
      _selected = kept;
    });
  }

  Future<void> _handleQuickEdit() async {
    final previous = ref.read(customProxiesProvider).value;
    if (previous == null) {
      return;
    }
    final appLocalizations = context.appLocalizations;
    final core = ref.read(coreHandlerProvider);
    final List<String> links;
    try {
      links = await core.encodeShareLinks([
        for (final proxy in previous) proxy.definition,
      ]);
    } catch (error) {
      await dialogs.showMessage(message: TextSpan(text: compactError(error)));
      return;
    }
    if (!mounted) {
      return;
    }
    final notifier = ref.read(customProxiesProvider.notifier);
    return showCustomQuickEdit(
      context,
      title: appLocalizations.proxies,
      content: ShareLinkEdit.textOf(links),
      schema: EditorSchema.shareLinks,
      invalidMessage: appLocalizations.shareLinksInvalid,
      apply: (content) async {
        final edit = ShareLinkEdit.read(
          content,
          previous: previous,
          links: links,
        );
        final decoded = await _decodeShareLinks(core, edit.pending);
        final proxies = edit.apply(
          decoded,
          groupNames: await ref.read(customGroupNamesProvider.future),
        );
        if (!await _confirmReplaced(previous, proxies)) {
          throw const QuickEditCancelled();
        }
        notifier.setAll(proxies);
      },
    );
  }

  /// A line whose name changed is a new proxy: what custom profiles name the
  /// old one by is left missing, so the edit says which go and which come.
  Future<bool> _confirmReplaced(
    List<CustomProxy> previous,
    List<CustomProxy> next,
  ) async {
    final kept = {for (final proxy in next) proxy.id};
    final removed = [
      for (final proxy in previous)
        if (!kept.contains(proxy.id)) proxy.name,
    ];
    if (removed.isEmpty) {
      return true;
    }
    final existed = {for (final proxy in previous) proxy.id};
    final added = [
      for (final proxy in next)
        if (!existed.contains(proxy.id)) proxy.name,
    ];
    final appLocalizations = currentAppLocalizations;
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: added.isEmpty
            ? appLocalizations.proxiesRemovedTip(removed.join(', '))
            : appLocalizations.proxiesReplacedTip(
                removed.join(', '),
                added.join(', '),
              ),
      ),
    );
    return res == true;
  }

  void _handleAddOrUpdate({CustomProxy? proxy}) {
    showNestedFormSheet<CustomProxy>(
      context: context,
      profileId: null,
      overrides: [
        customProxyProvider.overrideWithBuild(
          (_, _) =>
              proxy ??
              const CustomProxy(id: -1, definition: {'name': '', 'type': 'ss'}),
        ),
      ],
      currentOf: (ref) => ref.read(customProxyProvider),
      formBuilder: (_) => const _EditCustomProxyView(),
    );
  }

  Widget _buildNode(
    CustomProxy proxy, {
    required Set<int> selected,
    required ItemPosition position,
    int? dragIndex,
  }) {
    final item = ItemPositionProvider(
      position: position,
      child: _NodeItem(
        proxy: proxy,
        isEditing: selected.isNotEmpty,
        isSelected: selected.contains(proxy.id),
        onSelected: () => _handleToggleSelected(proxy.id),
        onPressed: () => _handleAddOrUpdate(proxy: proxy),
      ),
    );
    if (dragIndex == null) {
      return KeyedSubtree(key: ValueKey(proxy.id), child: item);
    }
    return ReorderableDelayedDragStartListener(
      key: ValueKey(proxy.id),
      index: dragIndex,
      child: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final proxies = ref.watch(customProxiesProvider).value;
    final all = proxies ?? const <CustomProxy>[];
    final types = <String, int>{};
    for (final proxy in all) {
      types.update(proxy.type, (count) => count + 1, ifAbsent: () => 1);
    }
    final type = types.containsKey(_type) ? _type : null;
    final visible = all
        .where((proxy) => type == null || proxy.type == type)
        .whereMatches(
          _query,
          (proxy) => proxy.searchFields,
          texts: _searchTexts,
        )
        .toList();
    // Indices among the matches cannot be mapped back onto the full list.
    final reorderable = type == null && _query.isEmpty;
    final selected = _selected.intersection({
      for (final proxy in all) proxy.id,
    });
    final visibleIds = {for (final proxy in visible) proxy.id};
    final visibleSelected = selected.intersection(visibleIds);
    return CommonPopScope(
      onPop: selected.isEmpty
          ? null
          : (_) {
              setState(() {
                _selected = {};
              });
              return false;
            },
      child: CommonScaffold(
        title: appLocalizations.proxies,
        searchState: AppBarSearchState(onSearch: _handleSearch),
        actions: [
          if (selected.isEmpty)
            ListEditorAddAction(
              onAdd: _handleAddOrUpdate,
              onQuickEdit: _handleQuickEdit,
            ),
        ],
        selectionActions: selected.isEmpty
            ? const []
            : [
                IconButtonData(
                  glyph: AppGlyphs.delete,
                  onPressed: visibleSelected.isEmpty
                      ? null
                      : () => _handleDelete(
                          visibleSelected,
                          kept: selected.difference(visibleSelected),
                        ),
                  tooltip: appLocalizations.delete,
                ),
                IconButtonData(
                  glyph: AppGlyphs.selectAll,
                  onPressed: () => _handleSelectAll(visibleIds),
                  tooltip: appLocalizations.selectAll,
                ),
              ],
        body: NullStatusSwitcher(
          isLoading: proxies == null,
          isEmpty: visible.isEmpty,
          isSearching: _query.isNotEmpty,
          nullStatus: NullStatus(
            label: appLocalizations.nullTip(appLocalizations.proxies),
            illustration: NullStatusIllustration.proxies,
            action: ElasticButton(
              child: FilledButton.tonalIcon(
                onPressed: _handleAddOrUpdate,
                icon: const GlyphIcon(AppGlyphs.addCircle, fill: 1),
                label: Text(appLocalizations.add),
              ),
            ),
          ),
          child: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: context.contentTopPadding),
                ),
                if (types.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _TypeFilters(
                        types: types,
                        selected: type,
                        onSelected: _handleType,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + BottomInsetScope.of(context),
                  ),
                  sliver: reorderable
                      ? SliverReorderableList(
                          itemCount: visible.length,
                          itemBuilder: (_, index) => _buildNode(
                            visible[index],
                            selected: selected,
                            position: ItemPosition.get(index, visible.length),
                            dragIndex: index,
                          ),
                          proxyDecorator: (child, index, animation) =>
                              commonProxyDecorator(
                                _buildNode(
                                  visible[index],
                                  selected: selected,
                                  position: ItemPosition.get(
                                    index,
                                    visible.length,
                                  ),
                                  dragIndex: index,
                                ),
                                index,
                                animation,
                              ),
                          onReorderItem: _handleReorder,
                        )
                      : SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (_, index) => _buildNode(
                            visible[index],
                            selected: selected,
                            position: ItemPosition.get(index, visible.length),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Short enough for a filter chip; the rest are read in full.
String _typeLabel(String type) => switch (type) {
  'hysteria2' => 'HY2',
  'hysteria' => 'HY',
  'wireguard' => 'WG',
  _ => type.toUpperCase(),
};

class _TypeFilters extends StatelessWidget {
  final Map<String, int> types;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _TypeFilters({
    required this.types,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: type, value: count) in types.entries)
          _TypeFilterChip(
            label: _typeLabel(type),
            count: count,
            isSelected: type == selected,
            onPressed: () => onSelected(type == selected ? null : type),
          ),
      ],
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onPressed;

  const _TypeFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final textStyle = context.textTheme.labelLarge?.copyWith(
      color: foregroundColor,
    );
    return Material(
      color: isSelected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      shape: AppShape.sm.copyWith(
        side: isSelected
            ? BorderSide.none
            : BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(label, style: textStyle),
              Text(
                '$count',
                style: textStyle?.copyWith(color: foregroundColor.opacity60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeItem extends ConsumerWidget {
  final CustomProxy proxy;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onPressed;

  const _NodeItem({
    required this.proxy,
    required this.isEditing,
    required this.isSelected,
    required this.onSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref
        .watch(
          customProxyListIssuesProvider.select(
            (state) => SelectValue(state[proxy.id] ?? const <CustomIssue>[]),
          ),
        )
        .value;
    return DecorationListItem(
      invalid: issues.isNotEmpty,
      isSelected: isSelected,
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      onPressed: isEditing ? onSelected : onPressed,
      title: EmojiText(
        proxy.name.isEmpty ? '-' : proxy.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(proxy.type, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (issues.isNotEmpty) CustomIssueButton(issues: issues),
          CommonCheckBox(
            value: isSelected,
            isCircle: true,
            onChanged: (_) => onSelected(),
          ),
        ],
      ),
    );
  }
}

Future<Map<int, List<Map<String, dynamic>>>> _decodeShareLinks(
  CoreController core,
  List<ShareLinkLine> lines,
) async {
  final appLocalizations = currentAppLocalizations;
  final results = await core.decodeShareLinks([
    for (final line in lines) line.link,
  ]);
  final decoded = <int, List<Map<String, dynamic>>>{};
  for (final (index, line) in lines.indexed) {
    if (results[index].isEmpty) {
      throw MessageException(
        appLocalizations.lineIssueTip(
          line.line,
          appLocalizations.shareLinksInvalid,
        ),
      );
    }
    decoded[line.line] = results[index];
  }
  final entries = [
    for (final MapEntry(key: line, value: proxies) in decoded.entries)
      for (final proxy in proxies) (line: line, proxy: proxy),
  ];
  final errors = await core.validateProxies([
    for (final entry in entries) entry.proxy,
  ]);
  for (final (index, error) in errors.indexed) {
    if (error.isNotEmpty) {
      throw MessageException(
        appLocalizations.lineIssueTip(entries[index].line, error),
      );
    }
  }
  return decoded;
}

/// Pops with what [read] made of the link, or with nothing when the link was
/// left as it came, which would only drop what the link cannot carry.
class _ShareLinkDialog extends StatefulWidget {
  final String initialLink;
  final Future<Map<String, dynamic>> Function(String link) read;

  const _ShareLinkDialog({required this.initialLink, required this.read});

  @override
  State<_ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends State<_ShareLinkDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLink);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final link = _controller.text.trim();
    if (link == widget.initialLink) {
      Navigator.of(context).pop();
      return;
    }
    if (_reading) {
      return;
    }
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final definition = await widget.read(link);
      if (mounted) {
        Navigator.of(context).pop(definition);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = compactError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.quickEdit,
      actions: [
        TextButton(
          onPressed: _reading ? null : _submit,
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'URI',
          alignLabelWithHint: true,
          hintText: 'vless://…',
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

Future<String> _deleteMessage(
  WidgetRef ref,
  Set<int> ids,
  String fallback,
) async {
  final names = {
    for (final proxy
        in ref.read(customProxiesProvider).value ?? const <CustomProxy>[])
      if (ids.contains(proxy.id)) proxy.name,
  };
  final users = await ref
      .read(profilesActionProvider.notifier)
      .proxyUsers(names);
  if (users.isEmpty) {
    return fallback;
  }
  return currentAppLocalizations.providerInUse(
    names.join(', '),
    users.map((profile) => profile.realLabel).join(', '),
  );
}

Future<bool> _handleSaveCustomProxy(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<String> onCoreRejected,
}) async {
  final proxy = ref.read(customProxyProvider);
  // A source still loading reads as empty below and would pass any name.
  Set<String> groupNames = const {};
  try {
    (_, groupNames) = await (
      ref.read(customProxiesProvider.future),
      ref.read(customGroupNamesProvider.future),
    ).wait;
  } catch (_) {}
  if (!context.mounted) {
    return false;
  }
  final issues = customProxyIssues(
    proxy,
    proxies: ref.read(customProxiesProvider).value ?? const [],
    groupNames: groupNames,
  );
  if (issues.isEmpty) {
    try {
      final errors = await ref.read(coreHandlerProvider).validateProxies([
        proxy.definition,
      ]);
      if (errors.first.isNotEmpty) {
        issues.add(CustomIssue.coreRejected(errors.first));
      }
    } catch (error) {
      issues.add(CustomIssue.coreRejected(compactError(error)));
    }
  }
  if (!context.mounted) {
    return false;
  }
  // The form stays editable while the core checks the proxy.
  if (!identical(ref.read(customProxyProvider), proxy)) {
    return _handleSaveCustomProxy(context, ref, onCoreRejected: onCoreRejected);
  }
  if (issues.isNotEmpty) {
    if (issues case [CoreRejectedIssue(:final message)]) {
      onCoreRejected(message);
    }
    await showSaveBlocked(context, issues.getMessage(context));
    return false;
  }
  final saved = proxy.id == -1 ? proxy.copyWith(id: snowflake.id) : proxy;
  ref.read(customProxiesProvider.notifier).put(saved);
  // The closing form would otherwise take its stored copy for another proxy
  // with its name.
  ref.read(customProxyProvider.notifier).value = saved;
  return true;
}

class _EditCustomProxyView extends ConsumerStatefulWidget {
  const _EditCustomProxyView();

  @override
  ConsumerState<_EditCustomProxyView> createState() =>
      _EditCustomProxyViewState();
}

class _EditCustomProxyViewState extends ConsumerState<_EditCustomProxyView> {
  static const _validateDelay = Duration(milliseconds: 400);

  late final bool _isNew;
  Timer? _validateTimer;
  int _validateRequest = 0;
  String? _coreError;
  bool _saving = false;
  bool _submitted = false;
  bool _obscurePassword = true;

  /// Bumped when the whole mapping is replaced, so the fields drop the text
  /// they were initialized with.
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _isNew = ref.read(customProxyProvider).id == -1;
    NestedFormSheet.bindSave(context, _handleSave);
    ref.listenManual(
      customProxyProvider.select((state) => state.definition),
      (_, _) => _scheduleValidate(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _validateTimer?.cancel();
    super.dispose();
  }

  void _scheduleValidate() {
    _validateTimer?.cancel();
    _validateTimer = Timer(_validateDelay, _validate);
  }

  Future<void> _handleQuickEdit() async {
    final appLocalizations = context.appLocalizations;
    final core = ref.read(coreHandlerProvider);
    var link = '';
    try {
      link = (await core.encodeShareLinks([
        ref.read(customProxyProvider).definition,
      ])).single;
    } catch (_) {}
    if (!mounted) {
      return;
    }
    final definition = await dialogs.showCommonDialog<Map<String, dynamic>>(
      child: _ShareLinkDialog(
        initialLink: link,
        read: (text) async {
          final definitions = (await core.decodeShareLinks([text])).single;
          if (definitions.isEmpty) {
            throw MessageException(appLocalizations.shareLinksInvalid);
          }
          if (definitions.length > 1) {
            throw MessageException(appLocalizations.singleShareLinkOnly);
          }
          return definitions.single;
        },
      ),
    );
    if (definition == null || !mounted) {
      return;
    }
    _fillFromLink(definition);
  }

  void _fillFromLink(Map<String, dynamic> definition) {
    final current = ref.read(customProxyProvider);
    final named = (definition['name'] ?? '') == '' && current.name.isNotEmpty
        ? {...definition, 'name': current.name}
        : importedCustomProxies(
            [definition],
            groupNames: ref.read(customGroupNamesProvider).value ?? const {},
            existing: [
              for (final proxy in ref.read(customProxiesProvider).value ?? [])
                if (proxy.id != current.id) proxy,
            ],
          ).single.definition;
    ref.read(customProxyProvider.notifier).value = current.copyWith(
      definition: named,
    );
    setState(() {
      _revision++;
    });
  }

  Future<void> _validate() async {
    final request = ++_validateRequest;
    final definition = ref.read(customProxyProvider).definition;
    String? error;
    try {
      final errors = await ref.read(coreHandlerProvider).validateProxies([
        definition,
      ]);
      error = errors.first.isEmpty ? null : errors.first;
    } catch (_) {
      error = null;
    }
    if (!mounted || request != _validateRequest || error == _coreError) {
      return;
    }
    setState(() {
      _coreError = error;
    });
  }

  void _update(String key, Object? value) {
    ref
        .read(customProxyProvider.notifier)
        .update((state) => state.withValue(key, value));
  }

  Widget _buildTextItem({
    required String title,
    required String key,
    required String? value,
    required int maxLength,
    String? hintText,
    bool digitsOnly = false,
    bool policyName = false,
    bool invalid = false,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final field = TextFormField(
      key: ValueKey('$key-$_revision'),
      initialValue: value,
      textAlign: TextAlign.end,
      obscureText: obscureText,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: digitsOnly
          ? TextInputLimits.digitsOnly(maxLength)
          : policyName
          ? TextInputLimits.policyName(maxLength)
          : TextInputLimits.limit(maxLength),
      onChanged: (value) {
        _update(key, digitsOnly ? int.tryParse(value) : value);
      },
      decoration: InputDecoration.collapsed(
        border: const NoInputBorder(),
        hintText: hintText ?? context.appLocalizations.optional,
      ),
    );
    return FormRow(
      title: title,
      invalid: invalid,
      trailing: suffix == null
          ? field
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: field),
                suffix,
              ],
            ),
    );
  }

  Widget _buildSecretItem({
    required String title,
    required String key,
    required String? value,
  }) {
    final appLocalizations = context.appLocalizations;
    return _buildTextItem(
      title: title,
      key: key,
      value: value,
      maxLength: TextInputLimits.password,
      obscureText: _obscurePassword,
      suffix: CommonMinIconButtonTheme(
        child: IconButton(
          tooltip: _obscurePassword
              ? appLocalizations.showPassword
              : appLocalizations.hidePassword,
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          icon: GlyphIcon(_obscurePassword ? AppGlyphs.eye : AppGlyphs.eyeOff),
        ),
      ),
    );
  }

  Widget _buildCredentialItem(CustomProxy proxy, ProxyCredential credential) {
    final appLocalizations = context.appLocalizations;
    final key = credential.name;
    final value = proxy.definition[key]?.toString();
    return switch (credential) {
      ProxyCredential.username => _buildTextItem(
        title: appLocalizations.username,
        key: key,
        value: value,
        maxLength: TextInputLimits.userName,
      ),
      ProxyCredential.password => _buildSecretItem(
        title: appLocalizations.password,
        key: key,
        value: value,
      ),
      ProxyCredential.uuid => _buildTextItem(
        title: 'UUID',
        key: key,
        value: value,
        maxLength: TextInputLimits.password,
      ),
    };
  }

  Future<void> _handleSelectType() async {
    final res = await Navigator.of(context).push(
      PagedSheetRoute(
        builder: (context) => SelectionSheet<String>(
          title: context.appLocalizations.proxyType,
          sections: const [SelectionSection(items: customProxyTypes)],
          labelBuilder: (item) => item,
          selectedOf: (ref) =>
              ref.watch(customProxyProvider.select((state) => state.type)),
          onSelected: (item) => Navigator.of(context).pop(item),
        ),
      ),
    );
    if (res == null) {
      return;
    }
    _update('type', res);
  }

  Widget _buildPickerItem({
    required String title,
    required String value,
    required VoidCallback onPressed,
  }) {
    return FormRow(
      title: title,
      onPressed: onPressed,
      trailing: Row(
        spacing: 4,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              style: context.listTitleStyle?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const GlyphIcon(AppGlyphs.chevronForward),
        ],
      ),
    );
  }

  Widget _buildTypeItem(String type) {
    return _buildPickerItem(
      title: context.appLocalizations.proxyType,
      value: type,
      onPressed: _handleSelectType,
    );
  }

  Widget _buildListItem(
    CustomProxy proxy, {
    required String title,
    required String key,
    required int itemMaxLength,
  }) {
    final appLocalizations = context.appLocalizations;
    final items = proxy.stringsOf(key);
    return _buildPickerItem(
      title: title,
      value: items.isEmpty
          ? appLocalizations.none
          : appLocalizations.itemsCount(items.length),
      onPressed: () => Navigator.of(context).push(
        PagedSheetRoute<void>(
          builder: (_) => _ProxyValuesView(
            title: title,
            field: key,
            itemMaxLength: itemMaxLength,
          ),
        ),
      ),
    );
  }

  Widget _buildEasyTierSection(CustomProxy proxy) {
    final appLocalizations = context.appLocalizations;
    final definition = proxy.definition;
    return generateSectionV3(
      title: appLocalizations.network,
      items: [
        _buildTextItem(
          title: appLocalizations.networkName,
          key: 'network-name',
          value: definition['network-name']?.toString(),
          maxLength: TextInputLimits.name,
          hintText: appLocalizations.networkName,
        ),
        _buildSecretItem(
          title: appLocalizations.networkSecret,
          key: 'network-secret',
          value: definition['network-secret']?.toString(),
        ),
        _buildListItem(
          proxy,
          title: appLocalizations.peers,
          key: 'peers',
          itemMaxLength: TextInputLimits.uri,
        ),
        _buildTextItem(
          title: appLocalizations.virtualIpv4,
          key: 'ipv4',
          value: definition['ipv4']?.toString(),
          maxLength: TextInputLimits.cidr,
          hintText: 'DHCP',
        ),
        _buildTextItem(
          title: appLocalizations.hostname,
          key: 'hostname',
          value: definition['hostname']?.toString(),
          maxLength: TextInputLimits.domain,
        ),
        _buildListItem(
          proxy,
          title: appLocalizations.exitNodes,
          key: 'exit-nodes',
          itemMaxLength: TextInputLimits.cidr,
        ),
      ],
    );
  }

  Widget _buildUdpItem(bool udp) {
    return FormRow(
      title: 'UDP',
      onPressed: () => _update('udp', !udp),
      trailing: Switch(value: udp, onChanged: (value) => _update('udp', value)),
    );
  }

  Future<void> _handleDelete() async {
    final appLocalizations = context.appLocalizations;
    final id = ref.read(customProxyProvider).id;
    final message = await _deleteMessage(ref, {
      id,
    }, appLocalizations.deleteTip(appLocalizations.proxies));
    if (!mounted) {
      return;
    }
    final res = await dialogs.showMessage(message: TextSpan(text: message));
    if (res == true && mounted) {
      ref.read(customProxiesProvider.notifier).delAll([id]);
      context.safeNestedPop();
    }
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    _saving = true;
    try {
      String? coreError;
      final saved = await _handleSaveCustomProxy(
        context,
        ref,
        onCoreRejected: (message) => coreError = message,
      );
      if (!mounted) return;
      if (saved) {
        context.safeNestedPop();
        return;
      }
      setState(() {
        _submitted = true;
        _coreError = coreError ?? _coreError;
      });
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final proxy = ref.watch(customProxyProvider);
    final showIncomplete = !_isNew || _submitted;
    final issues = [
      ...customProxyIssues(
        proxy,
        proxies: ref.watch(customProxiesProvider).value ?? const [],
        groupNames: ref.watch(customGroupNamesProvider).value ?? const {},
      ),
      if (_coreError != null) CustomIssue.coreRejected(_coreError!),
    ].where((issue) => showIncomplete || !issue.isIncomplete).toList();
    final nameInvalid = issues.any(
      (issue) =>
          issue is EmptyNameIssue ||
          issue is ReservedNameIssue ||
          issue is DuplicateNameIssue,
    );
    final easyTier = proxy.type == 'easytier';
    return CommonScaffold(
      iconActions: customFormActions(
        context,
        onQuickEdit: _handleQuickEdit,
        onSave: _handleSave,
      ),
      body: CustomScrollView(
        slivers: [
          SliverCustomIssuesBanner(issues: issues),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ).copyWith(bottom: 20),
            sliver: SliverList.list(
              children: [
                generateSectionV3(
                  title: appLocalizations.basicInfo,
                  items: [
                    _buildTextItem(
                      title: appLocalizations.name,
                      key: 'name',
                      value: proxy.name,
                      maxLength: TextInputLimits.proxyName,
                      hintText: appLocalizations.name,
                      policyName: true,
                      invalid: nameInvalid,
                    ),
                    _buildTypeItem(proxy.type),
                    if (!easyTier) ...[
                      _buildTextItem(
                        title: appLocalizations.server,
                        key: 'server',
                        value: proxy.server,
                        maxLength: TextInputLimits.domain,
                      ),
                      _buildTextItem(
                        title: appLocalizations.port,
                        key: 'port',
                        value: proxy.port?.toString(),
                        maxLength: TextInputLimits.port,
                        digitsOnly: true,
                      ),
                    ],
                    _buildUdpItem(proxy.definition['udp'] == true),
                  ],
                ),
                if (easyTier) _buildEasyTierSection(proxy),
                if (proxy.credentials.isNotEmpty)
                  generateSectionV3(
                    title: appLocalizations.authentication,
                    items: [
                      for (final credential in proxy.credentials)
                        _buildCredentialItem(proxy, credential),
                    ],
                  ),
                generateSectionV3(
                  title: appLocalizations.action,
                  items: [
                    if (!_isNew)
                      FormRow(
                        title: appLocalizations.delete,
                        titleStyle: TextStyle(color: context.colorScheme.error),
                        onPressed: _handleDelete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      title: _isNew
          ? appLocalizations.addCustomProxy
          : appLocalizations.editProxy,
    );
  }
}

/// Writes each change straight into the form, since a sheet page's back
/// button pops it without a result.
class _ProxyValuesView extends ConsumerWidget {
  final String title;
  final String field;
  final int itemMaxLength;

  const _ProxyValuesView({
    required this.title,
    required this.field,
    required this.itemMaxLength,
  });

  List<String> _valuesOf(WidgetRef ref) =>
      ref.read(customProxyProvider).stringsOf(field);

  void _save(WidgetRef ref, List<String> values) {
    ref
        .read(customProxyProvider.notifier)
        .update(
          (state) => state.withValue(field, values.isEmpty ? null : values),
        );
  }

  Future<void> _handleAddOrUpdate(
    BuildContext context,
    WidgetRef ref, [
    String? value,
  ]) async {
    final res = await showListEntryDialog(
      context,
      title: title,
      entries: _valuesOf(ref),
      entry: value,
      itemMaxLength: itemMaxLength,
    );
    if (res == null || res.isEmpty || !context.mounted) {
      return;
    }
    final values = _valuesOf(ref);
    _save(
      ref,
      value == null
          ? [...values, ...res]
          : [for (final item in values) item == value ? res.single : item],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListEditorPage<String, String>(
      title: title,
      selectionEnabled: true,
      idOf: (value) => value,
      itemsOf: (ref) => ref.watch(
        customProxyProvider.select((state) => state.stringsOf(field)),
      ),
      itemBuilder:
          (
            context,
            ref,
            value,
            index,
            isEditing,
            isSelected,
            onToggleSelected,
          ) => SelectedDecorationListItem(
            title: Text(value),
            isEditing: isEditing,
            isSelected: isSelected,
            onSelected: onToggleSelected,
            onPressed: () => _handleAddOrUpdate(context, ref, value),
          ),
      onReorder: (oldIndex, newIndex) =>
          _save(ref, _valuesOf(ref).copyAndReorder(oldIndex, newIndex)),
      onAdd: () => _handleAddOrUpdate(context, ref),
      onDelete: (values) => _save(ref, [
        for (final value in _valuesOf(ref))
          if (!values.contains(value)) value,
      ]),
      emptyLabel: context.appLocalizations.nullTip(title),
    );
  }
}
