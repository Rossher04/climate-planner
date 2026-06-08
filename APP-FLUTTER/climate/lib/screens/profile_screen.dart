import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';
import '../widgets/surface_box.dart';

/// Perfil del usuario autenticado.
/// Carga los datos reales desde `GET /api/users/me/` y permite editar
/// nombre, apellido, correo y telefono via `PATCH /api/users/me/`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? loadError;
  AppUser? user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final fetched = await widget.apiService.fetchMe();
      if (!mounted) return;
      setState(() {
        user = fetched;
        firstNameController.text = fetched.firstName;
        lastNameController.text = fetched.lastName;
        emailController.text = fetched.email;
        phoneController.text = fetched.phone;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = '$e';
        isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (isSaving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => isSaving = true);
    try {
      final updated = await widget.apiService.updateProfile(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() => user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  String? _validateRequired(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return 'Ingresa $label.';
    return null;
  }

  String? _validateEmail(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Ingresa el correo.';
    if (!text.contains('@') || !text.contains('.')) return 'Correo no válido.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? _buildError()
                : _buildForm(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el perfil.\n$loadError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                SurfaceBox(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => _validateRequired(v, 'el nombre'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => _validateRequired(v, 'el apellido'),
                      ),
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
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
                        label: Text(isSaving ? 'Guardando...' : 'Guardar cambios'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    RouteNames.changePassword,
                  ),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Cambiar contraseña'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final username = user?.username ?? '';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.blue,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Text(
                'Cuenta de Climate Planner',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
