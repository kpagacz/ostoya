import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ostoya/providers.dart';

class MeditationScreen extends ConsumerWidget {
  const MeditationScreen({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the side effect coordinator alive!
    ref.watch(timerSideEffectCoordinatorProvider);

    final timerState = ref.watch(timerControllerProvider);
    final isRunning = timerState.status == TimerStatus.running;
    final isCompleted = timerState.status == TimerStatus.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('Meditation Timer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isCompleted ? 'Done!' : _formatDuration(timerState.remainingTime),
              style: Theme.of(context).textTheme.displayLarge
                  ?.copyWith(fontSize: 80, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Remaining: ${_formatDuration(timerState.totalRemainingTime)}',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  onPressed: () {
                    final controller = ref.read(
                      timerControllerProvider.notifier,
                    );
                    if (isRunning) {
                      controller.pause();
                    } else if (timerState.status == TimerStatus.paused) {
                      controller.resume();
                    } else {
                      controller.start();
                    }
                  },
                  child: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
