import 'package:flutter/material.dart';

import 'drag_selection_controller.dart';
import 'marquee_selection_resolver.dart';

class MarqueeSelectionOverlay extends StatelessWidget {
  final DragSelectionController controller;
  final Widget child;
  final Iterable<MarqueeRowHit> Function() resolveRows;
  final ValueChanged<List<MarqueeRowHit>>? onSelectionChanged;
  final VoidCallback? onSelectionCompleted;
  final ScrollController? scrollController;
  final double edgeAutoScrollThreshold;
  final double edgeAutoScrollStep;

  const MarqueeSelectionOverlay({
    super.key,
    required this.controller,
    required this.child,
    required this.resolveRows,
    this.onSelectionChanged,
    this.onSelectionCompleted,
    this.scrollController,
    this.edgeAutoScrollThreshold = 56,
    this.edgeAutoScrollStep = 18,
  });

  void _maybeAutoScroll(BuildContext context, Offset localPosition) {
    final controller = scrollController;
    if (controller == null || !controller.hasClients) return;
    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null || !renderObject.attached) return;

    final viewportHeight = renderObject.size.height;
    final offsetY = localPosition.dy;
    var delta = 0.0;

    if (offsetY < edgeAutoScrollThreshold) {
      final intensity = 1 - (offsetY / edgeAutoScrollThreshold).clamp(0.0, 1.0);
      delta = -edgeAutoScrollStep * intensity;
    } else if (offsetY > viewportHeight - edgeAutoScrollThreshold) {
      final distanceToBottom = viewportHeight - offsetY;
      final intensity =
          1 - (distanceToBottom / edgeAutoScrollThreshold).clamp(0.0, 1.0);
      delta = edgeAutoScrollStep * intensity;
    }

    if (delta == 0) return;

    final position = controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            controller.start(details.localPosition);
          },
          onPanUpdate: (details) {
            controller.update(details.localPosition);
            _maybeAutoScroll(context, details.localPosition);
            final current = controller.current;
            if (current == null) return;
            onSelectionChanged?.call(
              resolveRowsInsideRect(
                selectionRect: current.rect,
                rows: resolveRows(),
              ),
            );
          },
          onPanEnd: (_) {
            onSelectionCompleted?.call();
            controller.clear();
          },
          onPanCancel: controller.clear,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              if (controller.current case final current?)
                Positioned.fromRect(
                  rect: current.rect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A3FF).withValues(alpha: 0.10),
                        border: Border.all(
                          color: const Color(
                            0xFF00A3FF,
                          ).withValues(alpha: 0.55),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
