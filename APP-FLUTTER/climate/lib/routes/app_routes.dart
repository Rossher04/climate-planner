import 'package:flutter/material.dart';

import '../screens/change_password_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../services/api_service.dart';
import 'route_names.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings, ApiService apiService) {
    switch (settings.name) {
      case RouteNames.home:
        return MaterialPageRoute(builder: (_) => HomeShell(apiService: apiService));
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => LoginScreen(apiService: apiService));
      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => ProfileScreen(apiService: apiService));
      case RouteNames.changePassword:
        final forced = settings.arguments is bool ? settings.arguments as bool : false;
        return MaterialPageRoute(
          builder: (_) => ChangePasswordScreen(apiService: apiService, forced: forced),
        );
      case RouteNames.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => ForgotPasswordScreen(apiService: apiService),
        );
      case RouteNames.splash:
      default:
        return MaterialPageRoute(builder: (_) => SplashScreen(apiService: apiService));
    }
  }
}
