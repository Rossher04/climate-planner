import 'package:flutter/material.dart';

import '../models/climate_view.dart';
import '../themes/app_colors.dart';
import 'climate_logo.dart';

class ClimateDrawer extends StatelessWidget {
  const ClimateDrawer({
    super.key,
    required this.selectedView,
    required this.onSelected,
    required this.onProfile,
    required this.onLogout,
  });

  final ClimateView selectedView;
  final ValueChanged<ClimateView> onSelected;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  ClimateLogo(size: 48),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Climate',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Planificador Inteligente',
                          style: TextStyle(color: Color(0xFFBDD4DD)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final view in ClimateView.values)
              ListTile(
                selected: selectedView == view,
                selectedTileColor: Colors.white,
                iconColor: selectedView == view ? AppColors.blue : Colors.white70,
                textColor: selectedView == view ? AppColors.ink : Colors.white,
                leading: Icon(view.icon),
                title: Text(view.title),
                onTap: () => onSelected(view),
              ),
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              iconColor: Colors.white70,
              textColor: Colors.white,
              leading: const Icon(Icons.person_outline),
              title: const Text('Mi perfil'),
              onTap: onProfile,
            ),
            ListTile(
              iconColor: const Color(0xFFB8DFF5),
              textColor: const Color(0xFFB8DFF5),
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
