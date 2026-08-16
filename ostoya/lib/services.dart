import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class AudioService {
  void playSound(String id) {
    print('🔊 [AUDIO SERVICE] Playing sound: $id');
  }

  void playCompletionChime() {
    print('🎉 [AUDIO SERVICE] Playing completion chime!');
  }
}

class AlarmService {
  final void Function(DateTime) onWakeUp;
  Timer? _timer;

  AlarmService({required this.onWakeUp});

  void scheduleExactWakeUp(DateTime time) {
    _timer?.cancel();
    final delay = time.difference(DateTime.now());
    
    print('⏰ [ALARM SERVICE] Scheduling local wake-up in ${delay.inSeconds} seconds.');
    
    if (delay.isNegative) {
      onWakeUp(time);
      return;
    }
    
    _timer = Timer(delay, () {
      print('⏰ [ALARM SERVICE] Wake-up timer fired!');
      onWakeUp(time);
    });
  }

  void cancelWakeUp() {
    print('⏰ [ALARM SERVICE] Cancelling wake-up.');
    _timer?.cancel();
  }
}

abstract class KeepAliveService {
  void startRunning(String timerLabel, String remainingTime);
  void updateTick(String remainingTime);
  void stopRunning();
}

class DesktopNoOpService implements KeepAliveService {
  @override
  void startRunning(String timerLabel, String remainingTime) {
    print('🖥️ [DESKTOP] KeepAlive started: $timerLabel ($remainingTime)');
  }

  @override
  void updateTick(String remainingTime) {}

  @override
  void stopRunning() {
    print('🖥️ [DESKTOP] KeepAlive stopped.');
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool fromStop) async {}
}

class AndroidForegroundService implements KeepAliveService {
  bool _isInitialized = false;

  void _init() {
    if (_isInitialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meditation_timer',
        channelName: 'Meditation Timer',
        channelDescription: 'Keeps the meditation timer running',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _isInitialized = true;
  }

  @override
  void startRunning(String timerLabel, String remainingTime) async {
    _init();
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      FlutterForegroundTask.updateService(
        notificationTitle: timerLabel,
        notificationText: remainingTime,
      );
    } else {
      FlutterForegroundTask.startService(
        notificationTitle: timerLabel,
        notificationText: remainingTime,
        callback: startCallback,
      );
    }
  }

  @override
  void updateTick(String remainingTime) async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      FlutterForegroundTask.updateService(
        notificationText: remainingTime,
      );
    }
  }

  @override
  void stopRunning() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      FlutterForegroundTask.stopService();
    }
  }
}
