import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/activity.dart';
import '../models/activity_statistics.dart';
import '../models/app_user.dart';
import '../models/coordinates.dart';
import '../models/planner_location.dart';
import '../utils/date_utils.dart';

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : client = client ?? http.Client(),
        baseUrl = baseUrl ?? apiBaseUrl;

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  final http.Client client;
  final String baseUrl;
  String? accessToken;
  String? refreshToken;

  bool get isAuthenticated => accessToken != null;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString(_accessKey);
      refreshToken = prefs.getString(_refreshKey);
      debugPrint('[ApiService] Sesion restaurada: ${isAuthenticated ? 'token presente' : 'sin token'}');
    } catch (e) {
      debugPrint('[ApiService] No se pudo restaurar sesion: $e');
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken != null) {
        await prefs.setString(_accessKey, accessToken!);
      }
      if (refreshToken != null) {
        await prefs.setString(_refreshKey, refreshToken!);
      }
    } catch (e) {
      debugPrint('[ApiService] No se pudo guardar sesion: $e');
    }
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } catch (_) {}
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    final response = await client
        .post(
          _uri('/auth/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': usernameOrEmail, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      debugPrint('[ApiService] Login fallido: ${response.statusCode}');
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    accessToken = data['access'] as String?;
    refreshToken = data['refresh'] as String?;
    if (accessToken != null) {
      await _persistSession();
      return true;
    }
    return false;
  }

  // ─── Clima actual ─────────────────────────────────────────────────────────

  /// Temperatura actual REAL desde OpenWeatherMap (via backend Django) para las
  /// coordenadas dadas. Devuelve null si el servidor no pudo obtenerla.
  Future<double?> fetchCurrentTemperature(double lat, double lon) async {
    final response = await client
        .get(_uri('/weather/current/?lat=$lat&lon=$lon'), headers: _authHeaders)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return double.tryParse('${data['temperature']}');
  }

  // ─── Usuario ────────────────────────────────────────────────────────────────

  Future<AppUser> fetchMe() async {
    final response = await client
        .get(_uri('/users/me/'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar el perfil (${response.statusCode}).');
    }
    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final response = await client
        .patch(
          _uri('/users/me/'),
          headers: _authHeaders,
          body: jsonEncode({
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone': phone,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar el perfil: ${_errorDetail(response.body)}');
    }
    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await client
        .post(
          _uri('/auth/change-password/'),
          headers: _authHeaders,
          body: jsonEncode({
            'old_password': oldPassword,
            'new_password': newPassword,
            'password_confirm': confirmPassword,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response.body));
    }
  }

  Future<String> requestPasswordRecovery(String email) async {
    final response = await client
        .post(
          _uri('/auth/password-recovery/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response.body));
    }
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Se ha enviado una contraseña temporal a tu correo.';
  }

  /// Inicia la recuperacion exigiendo USUARIO + CORREO que coincidan en la
  /// misma cuenta. El backend asigna una contrasena temporal y la devuelve (o
  /// la envia por correo si Resend esta activo).
  Future<Map<String, dynamic>> startPasswordRecovery(
    String email, {
    String username = '',
  }) async {
    final response = await client
        .post(
          _uri('/auth/password-recovery/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'username': username}),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response.body));
    }
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// Restablece la contrasena usando el token de recuperacion (sin loguearse).
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await client
        .post(
          _uri('/auth/password-reset/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'new_password': newPassword,
            'password_confirm': confirmPassword,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response.body));
    }
  }

  // ─── Ubicaciones ──────────────────────────────────────────────────────────────

  Future<List<PlannerLocation>> fetchLocations() async {
    final response = await client
        .get(_uri('/locations/'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar ubicaciones (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(PlannerLocation.fromJson).toList();
  }

  Future<PlannerLocation> createLocation({
    required String name,
    required double latitude,
    required double longitude,
    String description = '',
  }) async {
    final response = await client
        .post(
          _uri('/locations/'),
          headers: _authHeaders,
          body: jsonEncode({
            'name': name,
            'description': description,
            'latitude': latitude,
            'longitude': longitude,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw Exception('No se pudo guardar la ubicación (${response.statusCode}).');
    }
    return PlannerLocation.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PlannerLocation> updateLocation({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String description = '',
  }) async {
    final response = await client
        .patch(
          _uri('/locations/$id/'),
          headers: _authHeaders,
          body: jsonEncode({
            'name': name,
            'description': description,
            'latitude': latitude,
            'longitude': longitude,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar la ubicación: ${_errorDetail(response.body)}');
    }
    return PlannerLocation.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteLocation(int id) async {
    final response = await client
        .delete(_uri('/locations/$id/'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('No se pudo eliminar la ubicación (${response.statusCode}).');
    }
  }

  Future<List<Activity>> fetchActivities() async {
    final response = await client
        .get(_uri('/activities/'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar actividades (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(activityFromJson).toList();
  }

  Future<Activity> createActivity(Activity activity) async {
    final locationId = activity.locationId ?? locationIds[activity.location];
    if (locationId == null) {
      throw Exception('Selecciona una ubicación registrada en la API.');
    }

    final response = await client
        .post(
          _uri('/activities/'),
          headers: _authHeaders,
          body: jsonEncode({
            'location': locationId,
            'title': activity.title,
            'description': activity.description,
            'date': toApiDate(activity.date),
            'start_time': '${activity.time}:00',
            'end_time': '${activity.endTime}:00',
            'activity_type': activity.type == 'Interior' ? 'indoor' : 'outdoor',
            'desired_conditions': activity.desiredConditions.isEmpty
                ? ['sin lluvia']
                : activity.desiredConditions,
            'status': 'pending',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      final detail = _errorDetail(response.body);
      throw Exception('No se pudo guardar la actividad: $detail');
    }

    return activityFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Activity> updateActivity(Activity activity) async {
    final id = activity.id;
    if (id == null) {
      throw Exception('La actividad no tiene identificador para actualizar.');
    }
    final locationId = activity.locationId ?? locationIds[activity.location];
    if (locationId == null) {
      throw Exception('Selecciona una ubicación registrada en la API.');
    }

    final response = await client
        .patch(
          _uri('/activities/$id/'),
          headers: _authHeaders,
          body: jsonEncode({
            'location': locationId,
            'title': activity.title,
            'description': activity.description,
            'date': toApiDate(activity.date),
            'start_time': '${activity.time}:00',
            'end_time': '${activity.endTime}:00',
            'activity_type': activity.type == 'Interior' ? 'indoor' : 'outdoor',
            'desired_conditions': activity.desiredConditions.isEmpty
                ? ['sin lluvia']
                : activity.desiredConditions,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final detail = _errorDetail(response.body);
      throw Exception('No se pudo actualizar la actividad: $detail');
    }

    return activityFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteActivity(int activityId) async {
    final response = await client
        .delete(_uri('/activities/$activityId/'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('No se pudo eliminar la actividad (${response.statusCode}).');
    }
  }

  /// Reagenda una actividad pendiente: actualiza fecha/horas y marca el
  /// estado como 'rescheduled'. [date] llega en formato dd/mm/aaaa y las horas
  /// en HH:mm.
  Future<Activity> rescheduleActivity(
    int activityId, {
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final response = await client
        .patch(
          _uri('/activities/$activityId/'),
          headers: _authHeaders,
          body: jsonEncode({
            'date': toApiDate(date),
            'start_time': '$startTime:00',
            'end_time': '$endTime:00',
            'status': 'rescheduled',
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('No se pudo reagendar: ${_errorDetail(response.body)}');
    }
    return activityFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> markActivityFinished(int activityId) async {
    final response = await client
        .post(_uri('/activities/$activityId/finish/'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('No se pudo marcar como finalizada (${response.statusCode}).');
    }
  }

  String _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded.isNotEmpty) {
        final first = decoded.values.first;
        if (first is List && first.isNotEmpty) return '${first.first}';
        return '$first';
      }
      if (decoded is List && decoded.isNotEmpty) return '${decoded.first}';
    } catch (_) {}
    return body;
  }

  Activity activityFromJson(Map<String, dynamic> json) {
    final score = double.tryParse('${json['realization_probability']}')?.round();
    final temperature = double.tryParse('${json['temperature']}') ?? 24;
    final rainProbability = double.tryParse('${json['rain_probability']}')?.round();
    final activityType = json['activity_type'] == 'indoor' ? 'Interior' : 'Aire libre';
    final locationName = (json['location_name'] as String?) ?? 'Ubicación';
    final rawConditions = json['desired_conditions'];
    final desiredConditions = rawConditions is List
        ? rawConditions.map((e) => '$e').toList()
        : <String>[];
    final statistics = ActivityStatistics.fromJson(
      json['statistics'] as Map<String, dynamic>?,
    );

    return Activity(
      id: json['id'] as int?,
      locationId: json['location'] as int?,
      title: json['title'] as String,
      location: locationName,
      date: fromApiDate(json['date'] as String),
      time: shortTime(json['start_time'] as String),
      endTime: shortTime(json['end_time'] as String),
      type: activityType,
      temperature: temperature,
      rainProbability: rainProbability ?? (score == null ? 0 : max(0, 100 - score)),
      score: score ?? 70,
      status: _statusFromActivity(json),
      weatherSource: (json['weather_source'] as String?) ?? 'Django API',
      description: (json['description'] as String?) ?? '',
      desiredConditions: desiredConditions,
      statistics: statistics,
    );
  }

  ActivityStatus _statusFromActivity(Map<String, dynamic> json) {
    if (json['status'] == 'finished') return ActivityStatus.finished;
    switch (json['recommendation']) {
      case 'do':
        return ActivityStatus.recommended;
      case 'postpone':
        return ActivityStatus.reschedule;
      default:
        return ActivityStatus.possible;
    }
  }
}
