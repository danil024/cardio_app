import 'package:equatable/equatable.dart';

enum MetronomeCycleMode { fixed, untilStopped }

enum MetronomePhase { countdown, negative, pause, press, rest, finished }

class MetronomePreset extends Equatable {
  const MetronomePreset({
    required this.id,
    required this.name,
    this.countdownSec = 3,
    this.negativeSec = 3,
    this.pauseSec = 0,
    this.pressSec = 2,
    this.restSec = 2,
    this.cycleMode = MetronomeCycleMode.fixed,
    this.fixedCycles = 8,
  });

  final String id;
  final String name;
  final int countdownSec;
  final int negativeSec;
  final int pauseSec;
  final int pressSec;
  final int restSec;
  final MetronomeCycleMode cycleMode;
  final int fixedCycles;

  MetronomePreset copyWith({
    String? id,
    String? name,
    int? countdownSec,
    int? negativeSec,
    int? pauseSec,
    int? pressSec,
    int? restSec,
    MetronomeCycleMode? cycleMode,
    int? fixedCycles,
  }) {
    return MetronomePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      countdownSec: countdownSec ?? this.countdownSec,
      negativeSec: negativeSec ?? this.negativeSec,
      pauseSec: pauseSec ?? this.pauseSec,
      pressSec: pressSec ?? this.pressSec,
      restSec: restSec ?? this.restSec,
      cycleMode: cycleMode ?? this.cycleMode,
      fixedCycles: fixedCycles ?? this.fixedCycles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'countdownSec': countdownSec,
        'negativeSec': negativeSec,
        'pauseSec': pauseSec,
        'pressSec': pressSec,
        'restSec': restSec,
        'cycleMode': cycleMode == MetronomeCycleMode.fixed ? 'fixed' : 'until',
        'fixedCycles': fixedCycles,
      };

  static MetronomePreset fromJson(Map<String, dynamic> json) {
    final cycleRaw = (json['cycleMode'] as String?) ?? 'fixed';
    return MetronomePreset(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Preset',
      countdownSec: (json['countdownSec'] as num?)?.toInt() ?? 3,
      negativeSec: (json['negativeSec'] as num?)?.toInt() ?? 3,
      pauseSec: (json['pauseSec'] as num?)?.toInt() ?? 0,
      pressSec: (json['pressSec'] as num?)?.toInt() ?? 2,
      restSec: (json['restSec'] as num?)?.toInt() ?? 2,
      cycleMode: cycleRaw == 'until'
          ? MetronomeCycleMode.untilStopped
          : MetronomeCycleMode.fixed,
      fixedCycles: (json['fixedCycles'] as num?)?.toInt() ?? 8,
    );
  }

  int durationForPhase(MetronomePhase phase) {
    switch (phase) {
      case MetronomePhase.countdown:
        return countdownSec;
      case MetronomePhase.negative:
        return negativeSec;
      case MetronomePhase.pause:
        return pauseSec;
      case MetronomePhase.press:
        return pressSec;
      case MetronomePhase.rest:
        return restSec;
      case MetronomePhase.finished:
        return 0;
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        countdownSec,
        negativeSec,
        pauseSec,
        pressSec,
        restSec,
        cycleMode,
        fixedCycles,
      ];
}
