import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Marks a subtree as visited first by [PageTraversalPolicy].
class PrimaryFocusOrder extends FocusOrder {
  const PrimaryFocusOrder();

  @override
  int doCompare(FocusOrder other) => 0;
}

/// Hosts the focus scope of a single page's content, so directional
/// traversal stays inside the page and escapes to the enclosing scope at the
/// edge.
class PageFocusScope extends StatefulWidget {
  final Widget child;

  const PageFocusScope({super.key, required this.child});

  @override
  State<PageFocusScope> createState() => _PageFocusScopeState();
}

class _PageFocusScopeState extends State<PageFocusScope> {
  final FocusScopeNode _node = FocusScopeNode()
    ..traversalEdgeBehavior = TraversalEdgeBehavior.parentScope;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope.withExternalFocusNode(
      focusScopeNode: _node,
      child: widget.child,
    );
  }
}

/// Page-level focus traversal: primary actions first, escaping to the
/// enclosing scope when the page cannot move focus.
///
/// Also escapes when traversal made no progress — a scope without focusable
/// descendants reports a successful move without changing focus, which would
/// trap Tab. Directional edges focus the [PrimaryFocusOrder]-marked action
/// (right/down) or continue into the enclosing scope (any direction).
class PageTraversalPolicy extends OrderedTraversalPolicy {
  PageTraversalPolicy();

  FocusNode? _findPrimaryAction(FocusScopeNode scope) {
    for (final node in scope.traversalDescendants) {
      final context = node.context;
      if (context == null) {
        continue;
      }
      final order = FocusTraversalOrder.maybeOf(context);
      if (order is PrimaryFocusOrder) {
        return node;
      }
    }
    return null;
  }

  bool _isInPrimaryAction(FocusNode node) {
    final context = node.context;
    return context != null &&
        FocusTraversalOrder.maybeOf(context) is PrimaryFocusOrder;
  }

  // Uses next/previous rather than directional navigation, which would run
  // through this policy again and could re-focus the primary action.
  bool _escapeToEnclosingScope(FocusNode currentNode, bool forward) {
    final FocusScopeNode? parent = currentNode.nearestScope?.enclosingScope;
    if (parent == null || parent == FocusManager.instance.rootScope) {
      return false;
    }
    if (forward) {
      parent.nextFocus();
    } else {
      parent.previousFocus();
    }
    return true;
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final bool isDownRight =
        direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    // The FAB is the last content node; from it, down/right leave the content.
    if (isDownRight && _isInPrimaryAction(currentNode)) {
      return _escapeToEnclosingScope(currentNode, true);
    }
    // Accept the move only when it really advanced (empty scopes report
    // success without moving focus).
    final FocusScopeNode? scope = currentNode.nearestScope;
    final FocusNode? before = scope?.focusedChild;
    final bool moved = super.inDirection(currentNode, direction);
    if (moved && (scope == null || !identical(before, scope.focusedChild))) {
      return true;
    }
    if (isDownRight) {
      final FocusNode? primaryAction = scope == null
          ? null
          : _findPrimaryAction(scope);
      if (primaryAction != null && primaryAction.canRequestFocus) {
        primaryAction.requestFocus();
        return true;
      }
      return _escapeToEnclosingScope(currentNode, true);
    }
    return _escapeToEnclosingScope(currentNode, false);
  }

  bool _moveOrEscape(FocusNode currentNode, bool forward) {
    final FocusScopeNode? scope = currentNode.nearestScope;
    final FocusNode? before = scope?.focusedChild;
    final bool moved = forward
        ? super.next(currentNode)
        : super.previous(currentNode);
    if (scope == null || !identical(before, scope.focusedChild)) {
      return moved;
    }
    return _escapeToEnclosingScope(currentNode, forward);
  }

  @override
  bool next(FocusNode currentNode) => _moveOrEscape(currentNode, true);

  @override
  bool previous(FocusNode currentNode) => _moveOrEscape(currentNode, false);
}

/// Bridges arrow-key focus into a nested control that directional traversal
/// cannot reach because its bounds overlap the surrounding focusable.
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
