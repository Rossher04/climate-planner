import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../themes/app_colors.dart';

/// Modal de recuperacion de contrasena (modo academico, sin SMTP):
///   1) El usuario ingresa su correo registrado.
///   2) El backend asigna una contrasena TEMPORAL y la app la muestra.
/// Luego el usuario inicia sesion con esa temporal y la app lo obliga a
/// cambiarla (pantalla de cambio con doble confirmacion) -> cumple el enunciado.
class RecoveryDialog extends StatefulWidget {
  const RecoveryDialog({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<RecoveryDialog> {
  final emailController = TextEditingController();
  bool isLoading = false;
  String? tempPassword;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _msg('Ingresa un correo válido.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final data = await widget.apiService.startPasswordRecovery(email);
      final temp = data['temporary_password'] as String?;
      if (temp == null || temp.isEmpty) {
        throw Exception(data['error']?.toString() ?? 'No se pudo recuperar la cuenta.');
      }
      if (!mounted) return;
      setState(() => tempPassword = temp);
    } catch (e) {
      _msg('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final hasTemp = tempPassword != null;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.key_outlined, color: AppColors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Recuperar contraseña')),
        ],
      ),
      content: hasTemp ? _resultStep() : _emailStep(),
      actions: hasTemp
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                child: const Text('Entendido'),
              ),
            ]
          : [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: isLoading ? null : _request,
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continuar'),
              ),
            ],
    );
  }

  Widget _emailStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Ingresa el correo registrado de tu cuenta. Te asignaremos una '
          'contraseña temporal.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.mail_outline),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _resultStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tu contraseña temporal es:', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  tempPassword!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copiar',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tempPassword!));
                  _msg('Contraseña copiada.');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Inicia sesión con esta contraseña; la app te pedirá crear una nueva.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}
