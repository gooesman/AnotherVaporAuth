import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Lightweight, keyed cards: editing never replaces the cards or their readers.
class DashboardCardLayout extends StatefulWidget {
  const DashboardCardLayout({
    super.key,
    required this.cards,
    required this.titles,
    required this.order,
    required this.spans,
    required this.editing,
    required this.onMove,
    required this.onResize,
    required this.dragLabel,
    required this.resizeLabel,
  });

  final Map<String, Widget> cards;
  final Map<String, String> titles;
  final List<String> order;
  final Map<String, int> spans;
  final bool editing;
  final Future<void> Function(String moving, String target) onMove;
  final Future<void> Function(String section, int span) onResize;
  final String dragLabel, resizeLabel;

  @override
  State<DashboardCardLayout> createState() => _DashboardCardLayoutState();
}

class _DashboardCardLayoutState extends State<DashboardCardLayout> {
  static const _gap = 16.0;
  final _keys = <String, GlobalKey>{};
  EdgeDraggingAutoScroller? _scroller;
  String? _dragging, _target, _resizing;
  Offset? _pointer;
  bool _cancelled = false;
  bool _savingResize = false;
  bool _resizeCancelled = false;
  int? _previewSpan;
  double _resizeStart = 0, _resizeWidth = 0;

  List<String> get _sections => {
    ...widget.order.where(widget.cards.containsKey),
    ...widget.cards.keys,
  }.toList();

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
              onScrollViewScrolled: _updateDropTarget,
            );
    }
  }

  @override
  void didUpdateWidget(DashboardCardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing || !widget.cards.containsKey(_dragging)) _stopDrag();
    if (!widget.editing || !widget.cards.containsKey(_resizing)) {
      _resizing = null;
      _previewSpan = null;
    }
    _keys.removeWhere((id, _) => !widget.cards.containsKey(id));
  }

  @override
  void dispose() {
    _scroller?.stopAutoScroll();
    super.dispose();
  }

  void _stopDrag() {
    _scroller?.stopAutoScroll();
    _dragging = _target = null;
    _pointer = null;
  }

  void _updateDropTarget() {
    final pointer = _pointer;
    if (!mounted || _dragging == null || pointer == null) return;
    String? target;
    for (final id in _sections) {
      if (id == _dragging) continue;
      final box = _keys[id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.attached) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.contains(pointer)) {
          target = id;
          break;
        }
      }
    }
    if (_target != target) setState(() => _target = target);
    // A small cursor rectangle starts scrolling just before the viewport edge.
    _scroller?.startAutoScrollIfNecessary(
      Rect.fromCenter(center: pointer, width: 1, height: 48),
    );
  }

  void _finishDrag() {
    final moving = _dragging;
    final target = _target;
    final cancelled = _cancelled;
    setState(_stopDrag);
    if (!cancelled && moving != null && target != null && widget.editing) {
      unawaited(widget.onMove(moving, target));
    }
  }

  Future<void> _finishResize(String id) async {
    final span = _previewSpan;
    try {
      if (!_resizeCancelled &&
          widget.editing &&
          span != null &&
          span != (widget.spans[id] ?? 3)) {
        setState(() => _savingResize = true);
        await widget.onResize(id, span);
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingResize = false;
          _resizing = null;
          _previewSpan = null;
        });
      }
    }
  }

  void _resizeStep(String id, int span) {
    if (_savingResize || _resizing != null || _dragging != null) return;
    setState(() {
      _resizing = id;
      _previewSpan = span;
      _resizeCancelled = false;
    });
    unawaited(_finishResize(id));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final columns = _mobile
          ? 1
          : ((width + _gap) / (340 + _gap)).floor().clamp(1, 3);
      final unit = (width + _gap) / columns;
      final sections = _sections;
      final tokens = Theme.of(context).extension<AvaTokens>()!;
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final id in sections)
            Builder(
              key: ValueKey('dashboard-layout-$id'),
              builder: (context) {
                final stored = _resizing == id
                    ? _previewSpan ?? widget.spans[id] ?? 3
                    : widget.spans[id] ?? 3;
                final span = stored == 3 ? columns : stored.clamp(1, columns);
                final index = sections.indexOf(id);
                final title = widget.titles[id] ?? id;
                final canResize =
                    !_savingResize &&
                    _dragging == null &&
                    (_resizing == null || _resizing == id);
                final after =
                    _dragging != null && sections.indexOf(_dragging!) < index;
                return SizedBox(
                  key: _keys.putIfAbsent(id, GlobalKey.new),
                  width: unit * span - _gap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.editing)
                            Row(
                              key: const ValueKey('edit-header'),
                              children: [
                                Listener(
                                  onPointerCancel: (_) => _cancelled = true,
                                  child: Draggable<String>(
                                    data: id,
                                    maxSimultaneousDrags: _resizing == null
                                        ? 1
                                        : 0,
                                    dragAnchorStrategy:
                                        pointerDragAnchorStrategy,
                                    onDragStarted: () {
                                      _cancelled = false;
                                      setState(() => _dragging = id);
                                    },
                                    onDragUpdate: (details) {
                                      _pointer = details.globalPosition;
                                      _updateDropTarget();
                                    },
                                    onDragEnd: (_) => _finishDrag(),
                                    feedback: Material(
                                      elevation: 3,
                                      color: tokens.panel,
                                      borderRadius: BorderRadius.circular(
                                        tokens.radiusSm,
                                      ),
                                      child: SizedBox(
                                        width: 220,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: _LayoutHandle(
                                      key: ValueKey('dashboard-drag-$id'),
                                      label: '${widget.dragLabel}: $title',
                                      icon: Icons.drag_indicator,
                                      cursor: SystemMouseCursors.grab,
                                      decrease: index == 0
                                          ? null
                                          : () => unawaited(
                                              widget.onMove(
                                                id,
                                                sections[index - 1],
                                              ),
                                            ),
                                      increase: index == sections.length - 1
                                          ? null
                                          : () => unawaited(
                                              widget.onMove(
                                                id,
                                                sections[index + 1],
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          KeyedSubtree(
                            key: const ValueKey('content'),
                            child: widget.cards[id]!,
                          ),
                          if (widget.editing && !_mobile && columns > 1)
                            Align(
                              key: const ValueKey('edit-width'),
                              alignment: AlignmentDirectional.centerEnd,
                              child: Listener(
                                onPointerCancel: (_) => _resizeCancelled = true,
                                child: GestureDetector(
                                  dragStartBehavior: DragStartBehavior.down,
                                  onHorizontalDragStart: !canResize
                                      ? null
                                      : (details) {
                                          _resizeCancelled = false;
                                          _resizeStart =
                                              details.globalPosition.dx;
                                          _resizeWidth = unit * span;
                                          setState(() {
                                            _resizing = id;
                                            _previewSpan = stored;
                                          });
                                        },
                                  onHorizontalDragUpdate: !canResize
                                      ? null
                                      : (details) {
                                          if (_resizing != id) return;
                                          final direction =
                                              Directionality.of(context) ==
                                                  TextDirection.rtl
                                              ? -1
                                              : 1;
                                          final next =
                                              ((_resizeWidth +
                                                          direction *
                                                              (details
                                                                      .globalPosition
                                                                      .dx -
                                                                  _resizeStart)) /
                                                      unit)
                                                  .round()
                                                  .clamp(1, columns);
                                          final saved = next == columns
                                              ? 3
                                              : next;
                                          if (_previewSpan != saved) {
                                            setState(
                                              () => _previewSpan = saved,
                                            );
                                          }
                                        },
                                  onHorizontalDragEnd: !canResize
                                      ? null
                                      : (_) => unawaited(_finishResize(id)),
                                  onHorizontalDragCancel: !canResize
                                      ? null
                                      : () => setState(() {
                                          _resizing = null;
                                          _previewSpan = null;
                                        }),
                                  child: _LayoutHandle(
                                    key: ValueKey('dashboard-resize-$id'),
                                    label: '${widget.resizeLabel}: $title',
                                    icon: Icons.swap_horiz,
                                    cursor: SystemMouseCursors.resizeLeftRight,
                                    horizontal: true,
                                    decrease:
                                        _savingResize ||
                                            _resizing != null ||
                                            span <= 1
                                        ? null
                                        : () => _resizeStep(id, span - 1),
                                    increase:
                                        _savingResize ||
                                            _resizing != null ||
                                            span >= columns
                                        ? null
                                        : () => _resizeStep(
                                            id,
                                            span + 1 == columns ? 3 : span + 1,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_target == id)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: after ? null : -5,
                          bottom: after ? -5 : null,
                          child: Container(
                            key: ValueKey('dashboard-insert-$id'),
                            height: 3,
                            color: tokens.accent,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class _StepIntent extends Intent {
  const _StepIntent(this.increase);
  final bool increase;
}

class _LayoutHandle extends StatefulWidget {
  const _LayoutHandle({
    super.key,
    required this.label,
    required this.icon,
    required this.cursor,
    this.horizontal = false,
    this.decrease,
    this.increase,
  });
  final String label;
  final IconData icon;
  final MouseCursor cursor;
  final bool horizontal;
  final VoidCallback? decrease, increase;

  @override
  State<_LayoutHandle> createState() => _LayoutHandleState();
}

class _LayoutHandleState extends State<_LayoutHandle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    onDecrease: widget.decrease,
    onIncrease: widget.increase,
    child: FocusableActionDetector(
      mouseCursor: widget.cursor,
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      shortcuts: {
        SingleActivator(
          widget.horizontal
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowUp,
        ): const _StepIntent(
          false,
        ),
        SingleActivator(
          widget.horizontal
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowDown,
        ): const _StepIntent(
          true,
        ),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (intent) {
            (intent.increase ? widget.increase : widget.decrease)?.call();
            return null;
          },
        ),
      },
      child: Tooltip(
        message: widget.label,
        child: Container(
          width: widget.horizontal ? 36 : 44,
          height: widget.horizontal ? 36 : 44,
          decoration: BoxDecoration(
            border: _focused
                ? Border.all(color: Theme.of(context).colorScheme.primary)
                : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 20),
        ),
      ),
    ),
  );
}
