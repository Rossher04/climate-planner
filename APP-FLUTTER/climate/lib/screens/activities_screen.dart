import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/planner_location.dart';
import '../themes/app_colors.dart';
import '../widgets/activity_form.dart';
import '../widgets/activity_summary_dialog.dart';
import '../widgets/info_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/status_chip.dart';
import '../widgets/surface_box.dart';

class ActivitiesView extends StatelessWidget {
  const ActivitiesView({
    super.key,
    required this.activities,
    required this.locations,
    required this.onActivityAdded,
    required this.onActivityEdit,
    required this.onActivityDelete,
  });

  final List<Activity> activities;
  final List<PlannerLocation> locations;
  final Future<void> Function(Activity activity) onActivityAdded;
  final Future<void> Function(Activity activity) onActivityEdit;
  final Future<void> Function(Activity activity) onActivityDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('Nueva actividad'),
        ActivityFormPreview(
          activities: activities,
          locations: locations,
          onActivityAdded: onActivityAdded,
        ),
        const SizedBox(height: 14),
        const SectionTitle('Actividades creadas'),
        for (final activity in activities)
          _ActivityTile(
            activity: activity,
            locations: locations,
            onEdit: onActivityEdit,
            onDelete: onActivityDelete,
          ),
        if (activities.isEmpty)
          const InfoTile(
            status: ActivityStatus.possible,
            title: 'Sin actividades',
            subtitle: 'Crea la primera actividad desde el formulario.',
          ),
      ],
    );
  }
}

/// Tarjeta de una actividad con menu para editar o eliminar.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.locations,
    required this.onEdit,
    required this.onDelete,
  });

  final Activity activity;
  final List<PlannerLocation> locations;
  final Future<void> Function(Activity activity) onEdit;
  final Future<void> Function(Activity activity) onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('Se eliminará "${activity.title}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete(activity);
  }

  Future<void> _openEdit(BuildContext context) async {
    final updated = await showDialog<Activity>(
      context: context,
      builder: (_) => EditActivityDialog(activity: activity, locations: locations),
    );
    if (updated != null) await onEdit(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => showActivitySummary(context, activity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              StatusChip(status: activity.status),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.muted),
                onSelected: (value) {
                  if (value == 'edit') _openEdit(context);
                  if (value == 'delete') _confirmDelete(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            activity.title,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${activity.type} - ${activity.date} - ${activity.time} a ${activity.endTime} - '
            'lluvia ${activity.rainProbability}% - ${activity.weatherSource}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (activity.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(activity.description, style: const TextStyle(color: AppColors.ink)),
          ],
          if (activity.desiredConditions.isNotEmpty) ...[
            const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }
}

/// Dialogo para editar una actividad existente.
class EditActivityDialog extends StatefulWidget {
  const EditActivityDialog({
    super.key,
    required this.activity,
    required this.locations,
  });

  final Activity activity;
  final List<PlannerLocation> locations;

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController dateController;
  late final TextEditingController startController;
  late final TextEditingController endController;

  late String selectedType;
  late int? selectedLocationId;
  late final Set<String> selectedConditions;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    titleController = TextEditingController(text: a.title);
    descriptionController = TextEditingController(text: a.description);
    dateController = TextEditingController(text: a.date);
    startController = TextEditingController(text: a.time);
    endController = TextEditingController(text: a.endTime);
    selectedType = a.type;
    selectedLocationId = a.locationId ??
        (widget.locations.isNotEmpty ? widget.locations.first.id : null);
    selectedConditions = {...a.desiredConditions};
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

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final location = widget.locations.firstWhere(
      (l) => l.id == selectedLocationId,
      orElse: () => widget.locations.first,
    );
    final updated = widget.activity.copyWith(
      locationId: location.id,
      location: location.name,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      date: dateController.text.trim(),
      time: startController.text.trim(),
      endTime: endController.text.trim(),
      type: selectedType,
      desiredConditions: selectedConditions.toList(),
    );
    Navigator.of(context).pop(updated);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var initial = today;
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(dateController.text.trim());
    if (m != null) {
      initial = DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    }
    final firstDate = initial.isBefore(today) ? initial : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
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
      title: const Text('Editar actividad'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa el título.' : null,
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
                if (widget.locations.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: selectedLocationId,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final location in widget.locations)
                        DropdownMenuItem(value: location.id, child: Text(location.name)),
                    ],
                    onChanged: (id) => setState(() => selectedLocationId = id),
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
                            RegExp(r'^\d{2}:\d{2}$').hasMatch(v?.trim() ?? '') ? null : 'Hora',
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
                            RegExp(r'^\d{2}:\d{2}$').hasMatch(v?.trim() ?? '') ? null : 'Hora',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Aire libre', label: Text('Aire libre')),
                    ButtonSegment(value: 'Interior', label: Text('Interior')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (values) => setState(() => selectedType = values.first),
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
