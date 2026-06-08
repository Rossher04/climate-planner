/// Usuario autenticado, tal como lo expone `GET /api/users/me/`.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.temporaryPasswordRequired,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final bool temporaryPasswordRequired;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return AppUser(
      id: json['id'] as int,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? (profile?['phone'] as String?) ?? '',
      temporaryPasswordRequired:
          (profile?['temporary_password_required'] as bool?) ?? false,
    );
  }
}
