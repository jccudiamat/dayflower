import 'package:flutter/widgets.dart';

/// What the viewfinder should do when the app changes lifecycle state.
enum CameraLifecycleAction {
  /// Take the sensor.
  open,

  /// Hand it back. A live camera holds hardware other apps want, and
  /// Android will not give it to the gallery picker while we still have it.
  close,
}

/// ⚠️ **This depends on the lifecycle state and nothing else.**
///
/// The bug it exists to prevent: the viewfinder used to skip the whole
/// lifecycle handler when it had no controller —
///
/// ```dart
/// if (_cam == null) return;   // 🔴
/// ```
///
/// — but *pausing is what set the controller to null*. So the guard turned
/// the resume it was paired with into a no-op. Every trip out of the app,
/// which includes opening the gallery picker, handed the camera back on the
/// way out and never took it again on the way in. The viewfinder sat on its
/// spinner, and because the shutter falls back to the OS camera when it has
/// no controller, pressing it opened the phone's camera app instead.
///
/// Anything that reads controller state to decide this is the same bug in a
/// different shape.
CameraLifecycleAction cameraActionFor(AppLifecycleState state) =>
    switch (state) {
      AppLifecycleState.resumed => CameraLifecycleAction.open,
      // `inactive` is included on purpose. It is what arrives first when a
      // picker or a permission dialog comes up, and on iOS it may be the
      // only one that arrives at all.
      AppLifecycleState.inactive ||
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached =>
        CameraLifecycleAction.close,
    };
