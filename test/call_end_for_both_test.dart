import 'dart:async';

import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/calls/data/call_repository.dart';
import 'package:dayflower/features/calls/data/call_transport.dart';
import 'package:dayflower/features/calls/domain/call.dart';
import 'package:dayflower/features/calls/domain/call_notifier.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A call is for two: when it ends it is over for both, nobody goes back
/// in, and a call nobody answered reads as missed, whoever closed it.
class _Calls extends CallRepository {
  _Calls() : super(SupabaseClient('http://localhost', 'test-key'));

  final ended = <String>[];
  final missed = <String>[];

  @override
  Future<void> end(String messageId) async => ended.add(messageId);

  @override
  Future<void> missCall(String messageId) async => missed.add(messageId);
}

void main() {
  late StreamController<List<FlowerMessage>> rows;
  late _Calls calls;
  late ProviderContainer container;

  FlowerMessage call({DateTime? endedAt}) => FlowerMessage(
        id: 'call-1',
        pairId: '11111111-1111-1111-1111-111111111111',
        senderId: 'them',
        sentAt: DateTime.now().subtract(const Duration(seconds: 20)),
        callMode: 'video',
        callEndedAt: endedAt,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rows = StreamController<List<FlowerMessage>>.broadcast();
    calls = _Calls();
    container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      callRepositoryProvider.overrideWithValue(calls),
      callTransportProvider.overrideWithValue(UnconfiguredCallTransport()),
      flowerMessagesProvider.overrideWith((ref) => rows.stream),
    ]);
  });

  tearDown(() {
    container.dispose();
    rows.close();
  });

  CallNotifier notifier() => container.read(callNotifierProvider.notifier);
  CallSession? session() => container.read(callNotifierProvider);

  test('hanging up on a call nobody answered marks it missed', () async {
    // Rang, never answered: no startedAt. The caller cancelling used to
    // stamp now(), and the thread showed the ringing as a duration.
    notifier().ring(call());
    await notifier().hangUp();
    expect(calls.missed, ['call-1']);
    expect(calls.ended, isEmpty);
    expect(session(), isNull);
  });

  test('declining from the notification with no session still closes it',
      () async {
    // The app was closed: nothing on screen, nothing in memory.
    expect(session(), isNull);
    await notifier().declineCall('call-1');
    expect(calls.missed, ['call-1'], reason: 'the caller stops ringing');
  });

  test('the other side closing the call ends it here too', () async {
    // Keep the stream listened, as the app's shell does.
    final keep = container.listen(flowerMessagesProvider, (_, __) {});
    addTearDown(keep.close);
    notifier().ring(call());
    expect(session()?.status, CallStatus.ringing);
    rows.add([call()]);
    await Future<void>.delayed(Duration.zero);
    expect(session(), isNotNull, reason: 'still open, still ringing');

    rows.add([call(endedAt: DateTime.now())]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(session(), isNull, reason: 'gone the moment its row closed');
    expect(calls.ended, isEmpty, reason: 'nothing written: already closed');
    expect(calls.missed, isEmpty);
  });

  test('a call that has ended cannot be joined', () async {
    await notifier().join(call(endedAt: DateTime.now()));
    expect(session()?.status, CallStatus.failed);
    expect(session()?.failure, CallFailure.ended);
  });
}
