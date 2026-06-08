import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/coordinates.dart';
import '../models/planner_location.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../themes/app_colors.dart';
import '../widgets/location_form.dart';
import '../widgets/location_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/surface_box.dart';

class LocationsView extends StatefulWidget {
  const LocationsView({
    super.key,
    required this.apiService,
    required this.locations,
    required this.onLocationCreated,
  });

  final ApiService apiService;
  final List<PlannerLocation> locations;
  final Future<void> Function() onLocationCreated;

  @override
  State<LocationsView> createState() => _LocationsViewState();
}

class _LocationsViewState extends State<LocationsView> {
  static const _defaultCenter = LatLng(14.8421, -91.5210);

  GoogleMapController? mapController;
  bool canUseDeviceLocation = false;
  PlannerLocation? selectedLocation;
  Coordinates? deviceCoordinates;
  Coordinates? pickedCoordinates;

  final _searchController = TextEditingController();
  final _geocoding = const GeocodingService();
  List<GeoPlace> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.locations.isNotEmpty) {
      selectedLocation = widget.locations.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  LatLng get _cameraTarget {
    if (selectedLocation != null) {
      return LatLng(selectedLocation!.latitude, selectedLocation!.longitude);
    }
    if (deviceCoordinates != null) {
      return LatLng(deviceCoordinates!.latitude, deviceCoordinates!.longitude);
    }
    return _defaultCenter;
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (final location in widget.locations) {
      markers.add(
        Marker(
          markerId: MarkerId('loc_${location.id}'),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(title: location.name),
        ),
      );
    }
    if (deviceCoordinates != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('device'),
          position: LatLng(deviceCoordinates!.latitude, deviceCoordinates!.longitude),
          infoWindow: const InfoWindow(title: 'Ubicación actual'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    if (pickedCoordinates != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('picked'),
          position: LatLng(pickedCoordinates!.latitude, pickedCoordinates!.longitude),
          infoWindow: const InfoWindow(title: 'Punto seleccionado'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    return markers;
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      pickedCoordinates = Coordinates(position.latitude, position.longitude);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Punto seleccionado. Coordenadas cargadas en el formulario.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Busca lugares por nombre (Open-Meteo geocoding) y muestra los resultados.
  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await _geocoding.search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin resultados. Prueba con otro nombre.')),
      );
    }
  }

  /// Al elegir un resultado: centra el mapa y carga las coordenadas en el form.
  void _onPlacePicked(GeoPlace place) {
    setState(() {
      pickedCoordinates = Coordinates(place.latitude, place.longitude);
      _searchResults = [];
      _searchController.text = place.name;
    });
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 14),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name}: coordenadas cargadas en el formulario.')),
    );
  }

  Future<void> _editLocation(PlannerLocation location) async {
    final updated = await showDialog<_LocationEditResult>(
      context: context,
      builder: (_) => _EditLocationDialog(location: location),
    );
    if (updated == null) return;
    try {
      await widget.apiService.updateLocation(
        id: location.id,
        name: updated.name,
        latitude: updated.latitude,
        longitude: updated.longitude,
        description: location.description,
      );
      await widget.onLocationCreated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación actualizada en el servidor.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteLocation(PlannerLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ubicación'),
        content: Text(
          'Se eliminará "${location.name}". Las actividades asociadas también '
          'se eliminarán. Esta acción no se puede deshacer.',
        ),
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
    if (confirmed != true) return;
    try {
      await widget.apiService.deleteLocation(location.id);
      if (selectedLocation?.id == location.id) selectedLocation = null;
      await widget.onLocationCreated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación eliminada del servidor.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> useCurrentLocation() async {
    final messenger = ScaffoldMessenger.of(context);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      messenger.showSnackBar(const SnackBar(content: Text('Activa la ubicación del dispositivo.')));
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(const SnackBar(content: Text('Permiso de ubicación denegado.')));
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await _applyDevicePosition(position.latitude, position.longitude);
    } catch (_) {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        await _applyDevicePosition(lastPosition.latitude, lastPosition.longitude);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo obtener la ubicación.')));
      }
    }
  }

  Future<void> _applyDevicePosition(double lat, double lon) async {
    if (!mounted) return;
    setState(() {
      canUseDeviceLocation = true;
      deviceCoordinates = Coordinates(lat, lon);
    });
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lon), 15));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('Mapa de ubicaciones'),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchPlaces(),
          decoration: InputDecoration(
            hintText: 'Buscar lugar (ej. Quetzaltenango)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _searchPlaces,
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 6),
          SurfaceBox(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final place in _searchResults)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: AppColors.blue),
                    title: Text(place.name),
                    subtitle: place.region.isEmpty ? null : Text(place.region),
                    onTap: () => _onPlacePicked(place),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        SurfaceBox(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 260,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _cameraTarget, zoom: 14),
                markers: _markers,
                myLocationButtonEnabled: true,
                myLocationEnabled: canUseDeviceLocation,
                onMapCreated: (controller) => mapController = controller,
                onTap: _onMapTapped,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Busca un lugar arriba o toca el mapa para seleccionar coordenadas; se '
          'cargarán en el formulario.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: useCurrentLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Usar ubicación actual'),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Ubicaciones registradas'),
        if (widget.locations.isEmpty)
          const SurfaceBox(
            child: Text(
              'Aún no tienes ubicaciones guardadas en el servidor. Registra una abajo.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final location in widget.locations)
          LocationTile(
            color: location.id == selectedLocation?.id ? AppColors.green : AppColors.blue,
            title: location.name,
            coordinates: '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
            subtitle: location.id == selectedLocation?.id
                ? 'Ubicación seleccionada para actividades.'
                : 'Disponible para consultar clima y registrar actividades.',
            onTap: () {
              setState(() => selectedLocation = location);
              mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(location.latitude, location.longitude), 14),
              );
            },
            onEdit: () => _editLocation(location),
            onDelete: () => _deleteLocation(location),
          ),
        const SizedBox(height: 8),
        LocationFormPreview(
          apiService: widget.apiService,
          deviceCoordinates: deviceCoordinates,
          pickedCoordinates: pickedCoordinates,
          onLocationCreated: widget.onLocationCreated,
        ),
      ],
    );
  }
}

class _LocationEditResult {
  const _LocationEditResult(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;
}

/// Dialogo para editar una ubicacion existente.
class _EditLocationDialog extends StatefulWidget {
  const _EditLocationDialog({required this.location});

  final PlannerLocation location;

  @override
  State<_EditLocationDialog> createState() => _EditLocationDialogState();
}

class _EditLocationDialogState extends State<_EditLocationDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController latController;
  late final TextEditingController lonController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.location.name);
    latController = TextEditingController(text: widget.location.latitude.toStringAsFixed(6));
    lonController = TextEditingController(text: widget.location.longitude.toStringAsFixed(6));
  }

  @override
  void dispose() {
    nameController.dispose();
    latController.dispose();
    lonController.dispose();
    super.dispose();
  }

  String? _validateCoord(String? value, {required bool isLat}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Número inválido.';
    if (isLat && (parsed < -90 || parsed > 90)) return 'Latitud -90 a 90.';
    if (!isLat && (parsed < -180 || parsed > 180)) return 'Longitud -180 a 180.';
    return null;
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _LocationEditResult(
        nameController.text.trim(),
        double.parse(latController.text.trim()),
        double.parse(lonController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar ubicación'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _validateCoord(v, isLat: false),
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
