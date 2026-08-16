import 'dart:async' as async;

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostoya/providers.dart';
import 'package:ostoya/services.dart';

// 1. We create Fakes for our services.
// The Audio fake just records what sounds were played.
class FakeAudioService implements AudioService {
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

// 2. The Alarm fake is the secret sauce for fake_async!
// By using a standard Dart Timer, fake_async will automatically track it.
// When fakeAsync fast-forwards time, this timer will fire exactly as expected.
class FakeAlarmService implements AlarmService {
  @override
  final void Function(DateTime) onWakeUp;
  async.Timer? _timer;

  FakeAlarmService({required this.onWakeUp});

  @override
  void scheduleExactWakeUp(DateTime time) {
    _timer?.cancel();
    final delay = time.difference(clock.now());
    // Schedule a Dart timer. fake_async intercepts this!
    _timer = async.Timer(delay, () => onWakeUp(time));
  }

  @override
  void cancelWakeUp() {
    _timer?.cancel();
  }
}

void main() {
  group('TimerController (Riverpod + FakeAsync)', () {
    test('Counts down perfectly and fires alarms simulating the OS', () {
      // Wrap the whole test in fakeAsync to hijack the clock
      fakeAsync((async) {
        final audioFake = FakeAudioService();
        late ProviderContainer container;

        // Set up our fake OS Alarm Service
        final alarmFake = FakeAlarmService(
          onWakeUp: (scheduledTime) {
            // When the OS alarm fires, it calls the controller!
            container
                .read(timerControllerProvider.notifier)
                .processWakeUp(scheduledTime);
          },
        );

        container = ProviderContainer(
          overrides: [
            audioServiceProvider.overrideWithValue(audioFake),
            alarmServiceProvider.overrideWithValue(alarmFake),
          ],
        );

        final controller = container.read(timerControllerProvider.notifier);

        // Ensure side effects are listening!
        container.read(timerSideEffectCoordinatorProvider);

        // 1. Initial State Check
        var state = container.read(timerControllerProvider);
        expect(state.status, TimerStatus.idle);

        // The dummy plan has a 10s prep, 5m main, 30s cooldown.
        // Total = 10s + 300s + 30s = 340 seconds
        expect(state.totalRemainingTime.inSeconds, 340);
        expect(state.remainingTime.inSeconds, 10);

        // 2. Start the Timer
        controller.start();
        state = container.read(timerControllerProvider);
        expect(state.status, TimerStatus.running);

        // 3. We are currently in the first timer ('Preparation')
        state = container.read(timerControllerProvider);
        expect(state.currentTimerLabel, 'Preparation');

        // Fast-forward 10 seconds to finish 'Preparation'
        async.elapse(const Duration(seconds: 10));

        // The mock alarm fired! It woke the controller, played the bell, and advanced the state.
        state = container.read(timerControllerProvider);
        expect(state.currentTimerLabel, 'Main Meditation');
        expect(audioFake.playedSounds.length, 1);
        expect(audioFake.playedSounds.last, 'bell');

        // 4. We are now in 'Main Meditation' (5 minutes). Let's pause halfway.
        async.elapse(const Duration(minutes: 2, seconds: 30));
        controller.pause();

        state = container.read(timerControllerProvider);
        expect(state.status, TimerStatus.paused);
        expect(state.currentTimerLabel, 'Main Meditation');
        expect(state.remainingTime.inSeconds, 150); // 2m 30s remaining

        // Wait an hour in real life...
        async.elapse(const Duration(hours: 1));

        // Resume
        controller.resume();

        // 5. Fast-forward the remaining 2m 30s of 'Main Meditation'
        async.elapse(const Duration(minutes: 2, seconds: 30));

        // The mock alarm fired! We are now in 'Cool Down' (30s)
        state = container.read(timerControllerProvider);
        expect(state.currentTimerLabel, 'Cool Down');
        expect(audioFake.playedSounds.length, 2);
        expect(audioFake.playedSounds.last, 'chime');

        // 6. Fast-forward the final 30 seconds of 'Cool Down'
        async.elapse(const Duration(seconds: 30));

        // Plan Completed!
        state = container.read(timerControllerProvider);
        expect(state.status, TimerStatus.completed);
        expect(state.remainingTime, Duration.zero);
        expect(state.totalRemainingTime, Duration.zero);

        // Ensure all audio played correctly
        expect(audioFake.playedSounds.length, 3);
        expect(audioFake.playedSounds, ['bell', 'chime', 'bell']);
        expect(audioFake.chimePlayed, true);
      });
    });
  });
}
