import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 10,
            backgroundColor: const Color(0xFFE7EEF1),
            color: AppColors.green,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score%',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                ),
                const Text(
                  'realizable',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
