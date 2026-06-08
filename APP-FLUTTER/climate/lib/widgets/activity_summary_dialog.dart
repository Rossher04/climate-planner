import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../themes/app_colors.dart';
import 'status_chip.dart';

/// Muestra un dialogo con el resumen completo de una actividad usando datos
/// REALES del backend (clima, condiciones y resumen estadistico).
Future<void> showActivitySummary(BuildContext context, Activity activity) {
  return showDialog<void>(
    context: context,
    builder: (_) => ActivitySummaryDialog(activity: activity),
  );
}

class ActivitySummaryDialog extends StatelessWidget {
  const ActivitySummaryDialog({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final stats = activity.statistics;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              activity.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          StatusChip(status: activity.status),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryRow(icon: Icons.category_outlined, label: 'Tipo', value: activity.type),
              _SummaryRow(icon: Icons.place_outlined, label: 'Ubicación', value: activity.location),
              _SummaryRow(icon: Icons.event_outlined, label: 'Fecha', value: activity.date),
              _SummaryRow(
                icon: Icons.schedule_outlined,
                label: 'Horario',
                value: '${activity.time} a ${activity.endTime}',
              ),
              const Divider(height: 22),

              // Clima real registrado para la actividad.
              const _SectionLabel('Clima'),
              _SummaryRow(
                icon: Icons.thermostat_outlined,
                label: 'Temperatura',
                value: '${activity.temperature.toStringAsFixed(1)} C',
              ),
              _SummaryRow(
                icon: Icons.water_drop_outlined,
                label: 'Prob. lluvia',
                value: '${activity.rainProbability}%',
              ),
              _SummaryRow(
                icon: Icons.cloud_outlined,
                label: 'Fuente',
                value: activity.weatherSource,
              ),
              _SummaryRow(
                icon: Icons.verified_outlined,
                label: 'Realización',
                value: '${activity.score}%',
              ),

              if (activity.description.isNotEmpty) ...[
                const Divider(height: 22),
                const _SectionLabel('Descripción'),
                Text(activity.description, style: const TextStyle(color: AppColors.ink)),
              ],

              if (activity.desiredConditions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionLabel('Condiciones deseadas'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final condition in activity.desiredConditions)
                      Chip(
                        label: Text(condition, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.background,
                        side: const BorderSide(color: AppColors.line),
                      ),
                  ],
                ),
              ],

              if (stats != null) ...[
                const Divider(height: 22),
                const _SectionLabel('Estadística (servidor)'),
                _SummaryRow(
                  icon: Icons.timeline_outlined,
                  label: 'Media / Mediana / Moda',
                  value: '${stats.meanTemperature.toStringAsFixed(1)} / '
                      '${stats.medianTemperature.toStringAsFixed(1)} / '
                      '${stats.modeTemperature.toStringAsFixed(1)} C',
                ),
                _SummaryRow(
                  icon: Icons.trending_up_outlined,
                  label: 'Tendencia',
                  value: stats.trendLabel,
                ),
                _SummaryRow(
                  icon: Icons.umbrella_outlined,
                  label: 'Bayes lluvia',
                  value: '${stats.bayesRainProbability.toStringAsFixed(1)}%',
                ),
                _SummaryRow(
                  icon: Icons.recommend_outlined,
                  label: 'Recomendación',
                  value: _recommendationLabel(stats.recommendation),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  String _recommendationLabel(String value) {
    switch (value) {
      case 'do':
        return 'Realizar';
      case 'postpone':
        return 'Posponer';
      default:
        return 'Revisar';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.blue,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.muted)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
