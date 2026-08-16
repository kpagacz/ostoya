import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostoya/engine.dart';
import 'package:ostoya/models.dart';

void main() {
  group('TimerEngine', () {
    late Sound s1;
    late Sound s2;
    late Timer t1;
    late Timer t2;
    late TimerGroup rootGroup;
    late Plan plan;

    setUp(() {
      s1 = Sound('sound1');
      s2 = Sound('sound2');
      // 10 second timer
      t1 = Timer('t1', const Duration(seconds: 10), s1);
      // 5 second timer
      t2 = Timer('t2', const Duration(seconds: 5), s2);

      // Group with 2 loops: (t1, t2) * 2
      rootGroup = TimerGroup(children: [t1, t2], loopCount: 2);
      plan = Plan('Test Plan', rootGroup);
    });

    test('timeline flattens correctly', () {
      final engine = TimerEngine(plan);
      expect(engine.timeline.length, 4);
      expect(engine.timeline[0].label, 't1');
      expect(engine.timeline[1].label, 't2');
      expect(engine.timeline[2].label, 't1');
      expect(engine.timeline[3].label, 't2');
    });

    test('start() calculates first wake up', () async {
      final engine = TimerEngine(plan);
      final queue = StreamQueue(engine.eventStream);

      engine.start();
      expect(engine.engineStatus, EngineStatus.running);

      final scheduleEvent = await queue.next as ScheduleWakeUpEvent;
      // Should be roughly 10 seconds from now
      final diff = scheduleEvent.endTime.difference(DateTime.now());
      expect(diff.inSeconds, closeTo(10, 1));
    });

    test('processWakeUp() handles sequential events and finishes', () async {
      final engine = TimerEngine(plan);
      final queue = StreamQueue(engine.eventStream);

      engine.start();
      await queue.next; // Consume the start event

      final startTime = DateTime.now();

      // 1. Wake up after 10s (first timer finishes)
      final t1End = startTime.add(const Duration(seconds: 10));
      engine.processWakeUp(t1End);

      final soundEvent1 = await queue.next as PlaySoundEvent;
      expect(soundEvent1.sound.soundId, 'sound1');
      expect(await queue.next, isA<ScheduleWakeUpEvent>());

      // 2. Wake up after another 5s (second timer finishes)
      final t2End = t1End.add(const Duration(seconds: 5));
      engine.processWakeUp(t2End);

      final soundEvent2 = await queue.next as PlaySoundEvent;
      expect(soundEvent2.sound.soundId, 'sound2');
      expect(await queue.next, isA<ScheduleWakeUpEvent>());

      // 3. Fast forward remaining 15s in one batch (simulating device sleep)
      final endOfPlan = t2End.add(const Duration(seconds: 15));
      engine.processWakeUp(endOfPlan);

      // Should emit 2 sounds and 1 finish event
      expect(await queue.next, isA<PlaySoundEvent>());
      expect(await queue.next, isA<PlaySoundEvent>());
      expect(await queue.next, isA<PlanCompletedEvent>());
      expect(engine.engineStatus, EngineStatus.finished);
    });

    test('pause and resume correctly shift the end time', () async {
      final engine = TimerEngine(plan);
      final queue = StreamQueue(engine.eventStream);

      engine.start();
      await queue.next; // Consume the start event

      final startTime = DateTime.now();

      // Pause exactly 4 seconds in
      final pauseTime = startTime.add(const Duration(seconds: 4));
      engine.pause(pauseTime);

      expect(engine.engineStatus, EngineStatus.paused);
      expect(await queue.next, isA<CancelWakeUpEvent>());

      // Resume 10 seconds later
      final resumeTime = pauseTime.add(const Duration(seconds: 10));
      engine.resume(resumeTime);

      expect(engine.engineStatus, EngineStatus.running);

      final scheduleEvent = await queue.next as ScheduleWakeUpEvent;
      final diff = scheduleEvent.endTime.difference(resumeTime);
      expect(diff.inMilliseconds, closeTo(6000, 100)); // 6 seconds +/- 100ms
    });
  });
}
