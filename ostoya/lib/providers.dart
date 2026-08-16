import 'dart:async' as async;
import 'dart:io' show Platform;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ostoya/engine.dart';
import 'package:ostoya/models.dart';
import 'package:ostoya/services.dart';

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final alarmServiceProvider = Provider<AlarmService>((ref) {
  return AlarmService(
    onWakeUp: (time) {
      ref.read(timerControllerProvider.notifier).processWakeUp(time);
    },
  );
});

final keepAliveServiceProvider = Provider<KeepAliveService>((ref) {
  if (Platform.isAndroid) {
    return AndroidForegroundService();
  }
  return DesktopNoOpService();
});

Plan createDummyPlan() {
  final bellSound = Sound('bell');
  final chimeSound = Sound('chime');
  return Plan(
    'Meditation Session',
    TimerGroup(
      children: [
        Timer('Preparation', const Duration(seconds: 10), bellSound),
        Timer('Main Meditation', const Duration(minutes: 5), chimeSound),
        Timer('Cool Down', const Duration(seconds: 30), bellSound),
      ],
    ),
  );
}

final timerEngineProvider = Provider<TimerEngine>((ref) {
  final engine = TimerEngine(createDummyPlan());
  ref.onDispose(() => engine.dispose());
  return engine;
});

final timerSideEffectCoordinatorProvider = Provider<void>((ref) {
  final engine = ref.watch(timerEngineProvider);
  final audioService = ref.watch(audioServiceProvider);
  final alarmService = ref.watch(alarmServiceProvider);

  final subscription = engine.eventStream.listen((event) {
    switch (event) {
      case PlaySoundEvent(:final sound):
        audioService.playSound(sound.soundId);
      case ScheduleWakeUpEvent(:final endTime):
        alarmService.scheduleExactWakeUp(endTime);
      case CancelWakeUpEvent():
        alarmService.cancelWakeUp();
      case PlanCompletedEvent():
        alarmService.cancelWakeUp();
        audioService.playCompletionChime();
      default:
        break;
    }
  });

  ref.onDispose(() => subscription.cancel());
});

enum TimerStatus { idle, running, paused, completed }

class TimerUiState {
  final TimerStatus status;
  final Duration remainingTime;
  final Duration totalRemainingTime;
  final String? currentTimerLabel;

  const TimerUiState({
    required this.status,
    required this.remainingTime,
    this.totalRemainingTime = Duration.zero,
    this.currentTimerLabel,
  });

  TimerUiState copyWith({
    TimerStatus? status,
    Duration? remainingTime,
    Duration? totalRemainingTime,
    String? currentTimerLabel,
  }) {
    return TimerUiState(
      status: status ?? this.status,
      remainingTime: remainingTime ?? this.remainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      currentTimerLabel: currentTimerLabel ?? this.currentTimerLabel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerUiState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          remainingTime == other.remainingTime &&
          totalRemainingTime == other.totalRemainingTime &&
          currentTimerLabel == other.currentTimerLabel;

  @override
  int get hashCode =>
      status.hashCode ^
      remainingTime.hashCode ^
      totalRemainingTime.hashCode ^
      (currentTimerLabel?.hashCode ?? 0);
}

class TimerController extends Notifier<TimerUiState> {
  async.Timer? _uiTicker;

  TimerEngine get _engine => ref.read(timerEngineProvider);

  @override
  TimerUiState build() {
    ref.onDispose(() => _uiTicker?.cancel());

    final engine = ref.read(timerEngineProvider);
    return TimerUiState(
      status: _mapEngineStatus(engine.engineStatus),
      remainingTime: engine.remainingTime,
      totalRemainingTime: engine.calculateTotalRemainingTime(),
      currentTimerLabel: engine.currentTimer?.label,
    );
  }

  void start() {
    _engine.start();
    _startTicker();
    _syncStateWithEngine();
    _notifyKeepAlive();
  }

  void pause() {
    final now = clock.now();
    _engine.pause(now);
    _uiTicker?.cancel();
    _syncStateWithEngine();
    ref.read(keepAliveServiceProvider).stopRunning();
  }

  void resume() {
    final now = clock.now();
    _engine.resume(now);
    _startTicker();
    _syncStateWithEngine();
    _notifyKeepAlive();
  }

  void processWakeUp([DateTime? now]) {
    final currentTime = now ?? clock.now();
    _engine.processWakeUp(currentTime);
    _syncStateWithEngine();
    _notifyKeepAlive();
  }

  void _startTicker() {
    _uiTicker?.cancel();
    _uiTicker = async.Timer.periodic(const Duration(seconds: 1), (_) {
      _syncStateWithEngine();
    });
  }

  void _syncStateWithEngine() {
    state = state.copyWith(
      status: _mapEngineStatus(_engine.engineStatus),
      remainingTime: _engine.remainingTime,
      totalRemainingTime: _engine.calculateTotalRemainingTime(),
      currentTimerLabel: _engine.currentTimer?.label,
    );
    if (_engine.isCompleted) {
      _uiTicker?.cancel();
      ref.read(keepAliveServiceProvider).stopRunning();
    } else if (_engine.isRunning) {
      ref.read(keepAliveServiceProvider).updateTick(_formatDuration(_engine.remainingTime));
    }
  }

  void _notifyKeepAlive() {
    if (_engine.isRunning && _engine.currentTimer != null) {
      ref.read(keepAliveServiceProvider).startRunning(
            _engine.currentTimer!.label,
            _formatDuration(_engine.remainingTime),
          );
    }
  }

  static String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static TimerStatus _mapEngineStatus(EngineStatus engineStatus) {
    switch (engineStatus) {
      case EngineStatus.idle:
        return TimerStatus.idle;
      case EngineStatus.running:
        return TimerStatus.running;
      case EngineStatus.paused:
        return TimerStatus.paused;
      case EngineStatus.finished:
        return TimerStatus.completed;
    }
  }
}

final timerControllerProvider = NotifierProvider<TimerController, TimerUiState>(
  TimerController.new,
);
