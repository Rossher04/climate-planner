/// Resumen estadistico calculado en el backend Django para una actividad.
///
/// Contiene los tres bloques exigidos por el enunciado de Estadistica:
/// - Tendencia central (media, mediana, moda) sobre la serie de 7 dias.
/// - Regresion lineal (pendiente e intercepto) para la tendencia de temperatura.
/// - Probabilidad bayesiana de lluvia y probabilidad de realizacion del evento.
///
/// IMPORTANTE: estos valores provienen del servidor; Flutter NO los recalcula.
class ActivityStatistics {
  const ActivityStatistics({
    required this.meanTemperature,
    required this.medianTemperature,
    required this.modeTemperature,
    required this.temperatureSeries,
    required this.regressionSlope,
    required this.regressionIntercept,
    required this.trend,
    required this.bayesRainProbability,
    required this.realizationProbability,
    required this.recommendation,
  });

  final double meanTemperature;
  final double medianTemperature;
  final double modeTemperature;
  final List<double> temperatureSeries;
  final double regressionSlope;
  final double regressionIntercept;
  final String trend;
  final double bayesRainProbability;
  final double realizationProbability;
  final String recommendation;

  static ActivityStatistics? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    double parse(dynamic value) => double.tryParse('$value') ?? 0;

    final rawSeries = json['temperature_series'];
    final series = rawSeries is List
        ? rawSeries.map((e) => double.tryParse('$e') ?? 0.0).toList()
        : <double>[];

    return ActivityStatistics(
      meanTemperature: parse(json['mean_temperature']),
      medianTemperature: parse(json['median_temperature']),
      modeTemperature: parse(json['mode_temperature']),
      temperatureSeries: series,
      regressionSlope: parse(json['regression_slope']),
      regressionIntercept: parse(json['regression_intercept']),
      trend: (json['trend'] as String?) ?? 'stable',
      bayesRainProbability: parse(json['bayes_rain_probability']),
      realizationProbability: parse(json['realization_probability']),
      recommendation: (json['recommendation'] as String?) ?? 'review',
    );
  }

  /// Etiqueta legible de la tendencia para mostrar en la UI.
  String get trendLabel {
    switch (trend) {
      case 'warming':
        return 'Calentamiento';
      case 'cooling':
        return 'Enfriamiento';
      default:
        return 'Estable';
    }
  }
}
