import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/dashboard_sections.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import 'ava_panel.dart';

/// A responsive grid whose local gesture preview never replaces card readers.
class DashboardCardLayout extends StatefulWidget {
  const DashboardCardLayout({
    super.key,
    required this.cards,
    required this.titles,
    required this.layout,
    required this.editing,
    required this.onChanged,
    required this.dragLabel,
    required this.resizeLabel,
  });

  final Map<String, Widget> cards;
  final Map<String, String> titles;
  final DashboardLayout layout;
  final bool editing;

  /// The caller reports persistence errors; failed previews revert to [layout].
  final Future<void> Function(int columns, Map<String, DashboardGridRect> rects)
  onChanged;
  final String dragLabel, resizeLabel;

  @override
  State<DashboardCardLayout> createState() => _DashboardCardLayoutState();
}

class _DashboardCardLayoutState extends State<DashboardCardLayout> {
  final _canvasKey = GlobalKey();
  EdgeDraggingAutoScroller? _scroller;
  Map<String, DashboardGridRect> _resolved = {}, _initial = {};
  Map<String, DashboardGridRect>? _preview;
  String? _active;
  Offset? _origin, _pointer;
  bool _resizing = false, _cancelled = false, _saving = false;
  int _columns = 1, _previewColumns = 1;
  double _unit = 0;

  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (_scroller?.scrollable != scrollable) {
      _scroller?.stopAutoScroll();
      _scroller = scrollable == null
          ? null
          : EdgeDraggingAutoScroller(
              scrollable,
              velocityScalar: 12,
              onScrollViewScrolled: _updatePreview,
            );
    }
  }

  @override
  void didUpdateWidget(DashboardCardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing ||
        (_active != null && !widget.cards.containsKey(_active)) ||
        !setEquals(widget.cards.keys.toSet(), oldWidget.cards.keys.toSet()) ||
        !identical(widget.layout, oldWidget.layout)) {
      _cancelGesture();
    }
  }

  @override
  void dispose() {
    _scroller?.stopAutoScroll();
    super.dispose();
  }

  void _cancelGesture() {
    _scroller?.stopAutoScroll();
    _active = null;
    _pointer = _origin = null;
    _initial = {};
    _preview = null;
  }

  Offset _local(Offset global) =>
      (_canvasKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  void _start(String id, bool resize, DragStartDetails details) {
    if (!widget.editing || _saving || _active != null) return;
    setState(() {
      _active = id;
      _resizing = resize;
      _cancelled = false;
      _origin = _local(details.globalPosition);
      _pointer = details.globalPosition;
      _initial = Map.of(_resolved);
      _preview = _initial;
      _previewColumns = _columns;
    });
  }

  DashboardGridRect _adjust(
    DashboardGridRect rect,
    int dx,
    int dy,
    bool resize,
  ) {
    if (resize) {
      return rect.copyWith(
        columnSpan: (rect.columnSpan + dx).clamp(1, _columns - rect.column),
        rowSpan: (rect.rowSpan + dy).clamp(
          dashboardGridMinRowSpan,
          dashboardGridMaxRowSpan,
        ),
      );
    }
    return rect.copyWith(
      column: (rect.column + dx).clamp(0, _columns - rect.columnSpan),
      row: (rect.row + dy).clamp(0, dashboardGridMaxRows - rect.rowSpan),
    );
  }

  void _updatePreview() {
    final id = _active, pointer = _pointer, origin = _origin;
    if (!mounted || id == null || pointer == null || origin == null) return;
    final delta = _local(pointer) - origin;
    final next = relocateDashboardGrid(
      current: _initial,
      section: id,
      columns: _columns,
      target: _adjust(
        _initial[id]!,
        (delta.dx / _unit).round(),
        (delta.dy / dashboardGridRowHeight).round(),
        _resizing,
      ),
    );
    if (!mapEquals(_preview, next)) setState(() => _preview = next);
    _scroller?.startAutoScrollIfNecessary(
      Rect.fromCenter(center: pointer, width: 1, height: 48),
    );
  }

  void _end() {
    final next = _preview;
    final changed =
        _active != null &&
        !_cancelled &&
        widget.editing &&
        next != null &&
        !mapEquals(next, _initial);
    final columns = _columns;
    setState(() {
      _scroller?.stopAutoScroll();
      _active = null;
      _pointer = _origin = null;
      _initial = {};
      if (!changed) _preview = null;
    });
    if (changed) unawaited(_save(columns, next));
  }

  Future<void> _save(int columns, Map<String, DashboardGridRect> next) async {
    setState(() => _saving = true);
    try {
      await widget.onChanged(columns, next);
    } catch (_) {
      // Persistence feedback belongs to the caller; restore its saved layout.
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _preview = null;
        });
      }
    }
  }

  void _step(String id, bool resize, int dx, int dy) {
    if (!widget.editing || _saving || _active != null) return;
    final next = relocateDashboardGrid(
      current: _resolved,
      section: id,
      columns: _columns,
      target: _adjust(_resolved[id]!, dx, dy, resize),
    );
    if (mapEquals(next, _resolved)) return;
    setState(() {
      _preview = next;
      _previewColumns = _columns;
    });
    unawaited(_save(_columns, next));
  }

  Widget _handle(String id, bool resize) {
    final enabled =
        !_saving && (_active == null || (_active == id && _resizing == resize));
    return Listener(
      onPointerCancel: (_) {
        if (_active == id && _resizing == resize) _cancelled = true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: enabled ? (details) => _start(id, resize, details) : null,
        onPanUpdate: enabled
            ? (details) {
                if (_active != id || _resizing != resize) return;
                _pointer = details.globalPosition;
                _updatePreview();
              }
            : null,
        onPanEnd: enabled
            ? (_) {
                if (_active == id && _resizing == resize) _end();
              }
            : null,
        onPanCancel: enabled
            ? () {
                if (_active == id && _resizing == resize) {
                  setState(_cancelGesture);
                }
              }
            : null,
        child: _GridHandle(
          key: ValueKey('dashboard-${resize ? 'resize' : 'drag'}-$id'),
          label:
              '${resize ? widget.resizeLabel : widget.dragLabel}: ${widget.titles[id] ?? id}',
          resize: resize,
          enabled: enabled,
          onStep: (dx, dy) => _step(id, resize, dx, dy),
          onCancel: () => setState(_cancelGesture),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final columns = _mobile
          ? 1
          : ((width + dashboardGridGap) / (340 + dashboardGridGap))
                .floor()
                .clamp(1, 3);
      if (_columns != columns && _active != null) _cancelGesture();
      _columns = columns;
      _unit = (width + dashboardGridGap) / columns;
      _resolved = resolveDashboardGrid(
        order: widget.layout.order,
        spans: widget.layout.spans,
        rects: widget.layout.gridForColumns(columns),
        visible: widget.cards.keys,
        columns: columns,
      );
      final rects = _previewColumns == columns
          ? _preview ?? _resolved
          : _resolved;
      var rows = 0;
      for (final rect in rects.values) {
        if (rect.row + rect.rowSpan > rows) rows = rect.row + rect.rowSpan;
      }
      final tokens = Theme.of(context).extension<AvaTokens>()!;
      return SizedBox(
        key: _canvasKey,
        width: width,
        height: rows == 0
            ? 0
            : rows * dashboardGridRowHeight -
                  dashboardGridGap +
                  (widget.editing ? dashboardGridRowHeight * 2 : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.editing)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GridPainter(_unit, tokens.borderColor),
                  ),
                ),
              ),
            for (final id in widget.cards.keys)
              if (rects[id] case final rect?)
                Positioned(
                  key: ValueKey('dashboard-layout-$id'),
                  left: rect.column * _unit,
                  top: rect.row * dashboardGridRowHeight,
                  width: rect.columnSpan * _unit - dashboardGridGap,
                  height:
                      rect.rowSpan * dashboardGridRowHeight - dashboardGridGap,
                  child: _GridCard(
                    selected: _active == id,
                    moveHandle: widget.editing ? _handle(id, false) : null,
                    resizeHandle: widget.editing ? _handle(id, true) : null,
                    child: widget.cards[id]!,
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class _GridCard extends StatefulWidget {
  const _GridCard({
    required this.child,
    required this.selected,
    this.moveHandle,
    this.resizeHandle,
  });
  final Widget child;
  final bool selected;
  final Widget? moveHandle, resizeHandle;
  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _forwardOverscroll(OverscrollNotification notification) {
    if (notification.depth != 0 || notification.dragDetails == null) {
      return false;
    }
    final outer = Scrollable.maybeOf(context)?.position;
    if (outer != null && outer.hasContentDimensions) {
      final next = (outer.pixels + notification.overscroll).clamp(
        outer.minScrollExtent,
        outer.maxScrollExtent,
      );
      if (next != outer.pixels) outer.jumpTo(next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AvaTokens>()!;
    final panel = widget.child is AvaPanel ? widget.child as AvaPanel : null;
    final emphasized = panel?.emphasized ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: panel?.color ?? tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(
          color: widget.selected || emphasized
              ? tokens.accent
              : tokens.borderColor,
          width: widget.selected ? 2 : tokens.borderWidth,
        ),
        boxShadow: emphasized
            ? tokens.glowShadow(blur: context.r(16), opacity: .25)
            : (tokens.isPixel ? tokens.cardShadow() : const []),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<OverscrollNotification>(
                onNotification: _forwardOverscroll,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false, overscroll: false),
                  child: RawScrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    interactive: true,
                    thumbColor: tokens.muted.withValues(alpha: .45),
                    thickness: 3,
                    crossAxisMargin: 3,
                    mainAxisMargin: 4,
                    radius: Radius.circular(tokens.isPixel ? 0 : 4),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      child: AvaPanelLayoutScope(child: widget.child),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.moveHandle != null)
              Positioned(
                top: tokens.borderWidth,
                right: tokens.borderWidth,
                child: widget.moveHandle!,
              ),
            if (widget.resizeHandle != null)
              Positioned(
                bottom: tokens.borderWidth,
                right: tokens.borderWidth,
                child: widget.resizeHandle!,
              ),
          ],
        ),
      ),
    );
  }
}

class _GridHandle extends StatefulWidget {
  const _GridHandle({
    super.key,
    required this.label,
    required this.resize,
    required this.enabled,
    required this.onStep,
    required this.onCancel,
  });
  final String label;
  final bool resize, enabled;
  final void Function(int dx, int dy) onStep;
  final VoidCallback onCancel;
  @override
  State<_GridHandle> createState() => _GridHandleState();
}

class _GridHandleState extends State<_GridHandle> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AvaTokens>()!;
    return Semantics(
      label: widget.label,
      onIncrease: widget.enabled ? () => widget.onStep(0, 1) : null,
      onDecrease: widget.enabled ? () => widget.onStep(0, -1) : null,
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (_, event) {
          if (!widget.enabled || event is KeyUpEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.escape) {
            widget.onCancel();
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            widget.onStep(-1, 0);
          } else if (key == LogicalKeyboardKey.arrowRight) {
            widget.onStep(1, 0);
          } else if (key == LogicalKeyboardKey.arrowUp) {
            widget.onStep(0, -1);
          } else if (key == LogicalKeyboardKey.arrowDown) {
            widget.onStep(0, 1);
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: MouseRegion(
          cursor: widget.resize
              ? SystemMouseCursors.resizeUpLeftDownRight
              : SystemMouseCursors.move,
          child: Tooltip(
            message: widget.label,
            child: Container(
              width: widget.resize ? 36 : 44,
              height: widget.resize ? 36 : 44,
              decoration: BoxDecoration(
                color: tokens.panel.withValues(alpha: .96),
                border: _focused ? Border.all(color: tokens.accent) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.resize ? Icons.open_in_full : Icons.drag_indicator,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.unit, this.color);
  final double unit;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .4)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += unit) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += dashboardGridRowHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.unit != unit || oldDelegate.color != color;
}
