import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/planner_location.dart';
import '../themes/app_colors.dart';
import 'surface_box.dart';

/// Condiciones climaticas deseables que el usuario puede seleccionar.
/// Compartida entre el formulario de creacion y el dialogo de edicion.
const kConditionOptions = [
  'sin lluvia',
  'cielo despejado',
  'temperatura agradable',
  'viento bajo',
  'baja humedad',
];

class ActivityFormPreview extends StatefulWidget {
  const ActivityFormPreview({
    super.key,
    required this.activities,
    required this.locations,
    required this.onActivityAdded,
  });

  final List<Activity> activities;
  final List<PlannerLocation> locations;
  final Future<void> Function(Activity activity) onActivityAdded;

  @override
  State<ActivityFormPreview> createState() => _ActivityFormPreviewState();
}

class _ActivityFormPreviewState extends State<ActivityFormPreview> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final dateController = TextEditingController();
  final startController = TextEditingController();
  final endController = TextEditingController();

  PlannerLocation? selectedLocation;
  String selectedType = 'Aire libre';
  final Set<String> selectedConditions = {};
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.locations.isNotEmpty) {
      selectedLocation = widget.locations.first;
    }
  }

  @override
  void didUpdateWidget(covariant ActivityFormPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = selectedLocation;
    final stillExists = current != null && widget.locations.any((l) => l.id == current.id);
    if (!stillExists) {
      selectedLocation = widget.locations.isNotEmpty ? widget.locations.first : null;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    dateController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  DateTime? _parseDateTime(String date, String time) {
    final dateMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(date);
    final timeMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (dateMatch == null || timeMatch == null) return null;
    final day = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final year = int.parse(dateMatch.group(3)!);
    final hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return DateTime(year, month, day, hour, minute);
  }

  bool _overlaps(Activity activity, DateTime start, DateTime end) {
    if (activity.location != selectedLocation?.name) return false;
    if (activity.date != dateController.text.trim()) return false;
    final existingStart = _parseDateTime(activity.date, activity.time);
    final existingEnd = _parseDateTime(activity.date, activity.endTime);
    if (existingStart == null || existingEnd == null) return false;
    return start.isBefore(existingEnd) && end.isAfter(existingStart);
  }

  Future<void> saveActivity() async {
    if (isSaving) return;
    final location = selectedLocation;
    if (location == null) {
      _showMessage('Registra una ubicación antes de crear una actividad.');
      return;
    }
    final valid = formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final start = _parseDateTime(dateController.text.trim(), startController.text.trim());
    final end = _parseDateTime(dateController.text.trim(), endController.text.trim());

    if (start == null || end == null) {
      _showMessage('Usa fecha dd/mm/aaaa y hora HH:mm.');
      return;
    }
    if (!end.isAfter(start)) {
      _showMessage('La hora final debe ser mayor que la hora inicial.');
      return;
    }
    if (widget.activities.any((a) => _overlaps(a, start, end))) {
      _showMessage('La actividad se cruza con otra en la misma ubicación.');
      return;
    }

    // El clima real (temperatura, probabilidad de lluvia) y TODA la estadistica
    // los calcula el backend Django con OpenWeather al crear la actividad. El
    // formulario solo envia los datos capturados; estos campos climaticos son
    // marcadores que el servidor reemplaza al recargar la lista, por eso NO se
    // calcula clima en el cliente (evita datos duplicados o inconsistentes).
    final activity = Activity(
      locationId: location.id,
      title: titleController.text.trim(),
      location: location.name,
      date: dateController.text.trim(),
      time: startController.text.trim(),
      endTime: endController.text.trim(),
      type: selectedType,
      temperature: 0,
      rainProbability: 0,
      score: 0,
      status: ActivityStatus.possible,
      weatherSource: '',
      description: descriptionController.text.trim(),
      desiredConditions: selectedConditions.toList(),
    );

    setState(() => isSaving = true);
    try {
      await widget.onActivityAdded(activity);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    if (widget.locations.isEmpty) {
      return SurfaceBox(
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aún no tienes ubicaciones registradas. Ve a "Ubicaciones" y '
                'guarda al menos una para poder crear actividades reales.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return SurfaceBox(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el título.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: selectedLocation?.id,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final location in widget.locations)
                  DropdownMenuItem(value: location.id, child: Text(location.name)),
              ],
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  selectedLocation = widget.locations.firstWhere((l) => l.id == id);
                });
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                hintText: 'dd/mm/aaaa',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(text) ? null : 'Selecciona la fecha.';
              },
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
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      return RegExp(r'^\d{2}:\d{2}$').hasMatch(text) ? null : 'Hora';
                    },
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
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      return RegExp(r'^\d{2}:\d{2}$').hasMatch(text) ? null : 'Hora';
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Aire libre',
                  label: Text('Aire libre'),
                  icon: Icon(Icons.wb_sunny_outlined),
                ),
                ButtonSegment(
                  value: 'Interior',
                  label: Text('Interior'),
                  icon: Icon(Icons.meeting_room_outlined),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: (values) => setState(() => selectedType = values.first),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Condiciones deseables',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final condition in kConditionOptions)
                  FilterChip(
                    label: Text(condition),
                    selected: selectedConditions.contains(condition),
                    selectedColor: AppColors.blue.withValues(alpha: 0.18),
                    checkmarkColor: AppColors.blue,
                    onSelected: (on) => setState(() {
                      if (on) {
                        selectedConditions.add(condition);
                      } else {
                        selectedConditions.remove(condition);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSaving ? null : saveActivity,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
              label: Text(isSaving ? 'Guardando en el servidor...' : 'Guardar actividad'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
