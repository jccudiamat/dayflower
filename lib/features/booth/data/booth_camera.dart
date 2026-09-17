import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

final boothCameraProvider =
    Provider<BoothCamera Function()>((ref) => NativeBoothCamera.new);

/// The same contract drives the device camera and the offline review harness.
abstract class BoothCamera extends ChangeNotifier {
  bool get ready;
  bool get canFlip;
  String? get error;
  Widget preview();
  Future<void> open();
  Future<void> close();
  Future<void> flip();
  Future<Uint8List> capture();
}

class NativeBoothCamera extends BoothCamera {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _lens = CameraLensDirection.front;
  int _generation = 0;
  bool _disposed = false;
  String? _error;
  Future<void> _operations = Future.value();
  @override
  bool get ready => _controller?.value.isInitialized == true;
  @override
  bool get canFlip => _cameras.map((c) => c.lensDirection).toSet().length > 1;
  @override
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _queue(Future<void> Function() op) =>
      _operations = _operations.then((_) => op()).catchError((_) {});

  @override
  Future<void> open() {
    final generation = ++_generation;
    return _queue(() async {
      if (_disposed || generation != _generation) return;
      CameraController? camera;
      try {
        await _controller?.dispose();
        _controller = null;
        _error = null;
        _notify();
        _cameras = await availableCameras();
        if (_cameras.isEmpty) throw StateError('No camera');
        final description = _cameras.firstWhere((c) => c.lensDirection == _lens,
            orElse: () => _cameras.first);
        camera = CameraController(description, ResolutionPreset.high,
            enableAudio: false);
        await camera.initialize();
        if (_disposed || generation != _generation) {
          await camera.dispose();
          return;
        }
        _controller = camera;
        _lens = description.lensDirection;
        _notify();
      } catch (_) {
        await camera?.dispose();
        if (!_disposed && generation == _generation) {
          _error =
              'Camera unavailable. Allow camera access in Settings, or upload photos.';
          _notify();
        }
      }
    });
  }

  @override
  Future<void> close() {
    _generation++;
    final old = _controller;
    _controller = null;
    _notify();
    return _queue(() async => old?.dispose());
  }

  @override
  Future<void> flip() async {
    if (!canFlip) return;
    _lens = _lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await close();
    await open();
  }

  @override
  Widget preview() {
    final camera = _controller;
    if (camera == null || !ready) return const SizedBox.expand();
    return ValueListenableBuilder<CameraValue>(
        valueListenable: camera,
        builder: (context, value, _) {
          final orientation =
              value.lockedCaptureOrientation ?? value.deviceOrientation;
          final portrait = orientation == DeviceOrientation.portraitUp ||
              orientation == DeviceOrientation.portraitDown;
          final size = value.previewSize!;
          return ClipRect(
              child: SizedBox.expand(
                  child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                          width: portrait ? size.height : size.width,
                          height: portrait ? size.width : size.height,
                          child: CameraPreview(camera)))));
        });
  }

  @override
  Future<Uint8List> capture() async {
    final camera = _controller;
    final generation = _generation;
    if (camera == null || !ready) throw StateError('Camera is not ready');
    final file = await camera.takePicture();
    final bytes = await file.readAsBytes();
    if (_disposed || generation != _generation) {
      throw StateError('Capture cancelled');
    }
    return compute(_normalize, (bytes, _lens == CameraLensDirection.front));
  }

  @override
  void dispose() {
    _disposed = true;
    close();
    super.dispose();
  }
}

Uint8List _normalize((Uint8List, bool) input) {
  final decoded = img.decodeImage(input.$1);
  if (decoded == null) throw const FormatException('Could not read the shot');
  var photo = img.bakeOrientation(decoded);
  if (input.$2) photo = img.flipHorizontal(photo);
  return Uint8List.fromList(img.encodeJpg(photo, quality: 92));
}
