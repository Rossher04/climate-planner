import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../themes/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/activity_summary_dialog.dart';
import '../widgets/info_tile.dart';
import '../widgets/pending_activity_tile.dart';

class PendingView extends StatefulWidget {
  const PendingView({
    super.key,
    required this.activities,
    required this.onMarkFinished,
    required this.onReschedule,
  });

  final List<Activity> activities;
  final Future<void> Function(Activity activity) onMarkFinished;
  final Future<void> Function(
    Activity activity, {
    required String date,
    required String startTime,
    required String endTime,
  }) onReschedule;

  @override
  State<PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends State<PendingView> {
  String sortBy = 'fecha';
  String filterLocation = 'todas';
  String filterStatus = 'todas';
  int? finishingId;

  List<Activity> _getVisibleActivities() {
    var activities = widget.activities
        .where((a) => a.status != ActivityStatus.finished)
        .toList();

    // --- FILTROS reales: OCULTAN las actividades que no coinciden ---
    if (filterLocation != 'todas') {
      activities = activities.where((a) => a.location == filterLocation).toList();
    }
    if (filterStatus != 'todas') {
      activities = activities.where((a) => a.status.name == filterStatus).toList();
    }

    // --- ORDEN ---
    switch (sortBy) {
      case 'probabilidad':
        activities.sort((a, b) => b.score.compareTo(a.score));
        break;
      case 'ubicacion':
        activities.sort((a, b) => a.location.compareTo(b.location));
        break;
      case 'fecha':
      default:
        activities.sort((a, b) {
          final aDate = parseSimpleDate(a.date);
          final bDate = parseSimpleDate(b.date);
          if (aDate == null || bDate == null) return 0;
          return aDate.compareTo(bDate);
        });
    }
    return activities;
  }

  Future<void> _openReschedule(Activity activity) async {
    final result = await showDialog<_RescheduleResult>(
      context: context,
      builder: (_) => _RescheduleDialog(activity: activity),
    );
    if (result == null) return;
    await widget.onReschedule(
      activity,
      date: result.date,
      startTime: result.startTime,
      endTime: result.endTime,
    );
  }

  Future<void> _markAsFinished(Activity activity) async {
    if (activity.id == null || finishingId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como hecha'),
        content: Text('Se marcara "${activity.title}" como finalizada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Marcar hecha'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => finishingId = activity.id);
    await widget.onMarkFinished(activity);
    if (!mounted) return;
    setState(() => finishingId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actividad finalizada en el servidor.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _getVisibleActivities();
    final pending =
        widget.activities.where((a) => a.status != ActivityStatus.finished);
    final locations = <String>{for (final a in pending) a.location}.toList()..sort();

    return ListView(
      children: [
        // ---- FILTROS reales (ubicación + probabilidad) ----
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: filterLocation,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filtrar ubicación',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'todas', child: Text('Todas')),
                  for (final loc in locations)
                    DropdownMenuItem(
                      value: loc,
                      child: Text(loc, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => filterLocation = v ?? 'todas'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: filterStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filtrar probabilidad',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'todas', child: Text('Todas')),
                  DropdownMenuItem(value: 'recommended', child: Text('Recomendadas')),
                  DropdownMenuItem(value: 'possible', child: Text('Por revisar')),
                  DropdownMenuItem(value: 'reschedule', child: Text('Reagendar')),
                ],
                onChanged: (v) => setState(() => filterStatus = v ?? 'todas'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ---- Ordenar ----
        Row(
          children: [
            Expanded(
              child: FilterChip(
                selected: sortBy == 'fecha',
                label: const Text('Fecha'),
                onSelected: (_) => setState(() => sortBy = 'fecha'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterChip(
                selected: sortBy == 'ubicacion',
                label: const Text('Ubicación'),
                onSelected: (_) => setState(() => sortBy = 'ubicacion'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterChip(
                selected: sortBy == 'probabilidad',
                label: const Text('Probabilidad'),
                onSelected: (_) => setState(() => sortBy = 'probabilidad'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${visible.length} actividad(es)',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        for (final activity in visible)
          PendingActivityTile(
            activity,
            onTap: () => showActivitySummary(context, activity),
            onMarkFinished:
                activity.id == null ? null : () => _markAsFinished(activity),
            onReschedule: activity.id == null ? null : () => _openReschedule(activity),
          ),
        if (visible.isEmpty)
          const InfoTile(
            status: ActivityStatus.possible,
            title: 'No hay actividades que coincidan',
            subtitle: 'Ajusta los filtros o crea nuevas actividades.',
          ),
      ],
    );
  }
}

class _RescheduleResult {
  const _RescheduleResult(this.date, this.startTime, this.endTime);
  final String date;
  final String startTime;
  final String endTime;
}

/// Dialogo para reagendar una actividad: nueva fecha y horario.
class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.activity});

  final Activity activity;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController dateController;
  late final TextEditingController startController;
  late final TextEditingController endController;

  @override
  void initState() {
    super.initState();
    dateController = TextEditingController(text: widget.activity.date);
    startController = TextEditingController(text: widget.activity.time);
    endController = TextEditingController(text: widget.activity.endTime);
  }

  @override
  void dispose() {
    dateController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _RescheduleResult(
        dateController.text.trim(),
        startController.text.trim(),
        endController.text.trim(),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var initial = today;
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(dateController.text.trim());
    if (m != null) {
      final parsed = DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
      if (!parsed.isBefore(today)) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() {
        dateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    var initial = const TimeOfDay(hour: 8, minute: 0);
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(controller.text.trim());
    if (m != null) {
      final hour = int.parse(m.group(1)!);
      final minute = int.parse(m.group(2)!);
      if (hour <= 23 && minute <= 59) initial = TimeOfDay(hour: hour, minute: minute);
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Selecciona la hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reagendar actividad'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.activity.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Nueva fecha',
                hintText: 'dd/mm/aaaa',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) => RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Selecciona la fecha.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: startController,
                    readOnly: true,
                    onTap: () => _pickTime(startController),
                    decoration: const InputDecoration(
                      labelText: 'Inicio',
                      hintText: 'HH:mm',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.schedule_outlined),
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{2}:\d{2}$').hasMatch(v?.trim() ?? '') ? null : 'HH:mm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: endController,
                    readOnly: true,
                    onTap: () => _pickTime(endController),
                    decoration: const InputDecoration(
                      labelText: 'Fin',
                      hintText: 'HH:mm',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.schedule_outlined),
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{2}:\d{2}$').hasMatch(v?.trim() ?? '') ? null : 'HH:mm',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
          child: const Text('Reagendar'),
        ),
      ],
    );
  }
}
