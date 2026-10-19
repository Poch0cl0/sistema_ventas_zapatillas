abstract interface class AuthGateway {
  String? get uid;
  Stream<String?> get userChanges;
  Future<void> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> resetPassword(String email);
  Future<String?> idToken({bool forceRefresh = false});
  Future<void> signOut();
}
