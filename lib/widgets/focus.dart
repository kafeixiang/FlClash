import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reading-order traversal that escapes a nested focus scope when it cannot
/// move forward or backward.
///
/// Desktop pages are wrapped in their own `Navigator`, whose focus scope traps
/// Tab traversal inside the page. When a scope cannot move focus anymore, the
/// traversal is promoted to the enclosing scope so the sidebar/bottom
/// navigation stays reachable by keyboard.
class EscapingReadingOrderTraversalPolicy extends ReadingOrderTraversalPolicy {
  EscapingReadingOrderTraversalPolicy();

  @override
  bool next(FocusNode currentNode) {
    final FocusNode? before = FocusManager.instance.primaryFocus;
    final bool moved = super.next(currentNode);
    final FocusNode? after = FocusManager.instance.primaryFocus;
    if (identical(before, after)) {
      final FocusScopeNode? parent = currentNode.enclosingScope;
      if (parent != null && parent != FocusManager.instance.rootScope) {
        parent.nextFocus();
      }
    }
    return moved;
  }

  @override
  bool previous(FocusNode currentNode) {
    final FocusNode? before = FocusManager.instance.primaryFocus;
    final bool moved = super.previous(currentNode);
    final FocusNode? after = FocusManager.instance.primaryFocus;
    if (identical(before, after)) {
      final FocusScopeNode? parent = currentNode.enclosingScope;
      if (parent != null && parent != FocusManager.instance.rootScope) {
        parent.previousFocus();
      }
    }
    return moved;
  }
}

/// Bridges arrow-key focus from a surrounding focusable into a nested control.
///
/// Directional traversal cannot move into a control whose bounds overlap the
/// currently focused container (for example an icon button inside a card
/// button). Pressing one of [directions] while a descendant of this widget is
/// focused moves focus into the control built by [builder].
class FocusEntryOnArrow extends StatefulWidget {
  const FocusEntryOnArrow({
    super.key,
    required this.directions,
    required this.builder,
  });

  final Set<LogicalKeyboardKey> directions;
  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  @override
  State<FocusEntryOnArrow> createState() => _FocusEntryOnArrowState();
}

class _FocusEntryOnArrowState extends State<FocusEntryOnArrow> {
  final FocusNode _targetFocusNode = FocusNode();

  @override
  void dispose() {
    _targetFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            widget.directions.contains(event.logicalKey) &&
            !_targetFocusNode.hasFocus) {
          _targetFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.builder(context, _targetFocusNode),
    );
  }
}
