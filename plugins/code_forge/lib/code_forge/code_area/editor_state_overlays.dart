part of '../code_area.dart';

extension _EditorStateOverlays on _CodeForgeState {
  void _updateScrollbarLineNumberIndicator() {
    final renderObject = _codeFieldKey.currentContext?.findRenderObject();
    if (renderObject is! _CodeFieldRenderer) return;

    final lineNumber = renderObject.getScrollbarLineNumberAtScrollOffset(
      _vscrollController.hasClients ? _vscrollController.offset : 0.0,
    );
    if (_scrollbarLineNumberIndicator.value != lineNumber) {
      _scrollbarLineNumberIndicator.value = lineNumber;
    }
  }

  void _handleContextMenuRequest(Offset offset) {
    final stack = _editorStackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || !stack.attached) return;
    final selection = _controller.selection;
    widget.onContextMenu(
      context,
      CodeForgeContextMenuRequest(
        globalPosition: stack.localToGlobal(offset),
        hasSelection: !selection.isCollapsed,
        isAllSelected:
            selection.start == 0 && selection.end == _controller.length,
        readOnly: _readOnly,
        copy: _controller.copy,
        cut: _controller.cut,
        paste: () => _controller.paste(),
        selectAll: _controller.selectAll,
      ),
    );
  }

  Widget _buildVerticalScrollbar(BuildContext context, Widget child) {
    return widget.scrollbarBuilder(
      context,
      CodeForgeScrollbarDetails(
        controller: _vscrollController,
        firstVisibleLine: _scrollbarLineNumberIndicator,
      ),
      child,
    );
  }

  Widget _buildSuggestionPopup(
    BuildContext context,
    List<CodeForgeSuggestion> sugg,
    int? selectedIndex, {
    required double left,
    required double width,
    required double below,
    required double above,
  }) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _SuggestionPopupLayout(
          left: left,
          width: width,
          below: below,
          above: above,
        ),
        child: widget.suggestionPopupBuilder(
          context,
          CodeForgeSuggestionDetails(
            suggestions: sugg,
            selectedIndex: selectedIndex,
            onAccept: _controller.acceptSuggestion,
          ),
        ),
      ),
    );
  }
}

/// Opens the popup below the caret line when it fits there or that side has
/// more room, and above it otherwise, measuring the popup rather than
/// estimating its height.
class _SuggestionPopupLayout extends SingleChildLayoutDelegate {
  final double left;
  final double width;
  final double below;
  final double above;

  const _SuggestionPopupLayout({
    required this.left,
    required this.width,
    required this.below,
    required this.above,
  });

  static const _maxHeight = 400.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = max(constraints.maxHeight - below, above);
    return BoxConstraints(
      maxWidth: width,
      maxHeight: room.clamp(0.0, _maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final spaceBelow = size.height - below;
    final opensBelow = childSize.height <= spaceBelow || spaceBelow >= above;
    return Offset(left, opensBelow ? below : above - childSize.height);
  }

  @override
  bool shouldRelayout(_SuggestionPopupLayout oldDelegate) {
    return left != oldDelegate.left ||
        width != oldDelegate.width ||
        below != oldDelegate.below ||
        above != oldDelegate.above;
  }
}
