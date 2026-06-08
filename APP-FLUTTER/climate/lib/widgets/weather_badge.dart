import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Badge del header con la temperatura ACTUAL real (OpenWeatherMap via backend).
/// - [loading] true mientras se consulta el clima.
/// - [temperature] null si aun no hay dato o no se pudo obtener.
class WeatherBadge extends StatelessWidget {
  const WeatherBadge({super.key, this.temperature, this.loading = false});

  final double? temperature;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (loading) {
      trailing = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
      );
    } else {
      trailing = Text(
        temperature != null ? '${temperature!.round()} C' : '--',
        style: const TextStyle(fontWeight: FontWeight.w900),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_cloudy_outlined, size: 18, color: AppColors.blue),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    );
  }
}

