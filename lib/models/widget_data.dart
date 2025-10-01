import 'package:flutter/material.dart';

enum WidgetType {
  rssFeed,
  // Add more widget types here in the future
}

class WidgetData {
  final String id;
  final WidgetType type;
  final Offset position;
  final Size size;
  final Map<String, dynamic> settings;
  final bool isVisible;

  WidgetData({
    required this.id,
    required this.type,
    required this.position,
    this.size = const Size(300, 200),
    this.settings = const {},
    this.isVisible = true,
  });

  WidgetData copyWith({
    String? id,
    WidgetType? type,
    Offset? position,
    Size? size,
    Map<String, dynamic>? settings,
    bool? isVisible,
  }) {
    return WidgetData(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      size: size ?? this.size,
      settings: settings ?? this.settings,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'positionX': position.dx,
      'positionY': position.dy,
      'width': size.width,
      'height': size.height,
      'settings': settings,
      'isVisible': isVisible,
    };
  }

  factory WidgetData.fromJson(Map<String, dynamic> json) {
    return WidgetData(
      id: json['id'],
      type: WidgetType.values.firstWhere((e) => e.name == json['type']),
      position: Offset(json['positionX'].toDouble(), json['positionY'].toDouble()),
      size: Size(json['width'].toDouble(), json['height'].toDouble()),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      isVisible: json['isVisible'] ?? true,
    );
  }
}

abstract class BaseWidget extends StatefulWidget {
  final WidgetData data;
  final VoidCallback? onRemove;
  final Function(WidgetData)? onUpdate;

  const BaseWidget({
    super.key,
    required this.data,
    this.onRemove,
    this.onUpdate,
  });
}

abstract class BaseWidgetState<T extends BaseWidget> extends State<T> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.data.size.width,
      height: widget.data.size.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: buildContent(context),
    );
  }

  @protected
  Widget buildContent(BuildContext context);
}
