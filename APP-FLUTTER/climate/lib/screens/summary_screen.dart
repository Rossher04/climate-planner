import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../themes/app_colors.dart';
import '../widgets/metric_tile.dart';
import '../widgets/score_ring.dart';
import '../widgets/section_title.dart';
import '../widgets/surface_box.dart';

class SummaryView extends StatelessWidget {
  const SummaryView({super.key, required this.activities});

  final List<Activity> activities;

  Activity? get _nextActivity {
    final now = DateTime.now();
    Activity? next;
    DateTime? nextDate;
    for (final a in activities) {
      final parts = a.date.split('/');
      if (parts.length != 3) continue;
      final d = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
      if (d == null) continue;
      if (d.isBefore(now) && !d.isAtSameMomentAs(now)) continue;
      if (nextDate == null || d.isBefore(nextDate)) {
        nextDate = d;
        next = a;
      }
    }
    return next ?? (activities.isNotEmpty ? activities.first : null);
  }

  int get _avgRain {
    if (activities.isEmpty) return 0;
    return (activities.map((a) => a.rainProbability).reduce((a, b) => a + b) / activities.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextActivity;
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Actividades',
                value: '${activities.length}',
                color: AppColors.blue,
                icon: Icons.task_alt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Lluvia promedio',
                value: '$_avgRain%',
                color: AppColors.coral,
                icon: Icons.water_drop_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (next != null) ...[
          SurfaceBox(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Overline('Actividad próxima'),
                      const SizedBox(height: 6),
                      Text(
                        next.title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${next.location} - ${next.date} - ${next.time}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ScoreRing(score: next.score),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
