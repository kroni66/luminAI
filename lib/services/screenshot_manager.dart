import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';

class ScreenshotData {
  final String id;
  final Uint8List imageData;
  final DateTime timestamp;
  final String? filePath; // null if not saved yet

  ScreenshotData({
    required this.id,
    required this.imageData,
    required this.timestamp,
    this.filePath,
  });

  // Create a copy with updated file path
  ScreenshotData copyWith({String? filePath}) {
    return ScreenshotData(
      id: id,
      imageData: imageData,
      timestamp: timestamp,
      filePath: filePath,
    );
  }
}

enum ScreenshotMode {
  idle,
  capturing,
  preview,
}

class ScreenshotManager {
  final _uuid = const Uuid();

  // Screenshot controller for capturing widgets
  final ScreenshotController _screenshotController = ScreenshotController();

  // Current screenshot mode
  ScreenshotMode _mode = ScreenshotMode.idle;
  ScreenshotMode get mode => _mode;

  // Getter for screenshot controller
  ScreenshotController get screenshotController => _screenshotController;

  // Current screenshot data
  ScreenshotData? _currentScreenshot;

  // Region selection
  Rect? _selectedRegion;
  Rect? get selectedRegion => _selectedRegion;

  // Callbacks
  VoidCallback? onModeChanged;
  VoidCallback? onScreenshotTaken;
  VoidCallback? onScreenshotCleared;

  void setSelectedRegion(Rect region) {
    _selectedRegion = region;
  }

  void clearSelectedRegion() {
    _selectedRegion = null;
  }

  Future<void> enterScreenshotMode() async {
    debugPrint('ScreenshotManager: enterScreenshotMode called, current mode: $_mode');
    _mode = ScreenshotMode.capturing;
    _currentScreenshot = null;
    _selectedRegion = null;
    debugPrint('ScreenshotManager: Mode set to capturing, calling onModeChanged');
    onModeChanged?.call();
  }

  void exitScreenshotMode() {
    _mode = ScreenshotMode.idle;
    _currentScreenshot = null;
    _selectedRegion = null;
    onModeChanged?.call();
  }

  Future<bool> captureScreenshot() async {
    debugPrint('ScreenshotManager: captureScreenshot called, current mode: $_mode, selectedRegion: $_selectedRegion');
    try {
      debugPrint('ScreenshotManager: Taking screenshot using screenshot package...');

      // Capture the screenshot using the screenshot package
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes == null || imageBytes.isEmpty) {
        debugPrint('ScreenshotManager: Screenshot capture returned null or empty data');
        return false;
      }

      debugPrint('ScreenshotManager: Screenshot captured successfully, size: ${imageBytes.length} bytes');

      // If a region is selected, crop the image
      Uint8List finalImageData = imageBytes;

      if (_selectedRegion != null) {
        debugPrint('ScreenshotManager: Cropping image with region: $_selectedRegion');
        debugPrint('ScreenshotManager: Region values - left:${_selectedRegion!.left}, top:${_selectedRegion!.top}, right:${_selectedRegion!.right}, bottom:${_selectedRegion!.bottom}');
        try {
          finalImageData = await _cropImage(imageBytes, _selectedRegion!);
          debugPrint('ScreenshotManager: Image cropped successfully, final size: ${finalImageData.length}');
        } catch (cropError, cropStackTrace) {
          debugPrint('ScreenshotManager: Error during image cropping: $cropError');
          debugPrint('ScreenshotManager: Crop stack trace: $cropStackTrace');
          return false;
        }
      }

      _currentScreenshot = ScreenshotData(
        id: _uuid.v4(),
        imageData: finalImageData,
        timestamp: DateTime.now(),
      );

      debugPrint('ScreenshotManager: Setting mode to preview');
      _mode = ScreenshotMode.preview;
      debugPrint('ScreenshotManager: Calling onScreenshotTaken callback');
      onScreenshotTaken?.call();

      debugPrint('ScreenshotManager: Screenshot capture completed successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('ScreenshotManager: Error capturing screenshot: $e');
      debugPrint('ScreenshotManager: Stack trace: $stackTrace');
      return false;
    }
  }


  Future<Uint8List> _cropImage(Uint8List imageBytes, Rect region) async {
    debugPrint('ScreenshotManager: _cropImage called with region: $region');
    debugPrint('ScreenshotManager: Region values - left:${region.left}, top:${region.top}, right:${region.right}, bottom:${region.bottom}');
    debugPrint('ScreenshotManager: Image bytes length: ${imageBytes.length}');

    // Decode the image
    final img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      debugPrint('ScreenshotManager: Failed to decode image - originalImage is null');
      throw Exception('Failed to decode image');
    }

    debugPrint('ScreenshotManager: Original image size: ${originalImage.width}x${originalImage.height}');

    // Calculate the crop rectangle in image coordinates
    final int x = (region.left * originalImage.width).round();
    final int y = (region.top * originalImage.height).round();
    final int width = ((region.right - region.left) * originalImage.width).round();
    final int height = ((region.bottom - region.top) * originalImage.height).round();

    debugPrint('ScreenshotManager: Calculated crop coords - x:$x, y:$y, width:$width, height:$height');

    // Ensure bounds are within image
    final int safeX = x.clamp(0, originalImage.width - 1);
    final int safeY = y.clamp(0, originalImage.height - 1);
    final int safeWidth = width.clamp(1, originalImage.width - safeX);
    final int safeHeight = height.clamp(1, originalImage.height - safeY);

    debugPrint('ScreenshotManager: Safe crop coords - x:$safeX, y:$safeY, width:$safeWidth, height:$safeHeight');

    // Crop the image
    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: safeX,
      y: safeY,
      width: safeWidth,
      height: safeHeight,
    );

    debugPrint('ScreenshotManager: Cropped image created, size: ${croppedImage.width}x${croppedImage.height}');

    // Encode back to bytes
    final result = Uint8List.fromList(img.encodePng(croppedImage));
    debugPrint('ScreenshotManager: PNG encoded, size: ${result.length}');

    return result;
  }

  Future<String?> saveScreenshot() async {
    if (_currentScreenshot == null) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final screenshotsDir = Directory(path.join(directory.path, 'screenshots'));

      // Create screenshots directory if it doesn't exist
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = _currentScreenshot!.timestamp;
      final filename = 'screenshot_${timestamp.millisecondsSinceEpoch}.png';
      final filePath = path.join(screenshotsDir.path, filename);

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(_currentScreenshot!.imageData);

      // Update the screenshot data with the file path
      _currentScreenshot = _currentScreenshot!.copyWith(filePath: filePath);

      return filePath;
    } catch (e) {
      debugPrint('Error saving screenshot: $e');
      return null;
    }
  }

  void deleteScreenshot() {
    _currentScreenshot = null;
    _mode = ScreenshotMode.idle;
    onScreenshotCleared?.call();
  }

  ScreenshotData? getCurrentScreenshot() {
    return _currentScreenshot;
  }

  // Get screenshot as base64 for AI chat
  String? getScreenshotAsBase64() {
    if (_currentScreenshot == null) return null;
    return 'data:image/png;base64,${base64Encode(_currentScreenshot!.imageData)}';
  }

}
