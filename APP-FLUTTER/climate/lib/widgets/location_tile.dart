import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import 'surface_box.dart';

class LocationTile extends StatelessWidget {
  const LocationTile({
    super.key,
    required this.color,
    required this.title,
    required this.coordinates,
    required this.subtitle,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Color color;
  final String title;
  final String coordinates;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SurfaceBox(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_outlined, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coordinates,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.muted),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Eliminar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
