import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverwriteSelectionSection<T> {
  final String? label;
  final List<T> items;
  final String Function(BuildContext context, T item)? subtitleBuilder;

  const OverwriteSelectionSection({
    this.label,
    required this.items,
    this.subtitleBuilder,
  });
}

class OverwriteSelectionSheet<T> extends ConsumerWidget {
  final String title;
  final List<OverwriteSelectionSection<T>> sections;
  final String Function(T item) labelBuilder;
  final bool Function(WidgetRef ref, T item) isSelectedOf;
  final ValueChanged<T> onSelected;
  final double? bottomHeightFactor;
  final String? emptyLabel;

  const OverwriteSelectionSheet({
    super.key,
    required this.title,
    required this.sections,
    required this.labelBuilder,
    required this.isSelectedOf,
    required this.onSelected,
    this.bottomHeightFactor = 0.70,
    this.emptyLabel,
  });

  Widget _buildItem(
    BuildContext context,
    WidgetRef ref,
    OverwriteSelectionSection<T> section,
    T item,
    int index,
  ) {
    final position = ItemPosition.get(index, section.items.length);
    final isSelected = isSelectedOf(ref, item);
    return ItemPositionProvider(
      position: position,
      child: DecorationListItem(
        onPressed: () => onSelected(item),
        subtitle: section.subtitleBuilder != null
            ? Text(section.subtitleBuilder!(context, item))
            : null,
        title: TooltipText(
          text: Text(
            labelBuilder(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        isSelected: isSelected,
        trailing: isSelected ? const Icon(Icons.check) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final height = isBottomSheet
        ? ref.read(viewSizeProvider).height * (bottomHeightFactor ?? 1)
        : double.maxFinite;
    final isEmpty = sections.every((section) => section.items.isEmpty);
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      body: SizedBox(
        height: height,
        child: isEmpty && emptyLabel != null
            ? NullStatus(label: emptyLabel!)
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(bottom: 20, top: context.sheetTopPadding),
                children: [
                  for (final section in sections) ...[
                    if (section.label != null) ...[
                      InfoHeader(info: Info(label: section.label!)),
                      const SizedBox(height: 4),
                    ],
                    for (var index = 0; index < section.items.length; index++)
                      _buildItem(
                        context,
                        ref,
                        section,
                        section.items[index],
                        index,
                      ),
                  ],
                ],
              ),
      ),
      title: title,
    );
  }
}
