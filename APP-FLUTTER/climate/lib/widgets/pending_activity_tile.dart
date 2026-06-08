import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../themes/app_colors.dart';
import 'status_chip.dart';
import 'surface_box.dart';

class PendingActivityTile extends StatelessWidget {
  const PendingActivityTile(
    this.activity, {
    super.key,
    this.onTap,
    this.onMarkFinished,
    this.onReschedule,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final VoidCallback? onMarkFinished;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(status: activity.status),
                      const SizedBox(height: 8),
                      Text(
                        activity.title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${activity.type} - ${activity.temperature.toStringAsFixed(0)}°C - lluvia ${activity.rainProbability}% - ${activity.weatherSource}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${activity.location} - ${activity.date} - ${activity.time} a ${activity.endTime}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${activity.score}%',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activity.score >= 75
                            ? 'Realizar'
                            : activity.score >= 50
                                ? 'Revisar'
                                : 'Posponer',
                        style: TextStyle(
                          color: activity.score >= 75
                              ? AppColors.green
                              : activity.score >= 50
                                  ? AppColors.gold
                                  : AppColors.coral,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                if (onMarkFinished != null)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onMarkFinished,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Marcar como hecha'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.green),
                    ),
                  ),
                if (onReschedule != null)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onReschedule,
                      icon: const Icon(Icons.event_repeat, size: 18),
                      label: const Text('Reagendar'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.blue),
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
