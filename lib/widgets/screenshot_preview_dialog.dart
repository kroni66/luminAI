import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../services/screenshot_manager.dart';

class ScreenshotPreviewDialog extends StatefulWidget {
  final ScreenshotManager screenshotManager;
  final VoidCallback onSendToAI;
  final VoidCallback onClose;

  const ScreenshotPreviewDialog({
    super.key,
    required this.screenshotManager,
    required this.onSendToAI,
    required this.onClose,
  });

  @override
  State<ScreenshotPreviewDialog> createState() => _ScreenshotPreviewDialogState();
}

class _ScreenshotPreviewDialogState extends State<ScreenshotPreviewDialog> {
  bool _isSaving = false;
  String? _savedPath;

  @override
  Widget build(BuildContext context) {
    final screenshot = widget.screenshotManager.getCurrentScreenshot();
    if (screenshot == null) {
      return const SizedBox.shrink();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: ShadTheme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ShadTheme.of(context).colorScheme.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ShadTheme.of(context).colorScheme.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    HeroiconsOutline.camera,
                    size: 20,
                    color: ShadTheme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Screenshot Preview',
                    style: ShadTheme.of(context).textTheme.h4,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(
                      HeroiconsOutline.xMark,
                      size: 20,
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),

            // Screenshot preview
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ShadTheme.of(context).colorScheme.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        screenshot.imageData,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: ShadTheme.of(context).colorScheme.border,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Delete button
                  ShadButton.destructive(
                    onPressed: _deleteScreenshot,
                    child: Row(
                      children: [
                        Icon(HeroiconsOutline.trash, size: 16),
                        const SizedBox(width: 8),
                        const Text('Delete'),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Save button
                  ShadButton(
                    onPressed: _isSaving ? null : _saveScreenshot,
                    child: Row(
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(HeroiconsOutline.arrowDownTray, size: 16),
                        const SizedBox(width: 8),
                        Text(_savedPath != null ? 'Saved' : 'Save'),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Send to AI button
                  ShadButton(
                    onPressed: widget.onSendToAI,
                    child: Row(
                      children: [
                        Icon(HeroiconsOutline.paperAirplane, size: 16),
                        const SizedBox(width: 8),
                        const Text('Send to AI Chat'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteScreenshot() {
    widget.screenshotManager.deleteScreenshot();
    widget.onClose();
  }

  Future<void> _saveScreenshot() async {
    setState(() => _isSaving = true);
    try {
      final savedPath = await widget.screenshotManager.saveScreenshot();
      if (savedPath != null) {
        setState(() => _savedPath = savedPath);
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Screenshot saved to: $savedPath'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save screenshot'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving screenshot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
