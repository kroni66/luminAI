import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../services/screenshot_manager.dart';

class ScreenshotOverlay extends StatefulWidget {
  final ScreenshotManager screenshotManager;
  final VoidCallback onCancel;
  final double sidebarWidth;

  const ScreenshotOverlay({
    super.key,
    required this.screenshotManager,
    required this.onCancel,
    required this.sidebarWidth,
  });

  @override
  State<ScreenshotOverlay> createState() => _ScreenshotOverlayState();
}

class _ScreenshotOverlayState extends State<ScreenshotOverlay> {
  Offset? _startPoint;
  Offset? _endPoint;
  Rect? _selectionRect;
  int _lastUpdateTime = 0;
  int? _lastDebugTime;

  @override
  void initState() {
    super.initState();
    // Don't override callbacks - rely on browser screen's conditional rendering
  }

  @override
  Widget build(BuildContext context) {
    // If mode changed to preview or idle, don't render the overlay
    if (widget.screenshotManager.mode != ScreenshotMode.capturing) {
      debugPrint('ScreenshotOverlay: Mode is ${widget.screenshotManager.mode}, not rendering overlay');
      return const SizedBox.shrink();
    }

    debugPrint('ScreenshotOverlay: Rendering overlay, mode: ${widget.screenshotManager.mode}');
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        debugPrint('ScreenshotOverlay: Pointer down at ${event.localPosition}');
        _onPanStart(DragStartDetails(localPosition: event.localPosition));
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_startPoint != null) {
          _onPanUpdate(DragUpdateDetails(
            localPosition: event.localPosition,
            globalPosition: event.position,
            delta: event.delta,
          ));
        }
      },
      onPointerUp: (PointerUpEvent event) {
        debugPrint('ScreenshotOverlay: >>> POINTER UP DETECTED <<< at ${event.localPosition}');
        try {
          if (_selectionRect != null && _selectionRect!.width > 1 && _selectionRect!.height > 1) {
            debugPrint('ScreenshotOverlay: Capturing selected area (size: ${_selectionRect!.width}x${_selectionRect!.height})');
            _captureSelectedArea();
          } else {
            debugPrint('ScreenshotOverlay: No valid selection, capturing full screen instead');
            _captureFullScreen();
          }
        } catch (e, stackTrace) {
          debugPrint('ScreenshotOverlay: Exception in onPointerUp: $e');
          debugPrint('ScreenshotOverlay: Stack trace: $stackTrace');
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: Stack(
          children: [
            // Semi-transparent overlay
            Container(
              color: Colors.black.withOpacity(0.3),
            ),

            // Selection rectangle
            if (_selectionRect != null)
              Positioned(
                left: _selectionRect!.left,
                top: _selectionRect!.top,
                child: Container(
                  width: _selectionRect!.width,
                  height: _selectionRect!.height,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                    color: Colors.blue.withOpacity(0.1),
                  ),
                ),
              ),

            // Control buttons
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ShadTheme.of(context).colorScheme.background.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ShadTheme.of(context).colorScheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    // Capture full screen button
                    ShadButton(
                      onPressed: _captureFullScreen,
                      child: Row(
                        children: [
                          Icon(HeroiconsOutline.camera, size: 16),
                          const SizedBox(width: 8),
                          const Text('Capture Full Screen'),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Capture selected area button (only show if there's a selection)
                    if (_selectionRect != null)
                      ShadButton(
                        onPressed: _captureSelectedArea,
                        child: Row(
                          children: [
                            Icon(HeroiconsOutline.scissors, size: 16),
                            const SizedBox(width: 8),
                            const Text('Capture Selected'),
                          ],
                        ),
                      ),

                    const SizedBox(width: 8),

                    // Cancel button
                    ShadButton.destructive(
                      onPressed: widget.onCancel,
                      child: Row(
                        children: [
                          Icon(HeroiconsOutline.xMark, size: 16),
                          const SizedBox(width: 8),
                          const Text('Cancel'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    debugPrint('ScreenshotOverlay: Pan start at ${details.localPosition}');
    setState(() {
      _startPoint = details.localPosition;
      _endPoint = details.localPosition;
      _updateSelectionRect();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _endPoint = details.localPosition;
      _updateSelectionRect();
    });
  }


  void _updateSelectionRect() {
    if (_startPoint != null && _endPoint != null) {
      // Throttle updates to reduce debug output and potential performance issues
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastUpdateTime < 50) return; // Only update every 50ms
      _lastUpdateTime = now;

      // Only debug print normalized values every 500ms
      final shouldDebugPrint = (now - (_lastDebugTime ?? 0)) > 500;
      if (shouldDebugPrint) {
        _lastDebugTime = now;
      }

      final left = _startPoint!.dx < _endPoint!.dx ? _startPoint!.dx : _endPoint!.dx;
      final top = _startPoint!.dy < _endPoint!.dy ? _startPoint!.dy : _endPoint!.dy;
      final width = (_startPoint!.dx - _endPoint!.dx).abs();
      final height = (_startPoint!.dy - _endPoint!.dy).abs();

      _selectionRect = Rect.fromLTWH(left, top, width, height);

      // Convert to normalized coordinates (0.0 to 1.0)
      // Use the same method as screenshot manager for consistency
      Size screenSize;
    try {
      screenSize = MediaQueryData.fromWindow(ui.window).size;
    } catch (e, stackTrace) {
      debugPrint('ScreenshotOverlay: Exception getting screen size: $e');
      debugPrint('ScreenshotOverlay: Stack trace: $stackTrace');
      return; // Can't proceed without screen size
    }

      // Adjust coordinates to account for WebView positioning (sidebar + app bar offset)
      final appBarHeight = 72.0; // Actual app bar height from browser_screen.dart
      final webViewLeft = left - widget.sidebarWidth;
      final webViewTop = top - appBarHeight;
      final webViewWidth = width;
      final webViewHeight = height;

      // Ensure coordinates are within WebView bounds
      final webViewHeightAvailable = screenSize.height - appBarHeight;
      final clampedLeft = webViewLeft.clamp(0.0, screenSize.width - widget.sidebarWidth);
      final clampedTop = webViewTop.clamp(0.0, webViewHeightAvailable);
      final clampedWidth = webViewWidth.clamp(1.0, screenSize.width - widget.sidebarWidth - clampedLeft);
      final clampedHeight = webViewHeight.clamp(1.0, webViewHeightAvailable - clampedTop);

      final normalizedLeft = clampedLeft / (screenSize.width - widget.sidebarWidth);
      final normalizedTop = clampedTop / webViewHeightAvailable;
      final normalizedRight = (clampedLeft + clampedWidth) / (screenSize.width - widget.sidebarWidth);
      final normalizedBottom = (clampedTop + clampedHeight) / webViewHeightAvailable;

    // Validate normalized values
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      debugPrint('ScreenshotOverlay: Invalid screen size: ${screenSize.width}x${screenSize.height}');
      return;
    }

    // Clamp normalized values to valid range
    final finalLeft = normalizedLeft.clamp(0.0, 1.0);
    final finalTop = normalizedTop.clamp(0.0, 1.0);
    final finalRight = normalizedRight.clamp(0.0, 1.0);
    final finalBottom = normalizedBottom.clamp(0.0, 1.0);

    if (shouldDebugPrint) {
      debugPrint('ScreenshotOverlay: Normalized values - left:$finalLeft, top:$finalTop, right:$finalRight, bottom:$finalBottom');
    }

    final normalizedRect = Rect.fromLTRB(
      finalLeft,
      finalTop,
      finalRight,
      finalBottom,
    );

      try {
        widget.screenshotManager.setSelectedRegion(normalizedRect);
        if (shouldDebugPrint) {
          debugPrint('ScreenshotOverlay: Normalized rect: $normalizedRect');
        }
      } catch (e, stackTrace) {
        debugPrint('ScreenshotOverlay: Exception in setSelectedRegion: $e');
        debugPrint('ScreenshotOverlay: Stack trace: $stackTrace');
      }
    }
  }

  Future<void> _captureFullScreen() async {
    debugPrint('ScreenshotOverlay: _captureFullScreen called');
    widget.screenshotManager.clearSelectedRegion();
    try {
      final success = await widget.screenshotManager.captureScreenshot();
      debugPrint('ScreenshotOverlay: Full screen capture result: $success');

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture screenshot. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('ScreenshotOverlay: Exception during full screen capture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing screenshot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _captureSelectedArea() async {
    debugPrint('ScreenshotOverlay: _captureSelectedArea called');
    if (_selectionRect != null) {
      debugPrint('ScreenshotOverlay: Calling screenshotManager.captureScreenshot()');
      try {
        final success = await widget.screenshotManager.captureScreenshot();
        debugPrint('ScreenshotOverlay: captureScreenshot result: $success');

        if (!success) {
          debugPrint('ScreenshotOverlay: Screenshot capture failed, showing error');
          // Show error message but don't crash
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to capture screenshot. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('ScreenshotOverlay: Exception during screenshot capture: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error capturing screenshot: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      debugPrint('ScreenshotOverlay: No selection rect in _captureSelectedArea');
    }
  }
}
