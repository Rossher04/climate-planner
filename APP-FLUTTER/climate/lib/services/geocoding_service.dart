import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lugar encontrado por el buscador.
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region = '',
  });

  final String name;
  final double latitude;
  final double longitude;

  /// Texto secundario legible (zona/ciudad/departamento).
  final String region;
}

/// Busca lugares por nombre usando Nominatim (OpenStreetMap).
///
/// A diferencia de un geocoder de solo ciudades, Nominatim devuelve PUNTOS DE
/// INTERES reales: universidades, restaurantes, cines, teatros, etc. Es gratis
/// y NO requiere API key. Solo sirve para ubicar coordenadas en el mapa; la
/// ubicacion definitiva se guarda en el backend Django como siempre.
///
/// Nota: la politica de uso de Nominatim exige un User-Agent identificable y un
/// maximo de ~1 peticion por segundo (por eso la busqueda es al enviar, no por
/// cada tecla). La cobertura depende de los datos de OpenStreetMap.
class GeocodingService {
  const GeocodingService({this.client});

  final http.Client? client;

  Future<List<GeoPlace>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final apiClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
        'addressdetails': '1',
        'accept-language': 'es',
        'countrycodes': 'gt', // limitar a Guatemala para resultados relevantes
      });
      final response = await apiClient.get(
        uri,
        headers: {'User-Agent': 'ClimatePlannerApp/1.0 (proyecto estudiantil)'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>().map(_placeFromJson).toList();
    } catch (_) {
      return [];
    } finally {
      if (shouldClose) apiClient.close();
    }
  }

  GeoPlace _placeFromJson(Map<String, dynamic> r) {
    final display = (r['display_name'] as String?) ?? '';
    final rawName = (r['name'] as String?)?.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (display.isNotEmpty ? display.split(',').first.trim() : 'Lugar');

    final address = (r['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parts = <String>[];
    for (final key in ['suburb', 'neighbourhood', 'city', 'town', 'village', 'county', 'state']) {
      final value = address[key];
      if (value is String && value.isNotEmpty && !parts.contains(value)) {
        parts.add(value);
      }
    }
    final region = parts.isNotEmpty ? parts.take(2).join(', ') : display;

    return GeoPlace(
      name: name,
      latitude: double.parse('${r['lat']}'),
      longitude: double.parse('${r['lon']}'),
      region: region,
    );
  }
}
