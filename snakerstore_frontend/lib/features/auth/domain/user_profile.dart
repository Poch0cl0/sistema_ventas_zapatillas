import '../../../core/network/app_failure.dart';

enum UserRole { client, administrator }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.role,
    this.email,
    this.name,
  });
  final String uid;
  final String? email, name;
  final UserRole role;
  bool get isAdmin => role == UserRole.administrator;
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final role = switch (json['role']) {
      'CLIENTE' => UserRole.client,
      'ADMINISTRADOR' => UserRole.administrator,
      _ => throw const AppFailure(
        'El perfil no tiene un rol autorizado. Contacta a la tienda.',
      ),
    };
    if (json['uid'] is! String || (json['uid'] as String).isEmpty) {
      throw const AppFailure(
        'No pudimos verificar tu perfil. Inténtalo nuevamente.',
      );
    }
    return UserProfile(
      uid: json['uid'] as String,
      role: role,
      email: json['email'] as String?,
      name: json['name'] as String?,
    );
  }
}
