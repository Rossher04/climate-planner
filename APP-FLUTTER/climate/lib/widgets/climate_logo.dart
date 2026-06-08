import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

class ClimateLogo extends StatelessWidget {
  const ClimateLogo({super.key, required this.size});

  static const _asset = 'lib/logos/Minimalist Cloud Logo - Calm Colors.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _asset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          'CL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }
}
