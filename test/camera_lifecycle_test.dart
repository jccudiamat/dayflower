import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/tulip/domain/camera_lifecycle.dart';

/// Opening the gallery sends the app to the background and brings it back.
/// For a month that round trip killed the viewfinder permanently, because
/// the resume half was skipped whenever there was no controller — and the
/// pause half is what removed the controller.

void main() {
  test('leaving the app hands the camera back', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      expect(cameraActionFor(state), CameraLifecycleAction.close,
          reason: '$state must release the sensor');
    }
  });

  test('coming back takes it again', () {
    expect(cameraActionFor(AppLifecycleState.resumed),
        CameraLifecycleAction.open);
  });

  test('a whole gallery trip ends with the camera open', () {
    // 🔴 The regression, spelled out as the sequence that produced it:
    // inactive → paused while the picker is up, resumed on the way back.
    // The old code returned early on that last one and left the viewfinder
    // on a spinner it never came off, with the shutter falling through to
    // the phone's own camera app.
    const trip = [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.resumed,
    ];
    expect(trip.map(cameraActionFor).last, CameraLifecycleAction.open);
  });

  test('the decision uses the lifecycle state and nothing else', () {
    // Same input, same answer, every time — no controller, no flag, no
    // "did we already close it". Every version of this bug has been some
    // piece of state making one of these two answers conditional.
    for (final state in AppLifecycleState.values) {
      expect(cameraActionFor(state), cameraActionFor(state));
    }
    expect(AppLifecycleState.values.map(cameraActionFor).toSet().length, 2);
  });
}
