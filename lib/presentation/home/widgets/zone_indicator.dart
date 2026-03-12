import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_strings.dart';
import '../../../../data/storage/settings_storage.dart';
import '../../../../domain/models/hr_zones.dart';

class ZoneIndicator extends StatelessWidget {
  const ZoneIndicator({
    super.key,
    required this.heartRate,
    this.zones,
    required this.color,
    this.gradientPhase = 0,
    this.useGradient = false,
  });

  final int? heartRate;
  final HrZones? zones;
  final Color color;
  final double gradientPhase;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    if (heartRate == null || zones == null) {
      return const SizedBox.shrink();
    }

    final zone = zones!.zoneFor(heartRate!);

    if (zone == null) return const SizedBox.shrink();

    final percentMin = (zone.minPercent * 100).round();
    final percentMax = (zone.maxPercent * 100).round();
    final zoneName = AppStrings.zoneName(languageCode, zone.type);
    final bpmLabel = AppStrings.isRu(languageCode) ? 'уд/мин' : 'bpm';
    final text = Text(
      '$zoneName (${zone.minBpm}-${zone.maxBpm} $bpmLabel, $percentMin-$percentMax%)',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    );
    if (!useGradient) {
      return Text(
        '$zoneName (${zone.minBpm}-${zone.maxBpm} $bpmLabel, $percentMin-$percentMax%)',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1 + gradientPhase * 2, -1),
        end: Alignment(1 + gradientPhase * 2, 1),
        colors: const [
          Color(0xFF7F7FD5),
          Color(0xFF86A8E7),
          Color(0xFF91EAE4),
          Color(0xFFE0C3FC),
        ],
      ).createShader(bounds),
      child: text,
    );
  }
}
