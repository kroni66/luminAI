import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:blurbox/blurbox.dart';

class HoverPreviewWidget extends StatefulWidget {
  final String url;
  final String summary;
  final String? title;
  final String? screenshotUrl;
  final Offset position;
  final VoidCallback onClose;

  const HoverPreviewWidget({
    Key? key,
    required this.url,
    required this.summary,
    this.title,
    this.screenshotUrl,
    required this.position,
    required this.onClose,
  }) : super(key: key);

  @override
  State<HoverPreviewWidget> createState() => _HoverPreviewWidgetState();
}

class _HoverPreviewWidgetState extends State<HoverPreviewWidget> {
  late Offset _currentPosition;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
  }

  @override
  void didUpdateWidget(HoverPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position && !_isDragging) {
      _currentPosition = widget.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to ensure preview doesn't go off screen
    final screenSize = MediaQuery.of(context).size;
    const previewWidth = 320.0;
    const previewMaxHeight = 400.0;

    // Adjust position to keep preview on screen
    double left = _currentPosition.dx;
    double top = _currentPosition.dy;

    // Ensure preview doesn't go off the right edge
    if (left + previewWidth > screenSize.width) {
      left = screenSize.width - previewWidth - 20;
    }

    // Ensure preview doesn't go off the bottom edge
    if (top + previewMaxHeight > screenSize.height) {
      top = _currentPosition.dy - previewMaxHeight - 10;
    }

    // Ensure preview doesn't go off the top edge
    if (top < 0) {
      top = 10;
    }

    // Ensure preview doesn't go off the left edge
    if (left < 0) {
      left = 10;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: BlurBox(
          blur: 15.0,
          color: ShadTheme.of(context).colorScheme.background.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ShadTheme.of(context).colorScheme.border,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with URL - Draggable
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isDragging = true;
                      _dragOffset = details.localPosition;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentPosition = details.globalPosition - _dragOffset;
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? ShadTheme.of(context).colorScheme.muted.withOpacity(0.8)
                          : ShadTheme.of(context).colorScheme.muted,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link,
                          size: 16,
                          color: ShadTheme.of(context).colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDisplayName(),
                            style: ShadTheme.of(context).textTheme.small.copyWith(
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Screenshot (if available)
                if (widget.screenshotUrl != null && widget.screenshotUrl!.isNotEmpty)
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ShadTheme.of(context).colorScheme.muted.withOpacity(0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: ShadTheme.of(context).colorScheme.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      child: _ScreenshotWidget(
                        url: widget.screenshotUrl!,
                        targetUrl: widget.url,
                      ),
                    ),
                  ),

                // Summary text
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: ShadTheme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI Summary',
                              style: ShadTheme.of(context).textTheme.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: ShadTheme.of(context).colorScheme.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            widget.summary,
                            style: ShadTheme.of(context).textTheme.small.copyWith(
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                              height: 1.4,
                            ),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDisplayName() {
    // Prefer the extracted title if available
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }

    // Otherwise, try to make a more meaningful display from the URL
    try {
      final uri = Uri.parse(widget.url);
      if (uri.path.isNotEmpty && uri.path != '/') {
        // Extract meaningful parts from the path
        final pathParts = uri.path.split('/').where((part) => part.isNotEmpty);
        if (pathParts.isNotEmpty) {
          final lastPart = pathParts.last;
          // Convert kebab-case or snake_case to readable text
          final readableName = lastPart
              .replaceAll('-', ' ')
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
              .join(' ');
          return '$readableName - ${uri.host}';
        }
      }
      return uri.host;
    } catch (e) {
      return widget.url;
    }
  }
}

class _ScreenshotWidget extends StatefulWidget {
  final String url;
  final String targetUrl;

  const _ScreenshotWidget({
    required this.url,
    required this.targetUrl,
  });

  @override
  State<_ScreenshotWidget> createState() => _ScreenshotWidgetState();
}

class _ScreenshotWidgetState extends State<_ScreenshotWidget> {
  int _currentServiceIndex = 0;
  bool _hasError = false;

  // Alternative screenshot services
  final List<String> _screenshotServices = [
    'https://mini.s-shot.ru/1024x768/JPEG/1024/Z100/?{URL}',
    'https://image.thum.io/get/width/1024/crop/768/noanimate/{URL}',
    'https://api.screenshotmachine.com/?key=demo&url={URL}&dimension=1024x768&format=png&cacheLimit=0',
    'https://webshot.amanoteam.com/print?width=1024&height=768&url={URL}',
  ];

  String get _currentScreenshotUrl {
    if (_currentServiceIndex < _screenshotServices.length) {
      return _screenshotServices[_currentServiceIndex].replaceAll('{URL}', Uri.encodeComponent(widget.targetUrl));
    }
    return widget.url; // Fallback to original URL
  }

  void _tryNextService() {
    if (_currentServiceIndex < _screenshotServices.length - 1) {
      print('Trying screenshot service ${_currentServiceIndex + 1} of ${_screenshotServices.length}');
      setState(() {
        _currentServiceIndex++;
        _hasError = false;
      });
    } else {
      print('All screenshot services failed');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: ShadTheme.of(context).colorScheme.muted.withOpacity(0.3),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                color: ShadTheme.of(context).colorScheme.mutedForeground,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Screenshot unavailable',
                style: ShadTheme.of(context).textTheme.small.copyWith(
                  color: ShadTheme.of(context).colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Service temporarily unavailable',
                style: ShadTheme.of(context).textTheme.small.copyWith(
                  color: ShadTheme.of(context).colorScheme.mutedForeground,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Image.network(
      _currentScreenshotUrl,
      fit: BoxFit.cover,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      errorBuilder: (context, error, stackTrace) {
        print('Screenshot error for service $_currentServiceIndex (${_screenshotServices[_currentServiceIndex]}): $error');
        // Try next service on error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tryNextService();
        });

        return Container(
          color: ShadTheme.of(context).colorScheme.muted.withOpacity(0.3),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 8),
                Text(
                  'Trying alternative service...',
                  style: ShadTheme.of(context).textTheme.small.copyWith(
                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          color: ShadTheme.of(context).colorScheme.muted.withOpacity(0.3),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading screenshot...',
                  style: ShadTheme.of(context).textTheme.small.copyWith(
                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                  ),
                ),
                if (loadingProgress.expectedTotalBytes != null)
                  Text(
                    '${(loadingProgress.cumulativeBytesLoaded / 1024).round()}KB / ${(loadingProgress.expectedTotalBytes! / 1024).round()}KB',
                    style: ShadTheme.of(context).textTheme.small.copyWith(
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
