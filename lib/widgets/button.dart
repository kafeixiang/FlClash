import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

import 'builder.dart';
import 'card.dart';
import 'focus.dart';

/// Renders a visible ring around a floating action button while [focusNode]
/// holds focus (the Material FAB focus signal is too subtle).
class FabFocusRing extends StatefulWidget {
  final FocusNode focusNode;
  final OutlinedBorder ringShape;
  final Widget child;

  const FabFocusRing({
    super.key,
    required this.focusNode,
    required this.ringShape,
    required this.child,
  });

  @override
  State<FabFocusRing> createState() => _FabFocusRingState();
}

class _FabFocusRingState extends State<FabFocusRing> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant FabFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(focused ? 3 : 0),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: widget.ringShape.copyWith(
            side: focused
                ? BorderSide(color: color, width: 2.5)
                : BorderSide.none,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class CommonFloatingActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Icon icon;
  final String label;

  const CommonFloatingActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  State<CommonFloatingActionButton> createState() =>
      _CommonFloatingActionButtonState();
}

class _CommonFloatingActionButtonState
    extends State<CommonFloatingActionButton> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const PrimaryFocusOrder(),
      child: FabFocusRing(
        focusNode: _focusNode,
        ringShape: const StadiumBorder(),
        child: Theme(
          data: Theme.of(context).copyWith(
            floatingActionButtonTheme: Theme.of(context)
                .floatingActionButtonTheme
                .copyWith(
                  extendedIconLabelSpacing: 0,
                  extendedPadding: const EdgeInsets.all(16),
                ),
          ),
          child: FloatingActionButtonExtendedBuilder(
            builder: (isExtended) {
              return FloatingActionButton.extended(
                heroTag: null,
                focusNode: _focusNode,
                icon: widget.icon,
                onPressed: widget.onPressed,
                isExtended: true,
                label: AnimatedSize(
                  alignment: Alignment.centerLeft,
                  duration: midDuration,
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: midDuration,
                    opacity: isExtended ? 1.0 : 0.4,
                    curve: Curves.linear,
                    child: isExtended
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(widget.label, softWrap: false),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MoreActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? trailing;

  const MoreActionButton({
    super.key,
    this.onPressed,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        radius: 18,
        onPressed: onPressed,
        child: ListTile(
          minTileHeight: 0,
          minVerticalPadding: 0,
          titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          title: Text(label, style: context.textTheme.bodyLarge),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 18),
        ),
      ),
    );
  }
}
