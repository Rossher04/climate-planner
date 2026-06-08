import 'package:flutter/material.dart';

import '../models/activity.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.label});

  final ActivityStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      ActivityStatus.recommended => (
        text: label ?? 'Realizar',
        background: const Color(0xFFDFF3EB),
        foreground: const Color(0xFF176948),
      ),
      ActivityStatus.possible => (
        text: label ?? 'Posible',
        background: const Color(0xFFD6EEF6),
        foreground: const Color(0xFF1F6E8C),
      ),
      ActivityStatus.reschedule => (
        text: label ?? 'Reagendar',
        background: const Color(0xFFE0E3F5),
        foreground: const Color(0xFF3F4BA8),
      ),
      ActivityStatus.finished => (
        text: label ?? 'Finalizada',
        background: const Color(0xFFE3E8EC),
        foreground: const Color(0xFF44525C),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.text,
        style: TextStyle(
          color: data.foreground,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
