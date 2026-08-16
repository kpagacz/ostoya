import 'dart:async';
import 'package:clock/clock.dart';

import 'package:ostoya/models.dart';

abstract class Event {}

class ScheduleWakeUpEvent implements Event {
  final DateTime endTime;
  ScheduleWakeUpEvent(this.endTime);
}

class PlaySoundEvent implements Event {
  final Sound sound;
  PlaySoundEvent(this.sound);
}

class PlanCompletedEvent implements Event {}

class CancelWakeUpEvent implements Event {}

enum EngineStatus { idle, running, paused, finished }

class TimerEngine {
  final Plan plan;
  final List<Timer> timeline;

  int currentIndex = 0;
  DateTime? currentTimerEndTime;
  Duration? pausedRemainingDuration;
  EngineStatus engineStatus = EngineStatus.idle;

  final _eventController = StreamController<Event>.broadcast();
  Stream<Event> get eventStream => _eventController.stream;

  TimerEngine(this.plan) : timeline = plan.generateTimeline();

  bool get isCompleted => engineStatus == EngineStatus.finished;
  bool get isRunning => engineStatus == EngineStatus.running;
  bool get isPaused => engineStatus == EngineStatus.paused;
  bool get isIdle => engineStatus == EngineStatus.idle;

  Timer? get currentTimer =>
      (currentIndex >= 0 && currentIndex < timeline.length)
          ? timeline[currentIndex]
          : null;

  Duration calculateRemainingTime([DateTime? now]) {
    final currentTime = now ?? clock.now();
    switch (engineStatus) {
      case EngineStatus.idle:
        if (timeline.isNotEmpty && currentIndex < timeline.length) {
          return timeline[currentIndex].duration;
        }
        return Duration.zero;
      case EngineStatus.running:
        if (currentTimerEndTime == null) return Duration.zero;
        final remaining = currentTimerEndTime!.difference(currentTime);
        return remaining.isNegative ? Duration.zero : remaining;
      case EngineStatus.paused:
        return pausedRemainingDuration ?? Duration.zero;
      case EngineStatus.finished:
        return Duration.zero;
    }
  }

  Duration get remainingTime => calculateRemainingTime();

  Duration calculateTotalRemainingTime([DateTime? now]) {
    if (engineStatus == EngineStatus.finished || currentIndex >= timeline.length) {
      return Duration.zero;
    }
    final currentRem = calculateRemainingTime(now);
    final futureTotal = timeline
        .skip(currentIndex + 1)
        .fold<Duration>(Duration.zero, (prev, t) => prev + t.duration);
    return currentRem + futureTotal;
  }

  void start() {
    if (engineStatus != EngineStatus.idle || timeline.isEmpty) return;

    engineStatus = EngineStatus.running;
    currentTimerEndTime = clock.now().add(timeline[currentIndex].duration);
    emitEvent(ScheduleWakeUpEvent(currentTimerEndTime!));
  }

  void processWakeUp(DateTime now) {
    if (engineStatus != EngineStatus.running) return;

    while (currentIndex < timeline.length &&
        !currentTimerEndTime!.isAfter(now)) {
      final finishedTimer = timeline[currentIndex];
      emitEvent(PlaySoundEvent(finishedTimer.sound));

      currentIndex++;
      if (currentIndex >= timeline.length) {
        engineStatus = EngineStatus.finished;
        emitEvent(PlanCompletedEvent());
        return;
      }

      final nextTimer = timeline[currentIndex];
      currentTimerEndTime = currentTimerEndTime!.add(nextTimer.duration);
    }

    if (engineStatus == EngineStatus.running) {
      emitEvent(ScheduleWakeUpEvent(currentTimerEndTime!));
    }
  }

  void pause(DateTime now) {
    if (engineStatus != EngineStatus.running) return;
    pausedRemainingDuration = currentTimerEndTime!.difference(now);
    engineStatus = EngineStatus.paused;
    emitEvent(CancelWakeUpEvent());
  }

  void resume(DateTime now) {
    if (engineStatus != EngineStatus.paused) return;
    currentTimerEndTime = now.add(pausedRemainingDuration!);
    engineStatus = EngineStatus.running;
    emitEvent(ScheduleWakeUpEvent(currentTimerEndTime!));
  }

  void emitEvent(Event event) {
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }
}
