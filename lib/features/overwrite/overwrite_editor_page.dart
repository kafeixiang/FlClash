import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OverwriteItemBuilder<T> =
    Widget Function(
      BuildContext context,
      WidgetRef ref,
      T item,
      int index,
      bool isEditing,
      bool isSelected,
      VoidCallback onToggleSelected,
    );

class OverwriteEditorPage<T> extends ConsumerStatefulWidget {
  final String title;
  final List<T> Function(WidgetRef ref) itemsOf;
  final OverwriteItemBuilder<T> itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;
  final String emptyLabel;
  final double? itemExtent;
  final bool selectionEnabled;
  final bool dragFromRow;
  final dynamic Function(T item)? idOf;
  final Future<bool> Function(Set<dynamic> selected)? onDelete;

  const OverwriteEditorPage({
    super.key,
    required this.title,
    required this.itemsOf,
    required this.itemBuilder,
    required this.onReorder,
    required this.onAdd,
    required this.emptyLabel,
    this.itemExtent,
    this.selectionEnabled = false,
    this.dragFromRow = false,
    this.idOf,
    this.onDelete,
  });

  @override
  ConsumerState<OverwriteEditorPage<T>> createState() =>
      _OverwriteEditorPageState<T>();
}

class _OverwriteEditorPageState<T> extends ConsumerState<OverwriteEditorPage<T>>
    with UniqueKeyStateMixin {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Set<dynamic> get _selected => ref.watch(itemsProvider(key));

  bool get _isEditing => widget.selectionEnabled && _selected.isNotEmpty;

  dynamic _idOf(T item) {
    return widget.selectionEnabled ? widget.idOf!(item) : null;
  }

  bool _isSelected(T item) {
    return widget.selectionEnabled && _selected.contains(_idOf(item));
  }

  void _handleToggleSelected(T item) {
    if (!widget.selectionEnabled) {
      return;
    }
    final id = _idOf(item);
    ref.read(itemsProvider(key).notifier).update((selected) {
      final newSelected = Set<dynamic>.from(selected)..addOrRemove(id);
      return newSelected;
    });
  }

  Future<void> _handleSelectAll() async {
    final ids = widget.itemsOf(ref).map(_idOf).toSet();
    ref.read(itemsProvider(key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleDelete() async {
    final selected = _selected;
    final deleted = await widget.onDelete?.call(selected) ?? true;
    if (deleted) {
      ref.read(itemsProvider(key).notifier).value = {};
    }
  }

  Widget _buildItem(BuildContext context, T item, int index, int total) {
    final isEditing = _isEditing;
    final child = ItemPositionProvider(
      position: ItemPosition.get(index, total),
      child: widget.itemBuilder(
        context,
        ref,
        item,
        index,
        isEditing,
        widget.selectionEnabled && _isSelected(item),
        () => _handleToggleSelected(item),
      ),
    );
    if (widget.dragFromRow) {
      return ReorderableDelayedDragStartListener(
        key: ValueKey(item),
        index: index,
        child: child,
      );
    }
    return KeyedSubtree(key: ValueKey(item), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = widget.itemsOf(ref);
    final selected = _selected;
    return CommonScaffold(
      title: widget.title,
      actions: [
        if (widget.selectionEnabled &&
            widget.onDelete != null &&
            selected.isNotEmpty) ...[
          CommonMinIconButtonTheme(
            child: IconButton.filledTonal(
              onPressed: _handleDelete,
              icon: const Icon(Icons.delete),
            ),
          ),
          const SizedBox(width: 2),
        ],
        CommonMinFilledButtonTheme(
          child: widget.selectionEnabled && selected.isNotEmpty
              ? FilledButton(
                  onPressed: _handleSelectAll,
                  child: Text(appLocalizations.selectAll),
                )
              : FilledButton.tonal(
                  onPressed: widget.onAdd,
                  child: Text(appLocalizations.add),
                ),
        ),
        const SizedBox(width: 8),
      ],
      body: items.isEmpty
          ? NullStatus(label: widget.emptyLabel)
          : CommonScrollBar(
              controller: _scrollController,
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ).copyWith(bottom: 24),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return _buildItem(context, item, index, items.length);
                },
                itemExtent: widget.itemExtent,
                itemCount: items.length,
                proxyDecorator: (child, index, animation) {
                  final item = items[index];
                  return commonProxyDecorator(
                    _buildItem(context, item, index, items.length),
                    index,
                    animation,
                  );
                },
                onReorderItem: widget.onReorder,
              ),
            ),
    );
  }
}
