import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';
import '../widgets/climate_logo.dart';
import '../widgets/recovery_dialog.dart';
import '../widgets/surface_box.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: demoEmail);
  final passwordController = TextEditingController(text: demoPassword);
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (isLoading) return;
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => isLoading = true);

    try {
      final loggedIn = await widget.apiService.login(email, password);
      if (!mounted) return;

      if (loggedIn) {
        // Si el backend marca que la contrasena es temporal, obligamos al
        // usuario a cambiarla antes de entrar a la aplicacion.
        bool mustChange = false;
        try {
          final me = await widget.apiService.fetchMe();
          mustChange = me.temporaryPasswordRequired;
        } catch (_) {
          // Si falla la consulta de perfil, continuamos al home igualmente.
        }
        if (!mounted) return;
        if (mustChange) {
          Navigator.of(context).pushReplacementNamed(
            RouteNames.changePassword,
            arguments: true,
          );
        } else {
          Navigator.of(context).pushReplacementNamed(RouteNames.home);
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales incorrectas. Revisa correo y contraseña.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo conectar con el servidor: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ClimateLogo(size: 82),
                  const SizedBox(height: 22),
                  Text(
                    'Climate',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Planifica actividades según ubicación, clima y estadística.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      height: 1.5,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SurfaceBox(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.mail_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: login,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: Text(isLoading ? 'Conectando...' : 'Ingresar'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => RecoveryDialog(apiService: widget.apiService),
                    ),
                    icon: const Icon(Icons.key),
                    label: const Text('¿Olvidó su contraseña?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
