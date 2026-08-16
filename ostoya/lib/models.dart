class Sound {
  String soundId;

  new(this.soundId);
}

abstract class TimerNode {
  String? get label;

  List<Timer> flatten();
}

class Timer implements TimerNode {
  @override
  final String label;
  Duration duration;
  Sound sound;

  new(this.label, this.duration, this.sound);

  @override
  List<Timer> flatten() {
    return [this];
  }
}

class TimerGroup implements TimerNode {
  @override
  final String? label;
  final int loopCount;
  final List<TimerNode> children;

  TimerGroup({required this.children, this.loopCount = 1, this.label});

  @override
  List<Timer> flatten() {
    final flattenedList = <Timer>[];

    for (int i = 0; i < loopCount; i++) {
      for (final child in children) {
        flattenedList.addAll(child.flatten());
      }
    }

    return flattenedList;
  }
}

class Plan {
  final String label;
  final TimerGroup rootGroup;

  new(this.label, this.rootGroup);

  List<Timer> generateTimeline() {
    return rootGroup.flatten();
  }
}
