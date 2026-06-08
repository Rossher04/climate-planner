const demoEmail = 'estudiante@universidad.edu';
const demoPassword = 'Climate2026!';

// Permite forzar la URL en tiempo de compilacion:
//   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000/api
const _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// URL base de la API de Django.
/// - Web / Windows / iOS simulador: 127.0.0.1
/// - Emulador Android: 10.0.2.2 (alias del localhost del PC anfitrion)
/// - Dispositivo fisico: usa --dart-define con la IP LAN del PC.
String get apiBaseUrl {
  if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
  // Backend en la nube (Render): la app funciona SIN CABLE desde cualquier red.
  // Para desarrollo local, compila con --dart-define, por ejemplo:
  //   --dart-define=API_BASE_URL=http://127.0.0.1:8000/api  (fisico + adb reverse)
  //   --dart-define=API_BASE_URL=http://10.0.2.2:8000/api   (emulador Android)
  return 'https://climate-planner-api-3hkr.onrender.com/api';
}

const openWeatherApiKey = String.fromEnvironment(
  'OPENWEATHER_API_KEY',
  defaultValue: '3df972607649687e30d5f09838e16565',
);
const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
