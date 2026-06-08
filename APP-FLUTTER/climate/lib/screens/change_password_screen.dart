import 'package:flutter/material.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';
import '../widgets/climate_logo.dart';
import '../widgets/surface_box.dart';

/// Cambio de contraseña con doble confirmacion.
/// - [forced] = true cuando el usuario ingresa con una contraseña temporal y
///   debe cambiarla obligatoriamente antes de continuar.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.apiService,
    this.forced = false,
  });

  final ApiService apiService;
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final oldController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();
  bool isSaving = false;
  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    oldController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (isSaving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => isSaving = true);
    try {
      await widget.apiService.changePassword(
        oldPassword: oldController.text,
        newPassword: newController.text,
        confirmPassword: confirmController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
      if (widget.forced) {
        Navigator.of(context).pushReplacementNamed(RouteNames.home);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar la contraseña: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String? _validateNew(String? v) {
    final text = v ?? '';
    if (text.length < 8) return 'Mínimo 8 caracteres.';
    if (text == oldController.text) return 'Debe ser distinta a la actual.';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '') != newController.text) return 'Las contraseñas no coinciden.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambiar contraseña'),
          automaticallyImplyLeading: !widget.forced,
        ),
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
                      if (widget.forced)
                        SurfaceBox(
                          color: AppColors.background,
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ingresaste con una contraseña temporal. '
                                  'Debes definir una nueva para continuar.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.forced) const SizedBox(height: 16),
                      SurfaceBox(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: oldController,
                              obscureText: obscureOld,
                              decoration: InputDecoration(
                                labelText: widget.forced
                                    ? 'Contraseña temporal actual'
                                    : 'Contraseña actual',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureOld
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () => setState(() => obscureOld = !obscureOld),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Ingresa la contraseña actual.' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: newController,
                              obscureText: obscureNew,
                              decoration: InputDecoration(
                                labelText: 'Nueva contraseña',
                                prefixIcon: const Icon(Icons.lock_reset),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureNew
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () => setState(() => obscureNew = !obscureNew),
                                ),
                              ),
                              validator: _validateNew,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: confirmController,
                              obscureText: obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Confirmar nueva contraseña',
                                prefixIcon: const Icon(Icons.check_circle_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () =>
                                      setState(() => obscureConfirm = !obscureConfirm),
                                ),
                              ),
                              validator: _validateConfirm,
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: isSaving ? null : _save,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(isSaving ? 'Guardando...' : 'Guardar contraseña'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
