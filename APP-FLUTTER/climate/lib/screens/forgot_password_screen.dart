import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../themes/app_colors.dart';
import '../widgets/climate_logo.dart';
import '../widgets/surface_box.dart';

/// Recuperacion de contraseña: el usuario ingresa su correo y el backend
/// (`POST /api/auth/password-recovery/`) le envia una contraseña temporal.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool isSending = false;
  String? resultMessage;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (isSending) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      isSending = true;
      resultMessage = null;
    });
    try {
      final message =
          await widget.apiService.requestPasswordRecovery(emailController.text.trim());
      if (!mounted) return;
      setState(() => resultMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la recuperación: $e')),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  String? _validateEmail(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Ingresa tu correo.';
    if (!text.contains('@') || !text.contains('.')) return 'Correo no válido.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ClimateLogo(size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Ingresa el correo asociado a tu cuenta. Te enviaremos una '
                      'contraseña temporal para que recuperes el acceso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    SurfaceBox(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: isSending ? null : _send,
                            icon: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(isSending ? 'Enviando...' : 'Enviar recuperación'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (resultMessage != null) ...[
                      const SizedBox(height: 16),
                      SurfaceBox(
                        color: AppColors.background,
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                resultMessage!,
                                style: const TextStyle(color: AppColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
