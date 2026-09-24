part of '../code_area.dart';

extension _RendererCaret on _CodeFieldRenderer {
  void _ensureCaretVisible() {
    if (!vscrollController.hasClients || !hscrollController.hasClients) return;

    final caretInfo = _getCaretInfo();
    final caretX = caretInfo.offset.dx + _textLeft;
    final caretY = caretInfo.offset.dy + (innerPadding?.top ?? 0);
    final caretHeight = caretInfo.height;
    final vScrollOffset = vscrollController.offset;
    final hScrollOffset = hscrollController.offset;
    final viewportHeight =
        vscrollController.position.viewportDimension -
        (innerPadding?.bottom ?? 0);
    final viewportWidth =
        hscrollController.position.viewportDimension -
        (innerPadding?.right ?? 0);
    final relX = caretX.clamp(0.0, viewportWidth);
    final relY = (caretY - vScrollOffset).clamp(0.0, viewportHeight);

    offsetNotifier.value = Offset(relX, relY);

    if (caretY >= 0 && caretY <= vScrollOffset + (innerPadding?.top ?? 0)) {
      final targetOffset = caretY - (innerPadding?.top ?? 0);
      vscrollController.jumpTo(
        targetOffset.clamp(0, vscrollController.position.maxScrollExtent),
      );
    } else if (caretY + caretHeight > vScrollOffset + viewportHeight) {
      final targetOffset = caretY + caretHeight - viewportHeight;
      vscrollController.jumpTo(
        targetOffset.clamp(0, vscrollController.position.maxScrollExtent),
      );
    }

    final textStart = _gutterWidth + (innerPadding?.left ?? 0);
    if (caretX < textStart) {
      final targetOffset = hScrollOffset + caretX - textStart;
      hscrollController.jumpTo(
        targetOffset.clamp(0, hscrollController.position.maxScrollExtent),
      );
    } else if (caretX + 1.5 > viewportWidth) {
      final targetOffset = hScrollOffset + caretX + 1.5 - viewportWidth;
      hscrollController.jumpTo(
        targetOffset.clamp(0, hscrollController.position.maxScrollExtent),
      );
    }
  }

  void _scheduleCaretSyncAfterLayout() {
    if (_caretSyncAfterLayoutScheduled || _isFoldToggleInProgress) return;
    _caretSyncAfterLayoutScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _caretSyncAfterLayoutScheduled = false;
      if (!attached) return;
      if (!vscrollController.hasClients || !hscrollController.hasClients) {
        return;
      }
      _ensureCaretVisible();
    });
  }

  void _scrollToLine(int line) {
    if (line < 0 || line >= controller.lineCount) return;

    for (final fold in _foldRanges.values.where((f) => f != null)) {
      if (fold!.isFolded && line > fold.startIndex && line <= fold.endIndex) {
        _unfoldWithChildren(fold);
        _commitFoldChange();
        break;
      }
    }

    final targetY = _lineTop(line);
    final targetLineHeight = _lineExtent(line);
    final topPadding = innerPadding?.top ?? 0;
    final bottomPadding = innerPadding?.bottom ?? 0;
    final viewportHeight = vscrollController.position.viewportDimension;
    final visibleHeight = max(0.0, viewportHeight - topPadding - bottomPadding);
    final centerHeight = visibleHeight > 0 ? visibleHeight : viewportHeight;
    final maxScroll = vscrollController.position.maxScrollExtent;
    double scrollTarget = targetY + (targetLineHeight / 2) - (centerHeight / 2);

    scrollTarget = scrollTarget.clamp(0.0, maxScroll);

    vscrollController
        .animateTo(
          scrollTarget,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .then((_) {
          if (!attached) return;
          _highlightedLine = line;
          lineHighlightController.forward(from: 0.0);
        });
  }

  void _updateImeGeometry() {
    final conn = controller.connection;
    if (conn == null || !conn.attached) return;
    if (!vscrollController.hasClients || !hscrollController.hasClients) return;

    final caretInfo = _getCaretInfo();
    final vScroll = vscrollController.offset;
    final composing = controller.imeComposition != null;

    final caretY = caretInfo.offset.dy + (innerPadding?.top ?? 0);

    final caretInLine =
        caretInfo.offset.dx + (composing ? _imeComposingCaretDx : 0.0);
    final caretRect = Rect.fromLTWH(
      caretInLine + _textLeft,
      caretY - vScroll,
      2.0,
      caretInfo.height,
    );

    final composingRect = composing
        ? Rect.fromLTWH(
            caretInfo.offset.dx + _textLeft,
            caretY - vScroll,
            _imeComposingWidth > 0 ? _imeComposingWidth : 2.0,
            caretInfo.height,
          )
        : caretRect;

    final editableSize = size;

    if (caretRect == _lastImeCaretRect &&
        composingRect == _lastImeComposingRect &&
        editableSize == _lastImeEditableSize) {
      return;
    }
    _lastImeCaretRect = caretRect;
    _lastImeComposingRect = composingRect;
    _lastImeEditableSize = editableSize;

    conn.setEditableSizeAndTransform(editableSize, getTransformTo(null));
    conn.setCaretRect(caretRect);
    conn.setComposingRect(composingRect);
  }

  void _drawImeComposition(Canvas canvas, Offset offset, bool hasActiveFolds) {
    _imeComposingCaretDx = 0.0;
    _imeComposingWidth = 0.0;

    final comp = controller.imeComposition;
    if (comp == null || comp.displayText.isEmpty) return;

    final anchorLine = controller.getLineAtOffset(comp.anchor);
    if (hasActiveFolds && _isLineFolded(anchorLine)) return;

    final viewportHeight = vscrollController.position.viewportDimension;
    final screenYBase = _screenY(offset, _lineTop(anchorLine));
    if (screenYBase + _lineHeight < offset.dy ||
        screenYBase > offset.dy + viewportHeight) {
      return;
    }

    final lineStartOffset = controller.getLineStartOffset(anchorLine);
    final lineText = _lineText(anchorLine);
    final anchorCol = lineText.toUtf16Offset(comp.anchor - lineStartOffset);
    final linePara = _paragraphFor(anchorLine);

    double anchorX = 0;
    double rowTop = 0;
    if (anchorCol > 0) {
      final boxes = linePara.getBoxesForRange(
        0,
        anchorCol,
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (boxes.isNotEmpty) {
        final lastBox = boxes.last;
        anchorX = lastBox.right;
        rowTop = _rowTopForBox(lastBox);
      }
    }

    final screenX = _screenX(offset, anchorX);
    final screenY = screenYBase + rowTop;

    final baseColor =
        textStyle?.color ?? editorTheme['root']?.color ?? Colors.white;
    final bgColor = editorTheme['root']?.backgroundColor ?? Colors.black;
    final fontSize = textStyle?.fontSize ?? 14.0;
    final fontFamily = textStyle?.fontFamily;
    final overlayParagraphStyle = ui.ParagraphStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: textStyle?.height ?? 1.2,
      textDirection: TextDirection.ltr,
      textAlign: ui.TextAlign.start,
    );
    ui.Paragraph overlayParagraph(String text, ui.TextStyle style) {
      final builder = ui.ParagraphBuilder(overlayParagraphStyle)
        ..pushStyle(style)
        ..addText(text);
      return builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
    }

    final composingPara = overlayParagraph(
      comp.displayText,
      ui.TextStyle(
        color: baseColor,
        fontSize: fontSize,
        fontFamily: fontFamily,
        decoration: TextDecoration.underline,
        decorationColor: baseColor.withAlpha(150),
      ),
    );
    final composingWidth = composingPara.longestLine;

    final remainderWidth = (linePara.longestLine - anchorX).clamp(
      0.0,
      double.infinity,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        screenX,
        screenY,
        composingWidth + remainderWidth + 2,
        _lineHeight,
      ),
      Paint()..color = bgColor,
    );

    canvas.drawParagraph(composingPara, Offset(screenX, screenY));

    if (anchorCol < lineText.length) {
      final remainingPara = overlayParagraph(
        lineText.substring(anchorCol),
        ui.TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontWeight: textStyle?.fontWeight,
        ),
      );
      canvas.drawParagraph(
        remainingPara,
        Offset(screenX + composingWidth, screenY),
      );
    }

    double caretDx = 0;
    if (comp.displayCaret > 0) {
      final caretBoxes = composingPara.getBoxesForRange(
        0,
        comp.displayCaret.clamp(0, comp.displayText.length),
      );
      if (caretBoxes.isNotEmpty) caretDx = caretBoxes.last.right;
    }

    _imeComposingCaretDx = caretDx;
    _imeComposingWidth = composingWidth;

    if (focusNode.hasFocus && caretBlinkController.value > 0.5) {
      canvas.drawRect(
        Rect.fromLTWH(screenX + caretDx, screenY, 1.5, _lineHeight),
        _caretPainter,
      );
    }
  }

  void _selectWordAtOffset(int offset) {
    if (isMobile) {
      _selectionActive = selectionActiveNotifier.value = true;
    }

    final text = controller.text;
    final utf16Offset = text.toUtf16Offset(offset);
    int start = utf16Offset, end = utf16Offset;

    while (start > 0 && isWordChar(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length && isWordChar(text.codeUnitAt(end))) {
      end++;
    }

    controller.selection = TextSelection(
      baseOffset: text.toScalarOffset(start),
      extentOffset: text.toScalarOffset(end),
    );
    markNeedsPaint();
  }

  void _paintMobileHandles(Canvas canvas, Offset offset) {
    final selection = controller.selection;
    final handleColor = selectionStyle.cursorBubbleColor;
    final handleRadius = _handleRadius;

    final handlePaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.fill;

    _normalHandle = null;
    if (selection.isCollapsed) {
      if (!_readOnly && (_showBubble || _selectionActive)) {
        final caretInfo = _getCaretInfo();
        final handleSize = caretInfo.height;

        final handleX = _screenX(offset, caretInfo.offset.dx);
        final handleY = _screenY(offset, caretInfo.offset.dy + _lineHeight);

        canvas.save();
        canvas.translate(handleX, handleY);
        canvas.rotate(pi / 4);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromCenter(
              center: Offset((handleSize / 1.5), (handleSize / 1.5)),
              width: handleSize * 1.3,
              height: handleSize * 1.3,
            ),
            topRight: const Radius.circular(25),
            bottomLeft: const Radius.circular(25),
            bottomRight: const Radius.circular(25),
          ),
          handlePaint,
        );
        canvas.restore();

        _normalHandle = Rect.fromCenter(
          center: Offset(handleX, handleY + handleRadius),
          width: handleRadius * 2,
          height: handleRadius * 2,
        );

        if (_draggingCHandle) {
          _selectionActive = selectionActiveNotifier.value = true;
          final caretLineIndex = controller.getLineAtOffset(
            controller.selection.baseOffset,
          );
          final lineText = _lineText(caretLineIndex);
          final lineStartOffset = controller.getLineStartOffset(caretLineIndex);
          final caretInLine = controller.selection.baseOffset - lineStartOffset;

          final previewText = lineText.scalarSubstring(
            max(0, caretInLine - 10),
            caretInLine + 10,
          );

          ui.Paragraph zoomParagraph;
          if (_cachedMagnifiedParagraph != null &&
              _cachedMagnifiedLine == caretLineIndex &&
              _cachedMagnifiedOffset == caretInLine) {
            zoomParagraph = _cachedMagnifiedParagraph!;
          } else {
            final zoomFontSize = (textStyle?.fontSize ?? 14) * 1.5;
            final fontFamily = textStyle?.fontFamily;
            zoomParagraph = _syntaxHighlighter.buildHighlightedParagraph(
              caretLineIndex,
              previewText,
              _paragraphStyle,
              zoomFontSize,
              fontFamily,
            );
            _cachedMagnifiedParagraph = zoomParagraph;
            _cachedMagnifiedLine = caretLineIndex;
            _cachedMagnifiedOffset = caretInLine;
          }

          final zoomBoxWidth = min(
            zoomParagraph.longestLine + 16,
            size.width * 0.6,
          );
          final zoomBoxHeight = zoomParagraph.height + 12;
          final double zoomBoxX = (handleX - zoomBoxWidth / 2).clamp(
            0.0,
            max(0.0, size.width - zoomBoxWidth),
          );
          final zoomBoxY = handleY - zoomBoxHeight - 18;

          _paintMagnifier(
            canvas,
            Rect.fromLTWH(zoomBoxX, zoomBoxY, zoomBoxWidth, zoomBoxHeight),
            () => canvas.drawParagraph(
              zoomParagraph,
              Offset(zoomBoxX + 8, zoomBoxY + 6),
            ),
          );
        }
      }
    } else {
      if (_startHandleRect case final startRect?) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            startRect,
            topLeft: const Radius.circular(25),
            bottomLeft: const Radius.circular(25),
            bottomRight: const Radius.circular(25),
          ),
          handlePaint,
        );
      }

      if (_endHandleRect case final endRect?) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            endRect,
            topRight: const Radius.circular(25),
            bottomLeft: const Radius.circular(25),
            bottomRight: const Radius.circular(25),
          ),
          handlePaint,
        );
      }

      if (_draggingStartHandle ||
          _draggingEndHandle ||
          (_selectionActive && _isDragging)) {
        final selection = controller.selection;
        final dragOffset = _draggingStartHandle
            ? selection.start
            : selection.end;
        final dragLine = controller.getLineAtOffset(dragOffset);
        final startLine = max(0, dragLine - 1);
        final endLine = min(controller.lineCount - 1, dragLine + 1);

        List<ui.Paragraph> zoomParagraphs;
        if (_cachedSelectionMagnifierParagraphs != null &&
            _cachedSelectionMagnifierStartLine == startLine &&
            _cachedSelectionMagnifierEndLine == endLine) {
          zoomParagraphs = _cachedSelectionMagnifierParagraphs!;
        } else {
          zoomParagraphs = [];
          final zoomFontSize = (textStyle?.fontSize ?? 14) * 1.4;
          final fontFamily = textStyle?.fontFamily;

          for (int line = startLine; line <= endLine; line++) {
            final lineText = controller.getLineText(line);
            final lineStartOffset = controller.getLineStartOffset(line);

            String displayText;
            if (line == dragLine) {
              final colInLine = dragOffset - lineStartOffset;
              displayText = lineText.scalarSubstring(
                max(0, colInLine - 15),
                colInLine + 15,
              );
            } else {
              displayText = lineText.scalarSubstring(0, 30);
            }

            if (displayText.isEmpty) displayText = ' ';

            final para = _syntaxHighlighter.buildHighlightedParagraph(
              line,
              displayText,
              _paragraphStyle,
              zoomFontSize,
              fontFamily,
            );
            zoomParagraphs.add(para);
          }
          _cachedSelectionMagnifierParagraphs = zoomParagraphs;
          _cachedSelectionMagnifierStartLine = startLine;
          _cachedSelectionMagnifierEndLine = endLine;
        }

        double maxWidth = 0;
        double totalHeight = 0;
        for (final para in zoomParagraphs) {
          maxWidth = max(maxWidth, para.longestLine);
          totalHeight += para.height;
        }

        final zoomBoxWidth = min(maxWidth + 24, size.width * 0.7);
        final zoomBoxHeight = totalHeight + 18;
        double handleCenterX;
        double handleTopY;
        Rect? activeHandleRect;

        if (_draggingStartHandle && _startHandleRect != null) {
          handleCenterX = _startHandleRect!.center.dx;
          handleTopY = _startHandleRect!.top;
          activeHandleRect = _startHandleRect;
        } else if (_draggingEndHandle && _endHandleRect != null) {
          handleCenterX = _endHandleRect!.center.dx;
          handleTopY = _endHandleRect!.top;
          activeHandleRect = _endHandleRect;
        } else {
          handleCenterX = _currentPosition.dx;
          handleTopY = _currentPosition.dy;
          activeHandleRect = null;
        }

        const fingerOffsetY = 60.0;
        final fingerOffsetX = _draggingStartHandle
            ? 30.0
            : (_draggingEndHandle ? -30.0 : 0.0);
        final double zoomBoxX =
            (handleCenterX + fingerOffsetX - zoomBoxWidth / 2).clamp(
              4.0,
              max(4.0, size.width - zoomBoxWidth - 4),
            );
        var zoomBoxY = handleTopY - zoomBoxHeight - fingerOffsetY;
        const viewportTop = 0.0;
        final viewportBottom = size.height;

        if (zoomBoxY < viewportTop + 4) {
          final handleBottom = activeHandleRect?.bottom ?? (handleTopY + 40);
          zoomBoxY = handleBottom + fingerOffsetY;

          if (zoomBoxY + zoomBoxHeight > viewportBottom - 4) {
            zoomBoxY = viewportBottom - zoomBoxHeight - 4;
          }
        }

        zoomBoxY = zoomBoxY.clamp(
          viewportTop + 4,
          max(viewportTop + 4, viewportBottom - zoomBoxHeight - 4),
        );

        _paintMagnifier(
          canvas,
          Rect.fromLTWH(zoomBoxX, zoomBoxY, zoomBoxWidth, zoomBoxHeight),
          () {
            double yOffset = zoomBoxY + 9;
            for (int i = 0; i < zoomParagraphs.length; i++) {
              final para = zoomParagraphs[i];
              if (startLine + i == dragLine) {
                canvas.drawRect(
                  Rect.fromLTWH(
                    zoomBoxX,
                    yOffset - 2,
                    zoomBoxWidth,
                    para.height + 4,
                  ),
                  Paint()
                    ..color = selectionStyle.selectionColor.withValues(
                      alpha: 0.3,
                    )
                    ..style = PaintingStyle.fill,
                );
              }
              canvas.drawParagraph(para, Offset(zoomBoxX + 12, yOffset));
              yOffset += para.height;
            }
          },
        );
      }
    }
  }

  void _paintMagnifier(Canvas canvas, Rect box, VoidCallback paintContent) {
    final frame = RRect.fromRectAndRadius(box, const Radius.circular(12));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = editorTheme['root']?.backgroundColor ?? Colors.black
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = editorTheme['root']?.color ?? Colors.grey
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );
    canvas.save();
    canvas.clipRect(box);
    paintContent();
    canvas.restore();
  }
}
