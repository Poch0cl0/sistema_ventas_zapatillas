import 'package:dio/dio.dart';

import '../domain/user_profile.dart';

class AuthRepository {
  AuthRepository(this.api);
  final Dio api;
  Future<UserProfile> me() async {
    final response = await api.get<Map<String, dynamic>>('/auth/me');
    return UserProfile.fromJson(response.data!);
  }
}
