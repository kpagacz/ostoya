import 'package:flutter_test/flutter_test.dart';
import 'package:ostoya/engine.dart';
import 'package:ostoya/models.dart';

void main() async {
      final s1 = Sound('sound1');
      final s2 = Sound('sound2');
      final t1 = Timer('t1', const Duration(seconds: 10), s1);
      final t2 = Timer('t2', const Duration(seconds: 5), s2);
      final rootGroup = TimerGroup(children: [t1, t2], loopCount: 2);
      final plan = Plan('Test Plan', rootGroup);

      final engine = TimerEngine(plan);
      final events = <Event>[];
      engine.eventStream.listen(events.add);
      
      engine.start();
      await Future.microtask(() {});
      events.clear();
      
      final startTime = DateTime.now();
      final t1End = startTime.add(const Duration(seconds: 10));
      engine.processWakeUp(t1End);
      await Future.microtask(() {});
      print('Events length: ${events.length}');
      for (var e in events) print(e);
}
