import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/tab_info.dart';
import '../models/widget_data.dart';
import 'widget_factory.dart';
import 'draggable_widget.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';

class FavoriteAppItem {
  final String title;
  final String url;
  final String bg;
  final String fg;

  FavoriteAppItem({
    required this.title,
    required this.url,
    required this.bg,
    required this.fg,
  });
}

class AIRec {
  final String title;
  final String description;
  final String url;
  final String category;
  final String reason;

  AIRec({
    required this.title,
    required this.description,
    required this.url,
    required this.category,
    required this.reason,
  });
}

class NewTabPage extends StatefulWidget {
  final List<FavoriteAppItem> defaults;
  final List<FavoriteAppItem> customs;
  final List<TabInfo> tabs;
  final List<AIRec>? aiRecommendations;
  final bool isGeneratingRecommendations;
  final void Function(String url) onOpen;
  final void Function(FavoriteAppItem item) onRemoveCustom;
  final void Function() onAddRequest;
  final Future<void> Function()? onRegenerateRecommendations;
  final List<WidgetData> widgets;
  final void Function(WidgetType) onAddWidget;
  final void Function(String) onRemoveWidget;
  final void Function(WidgetData) onUpdateWidget;

  const NewTabPage({
    super.key,
    required this.defaults,
    required this.customs,
    required this.tabs,
    this.aiRecommendations,
    required this.isGeneratingRecommendations,
    required this.onOpen,
    required this.onRemoveCustom,
    required this.onAddRequest,
    this.onRegenerateRecommendations,
    required this.widgets,
    required this.onAddWidget,
    required this.onRemoveWidget,
    required this.onUpdateWidget,
  });

  @override
  State<NewTabPage> createState() => _NewTabPageState();
}

class ThreeDotLoadingIndicator extends StatefulWidget {
  const ThreeDotLoadingIndicator({super.key});

  @override
  State<ThreeDotLoadingIndicator> createState() => _ThreeDotLoadingIndicatorState();
}

class _ThreeDotLoadingIndicatorState extends State<ThreeDotLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          final animation = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(
                index * 0.2,
                (index + 1) * 0.2,
                curve: Curves.easeInOut,
              ),
            ),
          );

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -8 * animation.value),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _NewTabPageState extends State<NewTabPage> {
  int? _hoveredIndex;
  bool _isRegenerating = false;
  late ContextMenu _contextMenu;

  @override
  void initState() {
    super.initState();
    _contextMenu = ContextMenu(
      entries: [
        MenuItem(
          label: 'Add Widget',
          icon: Icons.add,
          onSelected: () => _showWidgetSelector(),
        ),
        if (widget.widgets.isNotEmpty)
          MenuItem(
            label: 'Remove All Widgets',
            icon: Icons.delete_sweep,
            onSelected: () => _removeAllWidgets(),
          ),
      ],
    );
  }

  void _showWidgetSelector() {
    showDialog(
      context: context,
      builder: (context) => WidgetSelectorDialog(
        onWidgetSelected: widget.onAddWidget,
      ),
    );
  }

  void _removeAllWidgets() {
    for (final widgetData in widget.widgets) {
      widget.onRemoveWidget(widgetData.id);
    }
  }

  String _getFaviconUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return '';
      return 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=64';
    } catch (e) {
      return '';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
      case 'productivity':
        return Colors.blue;
      case 'news':
      case 'information':
        return Colors.green;
      case 'social':
        return Colors.purple;
      case 'entertainment':
        return Colors.orange;
      case 'shopping':
        return Colors.pink;
      case 'research':
        return Colors.teal;
      case 'learning':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <FavoriteAppItem>[...widget.defaults, ...widget.customs];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1113), Color(0xFF000000)],
        ),
      ),
      child: ContextMenuRegion(
        contextMenu: _contextMenu,
        child: Stack(
          children: [
            // Widgets overlay
            ...widget.widgets.map((widgetData) {
              return Positioned(
                left: widgetData.position.dx,
                top: widgetData.position.dy,
                child: DraggableWidget(
                  widgetData: widgetData,
                  onUpdate: widget.onUpdateWidget,
                  onRemove: () => widget.onRemoveWidget(widgetData.id),
                  child: SizedBox(
                    width: widgetData.size.width,
                    height: widgetData.size.height,
                    child: WidgetFactory.createWidget(
                      widgetData,
                      onRemove: () => widget.onRemoveWidget(widgetData.id),
                      onUpdate: widget.onUpdateWidget,
                    ),
                  ),
                ),
              );
            }),

            // Main content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                // LUMIN Logo and Subtitle Section
                Column(
                  children: [
                    // LUMIN Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'lib/assets/LUMIN.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if image fails to load
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF4A5568),
                                    Color(0xFF2D3748),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'LUMIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Subtitle with shadcn UI styling
                    Text(
                      'Stay curious, stay limitless.',
                      style: ShadTheme.of(context).textTheme.large.copyWith(
                        color: ShadTheme.of(context).colorScheme.mutedForeground,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // AI Recommendations Section (only show if >3 tabs)
                if (widget.tabs.length > 3)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AI Recommendations',
                            style: ShadTheme.of(context).textTheme.h4.copyWith(
                              color: ShadTheme.of(context).colorScheme.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.onRegenerateRecommendations != null)
                            ShadButton.outline(
                              onPressed: _isRegenerating || widget.isGeneratingRecommendations ? null : () async {
                                setState(() => _isRegenerating = true);
                                try {
                                  await widget.onRegenerateRecommendations!();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isRegenerating = false);
                                  }
                                }
                              },
                              size: ShadButtonSize.sm,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isRegenerating || widget.isGeneratingRecommendations)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  else
                                    Icon(Icons.refresh, size: 16),
                                  const SizedBox(width: 4),
                                  Text(_isRegenerating || widget.isGeneratingRecommendations ? 'Generating...' : 'Regenerate'),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on your current tabs, here\'s what you might want to visit next',
                        style: ShadTheme.of(context).textTheme.small.copyWith(
                          color: ShadTheme.of(context).colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Show loading animation when generating recommendations
                      if (widget.isGeneratingRecommendations)
                        Container(
                          height: 155,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Three-dot loading animation
                              const ThreeDotLoadingIndicator(),
                              const SizedBox(width: 12),
                              Text(
                                'Generating recommendations...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      // Show recommendations if they exist
                      else if (widget.aiRecommendations != null && widget.aiRecommendations!.isNotEmpty)
                        SizedBox(
                          height: 155,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.aiRecommendations!.length,
                            itemBuilder: (context, index) {
                              final rec = widget.aiRecommendations![index];
                              return Container(
                                width: 280,
                                margin: const EdgeInsets.only(right: 12),
                                child: Card(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () => widget.onOpen(rec.url),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getCategoryColor(rec.category),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  rec.category,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.smart_toy,
                                                size: 16,
                                                color: Colors.blue,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            rec.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            rec.description,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            rec.reason,
                                            style: TextStyle(
                                              color: Colors.blue.shade300,
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      // Show placeholder when no recommendations and not generating
                      else
                        Container(
                          height: 155,
                          alignment: Alignment.center,
                          child: Text(
                            'AI recommendations will appear here once generated',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),

                // Favorites Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Favorites',
                          style: ShadTheme.of(context).textTheme.h4.copyWith(
                            color: ShadTheme.of(context).colorScheme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ShadButton.outline(
                          onPressed: widget.onAddRequest,
                          size: ShadButtonSize.sm,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16),
                              SizedBox(width: 4),
                              Text('Add'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                    final item = items[index];
                    final isCustom = index >= widget.defaults.length;
                    final bgColor = _parseColor(item.bg, const Color(0x11000000));
                    final fgColor = _parseColor(item.fg, Colors.white);
                    final isHovered = _hoveredIndex == index;

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        transform: isHovered ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onOpen(item.url),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: isHovered 
                                ? Colors.white.withOpacity(0.12)
                                : Colors.white.withOpacity(0.06),
                              border: Border.all(
                                color: isHovered 
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.12),
                                width: isHovered ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isHovered 
                                          ? bgColor.withOpacity(0.9)
                                          : bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: isHovered
                                          ? [
                                              BoxShadow(
                                                color: bgColor.withOpacity(0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _getFaviconUrl(item.url),
                                          width: isHovered ? 24 : 20,
                                          height: isHovered ? 24 : 20,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            // Fallback to text icon if favicon fails to load
                                            return AnimatedDefaultTextStyle(
                                              duration: const Duration(milliseconds: 200),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: isHovered ? 16 : 14,
                                                color: fgColor,
                                              ),
                                              child: Text(
                                                (item.title.isNotEmpty ? item.title[0] : '?').toUpperCase(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    if (isCustom)
                                      AnimatedPositioned(
                                        duration: const Duration(milliseconds: 200),
                                        right: isHovered ? -2 : 0,
                                        top: isHovered ? -2 : 0,
                                        child: AnimatedOpacity(
                                          duration: const Duration(milliseconds: 200),
                                          opacity: isHovered ? 1.0 : 0.7,
                                          child: InkWell(
                                            onTap: () => widget.onRemoveCustom(item),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: isHovered ? 16 : 14,
                                              height: isHovered ? 16 : 14,
                                              decoration: BoxDecoration(
                                                color: isHovered 
                                                  ? Colors.red.withOpacity(0.2)
                                                  : Colors.white.withOpacity(0.06),
                                                border: Border.all(
                                                  color: isHovered 
                                                    ? Colors.red.withOpacity(0.5)
                                                    : Colors.white.withOpacity(0.16),
                                                ),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.close, 
                                                size: isHovered ? 10 : 8, 
                                                color: isHovered ? Colors.red : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    color: isHovered ? Colors.white : Colors.white.withOpacity(0.9),
                                    fontSize: isHovered ? 12 : 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
  ),
);
}

  static Color _parseColor(String cssHex, Color fallback) {
    try {
      var hex = cssHex.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.length == 6) {
        hex = 'FF' + hex; // add alpha
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}

class WidgetSelectorDialog extends StatelessWidget {
  final void Function(WidgetType) onWidgetSelected;

  const WidgetSelectorDialog({super.key, required this.onWidgetSelected});

  @override
  Widget build(BuildContext context) {
    final availableWidgets = [
      WidgetType.rssFeed,
      // Add more widget types here as they become available
    ];

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1113),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      title: const Text('Add Widget'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableWidgets.map((widgetType) {
            return InkWell(
              onTap: () {
                onWidgetSelected(widgetType);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      WidgetFactory.getWidgetIcon(widgetType),
                      color: Colors.white.withOpacity(0.9),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WidgetFactory.getWidgetDisplayName(widgetType),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            WidgetFactory.getWidgetDescription(widgetType),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.add,
                      color: Colors.white.withOpacity(0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class AddFavoriteDialog extends StatefulWidget {
  final void Function(String title, String url, String bg, String fg) onSave;

  const AddFavoriteDialog({super.key, required this.onSave});

  @override
  State<AddFavoriteDialog> createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<AddFavoriteDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _bg = TextEditingController(text: '#00000011');
  final TextEditingController _fg = TextEditingController(text: '#FFFFFF');

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _bg.dispose();
    _fg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1113),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: Colors.white),
      title: const Text('Add Favorite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(label: 'Name', controller: _name, hint: 'e.g. YouTube'),
          _field(label: 'URL', controller: _url, hint: 'https://example.com'),
          _field(label: 'Background', controller: _bg, hint: '#00000011'),
          _field(label: 'Foreground', controller: _fg, hint: '#FFFFFF'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final rawUrl = _url.text.trim();
            if (rawUrl.isEmpty) return;
            final url = rawUrl.startsWith('http') ? rawUrl : 'https://' + rawUrl;
            widget.onSave(name.isEmpty ? url : name, url, _bg.text.trim(), _fg.text.trim());
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        )
      ],
    );
  }

  Widget _field({required String label, required TextEditingController controller, required String hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}


