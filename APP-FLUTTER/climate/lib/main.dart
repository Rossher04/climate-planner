import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'services/api_service.dart';
import 'themes/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = ApiService();
  await apiService.restoreSession();

  runApp(ClimateApp(apiService: apiService));
}

class ClimateApp extends StatelessWidget {
  const ClimateApp({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Climate',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      initialRoute: RouteNames.splash,
      onGenerateRoute: (settings) => AppRoutes.generateRoute(settings, apiService),
    );
  }
}
