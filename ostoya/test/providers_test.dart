import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostoya/engine.dart';
import 'package:ostoya/providers.dart';
import 'package:ostoya/services.dart';

class MockAudioService extends AudioService {
  final List<String> playedSounds = [];
  bool chimePlayed = false;

  @override
  void playSound(String id) {
    playedSounds.add(id);
  }

  @override
  void playCompletionChime() {
    chimePlayed = true;
  }
}

class MockAlarmService implements AlarmService {
  @override
  final void Function(DateTime) onWakeUp;

  MockAlarmService({this.onWakeUp = _defaultOnWakeUp});
  
  static void _defaultOnWakeUp(DateTime t) {}

  final List<DateTime> wakeUps = [];
  int cancelCount = 0;

  @override
  void scheduleExactWakeUp(DateTime time) {
    wakeUps.add(time);
  }

  @override
  void cancelWakeUp() {
    cancelCount++;
  }
}

void main() {
  group('Riverpod Providers & TimerController', () {
    late MockAudioService mockAudio;
    late MockAlarmService mockAlarm;
    late ProviderContainer container;

    setUp(() {
      mockAudio = MockAudioService();
      mockAlarm = MockAlarmService();

      container = ProviderContainer(
        overrides: [
          audioServiceProvider.overrideWithValue(mockAudio),
          alarmServiceProvider.overrideWithValue(mockAlarm),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle with correct durations', () {
      final state = container.read(timerControllerProvider);
      expect(state.status, TimerStatus.idle);
      expect(state.currentTimerLabel, 'Preparation');
      expect(state.remainingTime, const Duration(seconds: 10));
    });

    test(
      'start transitions to running and triggers wake up schedule',
      () async {
        final controller = container.read(timerControllerProvider.notifier);
        controller.start();
        await pumpEventQueue();

        final state = container.read(timerControllerProvider);
        expect(state.status, TimerStatus.running);
        expect(mockAlarm.wakeUps.length, 1);
      },
    );

    test('pause and resume correctly update state and side effects', () async {
      final controller = container.read(timerControllerProvider.notifier);
      controller.start();
      await pumpEventQueue();

      controller.pause();
      await pumpEventQueue();
      var state = container.read(timerControllerProvider);
      expect(state.status, TimerStatus.paused);
      expect(mockAlarm.cancelCount, 1);

      controller.resume();
      await pumpEventQueue();
      state = container.read(timerControllerProvider);
      expect(state.status, TimerStatus.running);
      expect(mockAlarm.wakeUps.length, 2);
    });

    test('processWakeUp plays sounds and reaches completion', () async {
      final controller = container.read(timerControllerProvider.notifier);
      controller.start();
      await pumpEventQueue();

      final engine = container.read(timerEngineProvider);
      // Fast forward past all timers
      final farFuture = DateTime.now().add(const Duration(hours: 1));
      controller.processWakeUp(farFuture);
      await pumpEventQueue();

      final state = container.read(timerControllerProvider);
      expect(state.status, TimerStatus.completed);
      expect(engine.engineStatus, EngineStatus.finished);
      expect(mockAudio.playedSounds.length, 3);
      expect(mockAudio.chimePlayed, isTrue);
    });
  });
}
