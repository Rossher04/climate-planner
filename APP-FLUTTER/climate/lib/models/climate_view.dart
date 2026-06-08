import 'package:flutter/material.dart';

enum ClimateView { summary, locations, activities, pending, statistics }

extension ClimateViewInfo on ClimateView {
  String get title {
    switch (this) {
      case ClimateView.summary:
        return 'Resumen';
      case ClimateView.locations:
        return 'Ubicaciones';
      case ClimateView.activities:
        return 'Actividades';
      case ClimateView.pending:
        return 'Pendientes';
      case ClimateView.statistics:
        return 'Estadística';
    }
  }

  IconData get icon {
    switch (this) {
      case ClimateView.summary:
        return Icons.dashboard_outlined;
      case ClimateView.locations:
        return Icons.location_on_outlined;
      case ClimateView.activities:
        return Icons.event_note_outlined;
      case ClimateView.pending:
        return Icons.pending_actions_outlined;
      case ClimateView.statistics:
        return Icons.show_chart_outlined;
    }
  }
}
