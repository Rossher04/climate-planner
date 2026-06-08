import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import 'surface_box.dart';

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
