import 'package:flutter/material.dart';

import '../models/coordinates.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';
import 'section_title.dart';
import 'surface_box.dart';

class LocationFormPreview extends StatefulWidget {
  const LocationFormPreview({
    super.key,
    required this.apiService,
    required this.onLocationCreated,
    this.deviceCoordinates,
    this.pickedCoordinates,
  });

  final ApiService apiService;
  final Future<void> Function() onLocationCreated;
  final Coordinates? deviceCoordinates;

  /// Coordenadas seleccionadas tocando el mapa. Cuando cambian, se rellenan
  /// automaticamente los campos de latitud y longitud.
  final Coordinates? pickedCoordinates;

  @override
  State<LocationFormPreview> createState() => _LocationFormPreviewState();
}

class _LocationFormPreviewState extends State<LocationFormPreview> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final latController = TextEditingController();
  final lonController = TextEditingController();
  bool isSaving = false;

  @override
  void didUpdateWidget(covariant LocationFormPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final picked = widget.pickedCoordinates;
    if (picked != null && picked != oldWidget.pickedCoordinates) {
      latController.text = picked.latitude.toStringAsFixed(6);
      lonController.text = picked.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    latController.dispose();
    lonController.dispose();
    super.dispose();
  }

  void _useDevice() {
    final coords = widget.deviceCoordinates;
    if (coords == null) {
      _showMessage('Primero toca "Usar ubicación actual" en el mapa.');
      return;
    }
    setState(() {
      latController.text = coords.latitude.toStringAsFixed(6);
      lonController.text = coords.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _save() async {
    if (isSaving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final lat = double.parse(latController.text.trim());
    final lon = double.parse(lonController.text.trim());

    setState(() => isSaving = true);
    try {
      await widget.apiService.createLocation(
        name: nameController.text.trim(),
        latitude: lat,
        longitude: lon,
      );
      await widget.onLocationCreated();
      if (!mounted) return;
      nameController.clear();
      latController.clear();
      lonController.clear();
      _showMessage('Ubicación guardada en el servidor.');
    } catch (e) {
      _showMessage('$e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateCoord(String? value, {required bool isLat}) {
    final text = value?.trim() ?? '';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Número inválido.';
    if (isLat && (parsed < -90 || parsed > 90)) return 'Latitud -90 a 90.';
    if (!isLat && (parsed < -180 || parsed > 180)) return 'Longitud -180 a 180.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Registro de ubicación'),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre.' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _validateCoord(v, isLat: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: lonController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _validateCoord(v, isLat: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _useDevice,
              icon: const Icon(Icons.my_location),
              label: const Text('Usar ubicación actual'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Guardando...' : 'Guardar ubicación'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}
