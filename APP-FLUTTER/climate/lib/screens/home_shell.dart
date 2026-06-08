import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/activity.dart';
import '../models/climate_view.dart';
import '../models/coordinates.dart';
import '../models/planner_location.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../widgets/climate_drawer.dart';
import '../widgets/climate_logo.dart';
import '../widgets/weather_badge.dart';
import 'activities_screen.dart';
import 'locations_screen.dart';
import 'pending_screen.dart';
import 'statistics_screen.dart';
import 'summary_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  ClimateView selectedView = ClimateView.summary;
  final List<Activity> activities = [];
  List<PlannerLocation> locations = [];
  bool isSyncing = false;
  bool loadedFromApi = false;
  String userName = '';

  // Temperatura ACTUAL real (OpenWeatherMap) para el badge del header.
  double? currentTemp;
  bool loadingTemp = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadCurrentWeather();
  }

  /// Obtiene la temperatura actual real: usa el GPS del telefono para las
  /// coordenadas y consulta OpenWeatherMap a traves del backend. Si el GPS no
  /// esta disponible, cae en la primera ubicacion guardada del usuario.
  Future<void> _loadCurrentWeather() async {
    if (!widget.apiService.isAuthenticated) return;
    setState(() => loadingTemp = true);
    try {
      final coords = await _resolveCoordinates();
      if (coords == null) return;
      final temp = await widget.apiService.fetchCurrentTemperature(
        coords.$1,
        coords.$2,
      );
      if (!mounted) return;
      setState(() => currentTemp = temp);
    } catch (_) {
      // Sin conexion o sin clima: el badge mostrara "--".
    } finally {
      if (mounted) setState(() => loadingTemp = false);
    }
  }

  /// Devuelve (lat, lon) del GPS si hay permiso; si no, de la primera ubicacion.
  Future<(double, double)?> _resolveCoordinates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
          return (pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (last.latitude, last.longitude);
    }
    // Respaldo: primera ubicacion guardada del usuario.
    if (locations.isNotEmpty) {
      final loc = locations.first;
      return (loc.latitude, loc.longitude);
    }
    return null;
  }

  Future<void> _loadInitialData() async {
    if (!widget.apiService.isAuthenticated) return;

    setState(() => isSyncing = true);
    try {
      final fetchedLocations = await widget.apiService.fetchLocations();
      final fetchedActivities = await widget.apiService.fetchActivities();
      var name = userName;
      try {
        final me = await widget.apiService.fetchMe();
        name = me.firstName.trim().isNotEmpty ? me.firstName.trim() : me.username;
      } catch (_) {
        // Si falla, el saludo usa un valor generico.
      }
      if (!mounted) return;

      setState(() {
        _applyLocations(fetchedLocations);
        activities
          ..clear()
          ..addAll(fetchedActivities);
        userName = name;
        loadedFromApi = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar con la API: $e')),
      );
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  void _applyLocations(List<PlannerLocation> fetched) {
    locations = fetched;
    for (final location in fetched) {
      locationIds[location.name] = location.id;
    }
  }

  Future<void> _refreshActivities() async {
    if (!widget.apiService.isAuthenticated) return;
    try {
      final fetched = await widget.apiService.fetchActivities();
      if (!mounted) return;
      setState(() {
        activities
          ..clear()
          ..addAll(fetched);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron recargar las actividades: $e')),
      );
    }
  }

  void _selectView(ClimateView view) {
    setState(() => selectedView = view);
    Navigator.of(context).maybePop();
  }

  void _openProfile() {
    Navigator.of(context).pop(); // cierra el drawer
    Navigator.of(context).pushNamed(RouteNames.profile);
  }

  Future<void> _addActivity(Activity activity) async {
    if (!widget.apiService.isAuthenticated) {
      _showError('Inicia sesión para guardar actividades en el servidor.');
      return;
    }

    try {
      await widget.apiService.createActivity(activity);
    } catch (e) {
      _showError('$e');
      return; // Nunca insertamos actividades que no se guardaron en Django.
    }

    await _refreshActivities();
    if (!mounted) return;
    setState(() => selectedView = ClimateView.pending);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad guardada en el servidor.')),
    );
  }

  Future<void> _onLocationCreated() async {
    try {
      final fetched = await widget.apiService.fetchLocations();
      if (!mounted) return;
      setState(() => _applyLocations(fetched));
    } catch (e) {
      _showError('No se pudieron recargar las ubicaciones: $e');
    }
    // Si se elimino una ubicacion, sus actividades se borran EN CASCADA en el
    // backend; refrescamos la lista para que tambien desaparezcan en la app.
    await _refreshActivities();
  }

  Future<void> _markFinished(Activity activity) async {
    if (activity.id == null) return;
    try {
      await widget.apiService.markActivityFinished(activity.id!);
    } catch (e) {
      _showError('$e');
      return;
    }
    await _refreshActivities();
  }

  Future<void> _rescheduleActivity(
    Activity activity, {
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    if (activity.id == null) return;
    try {
      await widget.apiService.rescheduleActivity(
        activity.id!,
        date: date,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _showError('$e');
      return;
    }
    await _refreshActivities();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad reagendada en el servidor.')),
    );
  }

  Future<void> _editActivity(Activity activity) async {
    try {
      await widget.apiService.updateActivity(activity);
    } catch (e) {
      _showError('$e');
      return;
    }
    await _refreshActivities();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad actualizada en el servidor.')),
    );
  }

  Future<void> _deleteActivity(Activity activity) async {
    if (activity.id == null) return;
    try {
      await widget.apiService.deleteActivity(activity.id!);
    } catch (e) {
      _showError('$e');
      return;
    }
    await _refreshActivities();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad eliminada del servidor.')),
    );
  }

  Future<void> _logout() async {
    await widget.apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(RouteNames.login);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildView() {
    switch (selectedView) {
      case ClimateView.summary:
        return SummaryView(activities: activities, userName: userName);
      case ClimateView.locations:
        return LocationsView(
          apiService: widget.apiService,
          locations: locations,
          onLocationCreated: _onLocationCreated,
        );
      case ClimateView.activities:
        return ActivitiesView(
          activities: activities,
          locations: locations,
          onActivityAdded: _addActivity,
          onActivityEdit: _editActivity,
          onActivityDelete: _deleteActivity,
        );
      case ClimateView.pending:
        return PendingView(
          activities: activities,
          onMarkFinished: _markFinished,
          onReschedule: _rescheduleActivity,
        );
      case ClimateView.statistics:
        return StatisticsView(activities: activities);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            const ClimateLogo(size: 36),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                selectedView.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Recargar desde el servidor',
              icon: const Icon(Icons.refresh),
              onPressed: _loadInitialData,
            ),
          WeatherBadge(temperature: currentTemp, loading: loadingTemp),
          const SizedBox(width: 12),
        ],
      ),
      drawer: ClimateDrawer(
        selectedView: selectedView,
        onSelected: _selectView,
        onProfile: _openProfile,
        onLogout: _logout,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Padding(
            key: ValueKey(selectedView),
            padding: const EdgeInsets.all(16),
            child: _buildView(),
          ),
        ),
      ),
    );
  }
}
