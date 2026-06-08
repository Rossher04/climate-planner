import 'dart:math';

import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../themes/app_colors.dart';
import '../widgets/metric_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/stat_tile.dart';
import '../widgets/status_chip.dart';
import '../widgets/surface_box.dart';

/// Panel de estadistica. TODOS los valores estadisticos provienen del backend
/// Django (modelo StatisticalSummary): tendencia central, regresion lineal y
/// probabilidad bayesiana. Flutter NO recalcula nada, solo visualiza.
class StatisticsView extends StatefulWidget {
  const StatisticsView({super.key, required this.activities});

  final List<Activity> activities;

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  int _selectedId = -1;

  /// Actividades que ya tienen resumen estadistico calculado en el servidor.
  List<Activity> get _withStats =>
      widget.activities.where((a) => a.statistics != null && a.id != null).toList();

  Activity? get _selected {
    final list = _withStats;
    if (list.isEmpty) return null;
    final match = list.where((a) => a.id == _selectedId);
    return match.isNotEmpty ? match.first : list.first;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return const Center(
        child: Text(
          'No hay actividades para calcular estadísticas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    final dashboard = DashboardStats(widget.activities);
    final selected = _selected;

    return ListView(
      children: [
        // --- Dashboard overview (conteos reales) ---
        const SectionTitle('Panel general'),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Total',
                value: '${dashboard.total}',
                color: AppColors.blue,
                icon: Icons.event_note_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Recomendadas',
                value: '${dashboard.recommended}',
                color: AppColors.green,
                icon: Icons.thumb_up_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Por revisar',
                value: '${dashboard.possible}',
                color: AppColors.gold,
                icon: Icons.help_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Reagendar',
                value: '${dashboard.reschedule}',
                color: AppColors.coral,
                icon: Icons.event_busy_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // --- Activity type distribution ---
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Tipo de actividades'),
              Row(
                children: [
                  Expanded(
                    child: _TypeBar(
                      label: 'Aire libre',
                      count: dashboard.outdoor,
                      total: dashboard.total,
                      color: AppColors.blue,
                      icon: Icons.wb_sunny_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeBar(
                      label: 'Interior',
                      count: dashboard.indoor,
                      total: dashboard.total,
                      color: AppColors.green,
                      icon: Icons.meeting_room_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // --- Per-activity statistics from backend ---
        if (selected == null)
          const SurfaceBox(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Las estadísticas (media, mediana, moda, regresión y Bayes) se '
                'calculan en el servidor al crear una actividad. Crea o abre una '
                'actividad para ver su análisis completo.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ),
          )
        else
          _ActivityStatsSection(
            activities: _withStats,
            selected: selected,
            onChanged: (id) => setState(() => _selectedId = id),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Per-activity backend statistics section ─────────────────────────────────

class _ActivityStatsSection extends StatelessWidget {
  const _ActivityStatsSection({
    required this.activities,
    required this.selected,
    required this.onChanged,
  });

  final List<Activity> activities;
  final Activity selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final stats = selected.statistics!;
    final series = stats.temperatureSeries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Análisis por actividad'),
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Actividad analizada',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: selected.id,
                  items: [
                    for (final a in activities)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.title} - ${a.location}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) onChanged(id);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // --- Tendencia central ---
        const SectionTitle('Resumen Climático Semanal'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Media',
                value: '${stats.meanTemperature.toStringAsFixed(1)} C',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Mediana',
                value: '${stats.medianTemperature.toStringAsFixed(1)} C',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Moda',
                value: '${stats.modeTemperature.toStringAsFixed(1)} C',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // --- Regresion lineal ---
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Regresión lineal')),
                  StatusChip(
                    status: stats.regressionSlope >= 0
                        ? ActivityStatus.recommended
                        : ActivityStatus.reschedule,
                    label: stats.trendLabel,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'y = ${stats.regressionSlope.toStringAsFixed(3)} x + '
                '${stats.regressionIntercept.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _slopeExplanation(stats.regressionSlope),
                style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 10),
              if (series.length >= 2)
                SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: TrendChartPainter(
                      values: series,
                      slope: stats.regressionSlope,
                      intercept: stats.regressionIntercept,
                    ),
                  ),
                )
              else
                const Text(
                  'Serie de temperaturas no disponible para esta actividad.',
                  style: TextStyle(color: AppColors.muted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // --- Bayes section ---
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Análisis bayesiano'),
              const SizedBox(height: 4),
              const Text(
                'Probabilidad de lluvia ajustada con el Teorema de Bayes a partir '
                'del pronóstico y la fiabilidad del sistema de alerta.',
                style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _BayesRow(
                label: 'P(lluvia | alerta) - Bayes',
                value: '${stats.bayesRainProbability.toStringAsFixed(1)}%',
                highlight: true,
              ),
              const Divider(height: 20),
              _BayesRow(
                label: 'Probabilidad de realización',
                value: '${stats.realizationProbability.toStringAsFixed(1)}%',
                highlight: true,
              ),
              const SizedBox(height: 6),
              _BayesRow(
                label: 'Recomendación',
                value: _recommendationLabel(stats.recommendation),
                highlight: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _slopeExplanation(double slope) {
    final magnitude = slope.abs().toStringAsFixed(3);
    if (slope > 0.05) {
      return 'La pendiente m = +$magnitude indica que la temperatura tiende a '
          'subir aproximadamente $magnitude C por día (tendencia al alza).';
    }
    if (slope < -0.05) {
      return 'La pendiente m = -$magnitude indica que la temperatura tiende a '
          'bajar aproximadamente $magnitude C por día (tendencia a la baja).';
    }
    return 'La pendiente m = $magnitude es cercana a cero: la temperatura se '
        'mantiene estable en la semana.';
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

// ─── Dashboard statistics ─────────────────────────────────────────────────────

class DashboardStats {
  DashboardStats(this.activities);

  final List<Activity> activities;

  int get total => activities.length;
  int get recommended => activities.where((a) => a.status == ActivityStatus.recommended).length;
  int get possible => activities.where((a) => a.status == ActivityStatus.possible).length;
  int get reschedule => activities.where((a) => a.status == ActivityStatus.reschedule).length;
  int get outdoor => activities.where((a) => a.type == 'Aire libre').length;
  int get indoor => activities.where((a) => a.type == 'Interior').length;
}

// ─── Bayes row widget ─────────────────────────────────────────────────────────

class _BayesRow extends StatelessWidget {
  const _BayesRow({required this.label, required this.value, required this.highlight});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppColors.ink : AppColors.muted,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.blue : AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Type distribution bar ────────────────────────────────────────────────────

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: AppColors.line,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count actividades (${(pct * 100).toStringAsFixed(0)}%)',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

// ─── Trend chart painter (scatter + regression line) ──────────────────────────

class TrendChartPainter extends CustomPainter {
  const TrendChartPainter({
    required this.values,
    required this.slope,
    required this.intercept,
  });

  final List<double> values;
  final double slope;
  final double intercept;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 28.0;
    final minV = values.reduce(min) - 1;
    final maxV = values.reduce(max) + 1;

    final gridPaint = Paint()..color = AppColors.line..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final trendPaint = Paint()
      ..color = AppColors.coral
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = Colors.white;
    final dotBorder = Paint()..color = AppColors.blue..strokeWidth = 3..style = PaintingStyle.stroke;

    for (var i = 0; i < 4; i++) {
      final y = padding + i * ((size.height - padding * 2) / 3);
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    final span = values.length > 1 ? values.length - 1 : 1;
    Offset pointFor(int day, double temp) {
      final x = padding + (day / span) * (size.width - padding * 2);
      final y = size.height - padding - ((temp - minV) / (maxV - minV)) * (size.height - padding * 2);
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = pointFor(i, values[i]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // Recta de regresion: x va de 1..n (igual que en el backend), por eso
    // evaluamos intercept + slope*(i+1).
    final trendPath = Path()
      ..moveTo(pointFor(0, intercept + slope).dx, pointFor(0, intercept + slope).dy)
      ..lineTo(
        pointFor(values.length - 1, intercept + slope * values.length).dx,
        pointFor(values.length - 1, intercept + slope * values.length).dy,
      );
    canvas.drawPath(trendPath, trendPaint);

    for (var i = 0; i < values.length; i++) {
      final p = pointFor(i, values[i]);
      canvas.drawCircle(p, 6, dotPaint);
      canvas.drawCircle(p, 6, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter old) =>
      old.values != values || old.slope != slope || old.intercept != intercept;
}
