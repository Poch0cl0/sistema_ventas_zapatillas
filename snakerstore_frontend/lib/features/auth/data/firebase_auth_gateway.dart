import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_gateway.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this.auth);
  final FirebaseAuth auth;
  @override
  String? get uid => auth.currentUser?.uid;
  @override
  Stream<String?> get userChanges =>
      auth.authStateChanges().map((user) => user?.uid).distinct();
  @override
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> register(String name, String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    // /auth/me creates the profile from this refreshed, verified name claim.
    await credential.user!.getIdToken(true);
  }

  @override
  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      auth.currentUser?.getIdToken(forceRefresh);
  @override
  Future<void> signOut() => auth.signOut();
}
