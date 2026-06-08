import 'dart:async';

import 'package:flutter/material.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';
import '../widgets/climate_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1600), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final next = widget.apiService.isAuthenticated ? RouteNames.home : RouteNames.login;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const ClimateLogo(size: 110),
            ),
            const SizedBox(height: 24),
            const Text(
              'Climate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Planificador Inteligente de Actividades',
              style: TextStyle(color: Color(0xFFBDD4DD), fontSize: 14),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
