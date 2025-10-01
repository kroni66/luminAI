import 'package:flutter/material.dart';
import '../models/widget_data.dart';

class DraggableWidget extends StatefulWidget {
  final WidgetData widgetData;
  final Function(WidgetData) onUpdate;
  final VoidCallback onRemove;
  final Widget child;

  const DraggableWidget({
    super.key,
    required this.widgetData,
    required this.onUpdate,
    required this.onRemove,
    required this.child,
  });

  @override
  State<DraggableWidget> createState() => _DraggableWidgetState();
}

class _DraggableWidgetState extends State<DraggableWidget> {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.widgetData.position.dx + _dragOffset.dx,
      top: widget.widgetData.position.dy + _dragOffset.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
        },
        onPanEnd: (details) {
          // Update the widget position when drag ends
          final newPosition = widget.widgetData.position + _dragOffset;
          widget.onUpdate(
            widget.widgetData.copyWith(position: newPosition),
          );
          setState(() {
            _isDragging = false;
            _dragOffset = Offset.zero;
          });
        },
        child: AnimatedOpacity(
          opacity: _isDragging ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: widget.child,
        ),
      ),
    );
  }
}
