import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:ostoya/views/meditation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterForegroundTask.requestNotificationPermission();

  runApp(const ProviderScope(child: OstoyaApp()));
}

class OstoyaApp extends StatelessWidget {
  const OstoyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ostoya Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MeditationScreen(),
    );
  }
}
