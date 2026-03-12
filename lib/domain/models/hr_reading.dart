import 'package:equatable/equatable.dart';

/// Одно показание пульса
class HrReading extends Equatable {
  const HrReading({
    required this.timestamp,
    required this.heartRate,
  });

  final DateTime timestamp;
  final int heartRate;

  HrReading copyWith({
    DateTime? timestamp,
    int? heartRate,
  }) {
    return HrReading(
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
    );
  }

  Map<String, dynamic> toJson() => {
        't': timestamp.millisecondsSinceEpoch,
        'hr': heartRate,
      };

  factory HrReading.fromJson(Map<String, dynamic> json) => HrReading(
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
        heartRate: json['hr'] as int,
      );

  @override
  List<Object?> get props => [timestamp, heartRate];
}
