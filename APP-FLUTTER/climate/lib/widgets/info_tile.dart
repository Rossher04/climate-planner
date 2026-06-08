import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../themes/app_colors.dart';
import 'status_chip.dart';
import 'surface_box.dart';

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
  });

  final ActivityStatus status;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(status: status),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
