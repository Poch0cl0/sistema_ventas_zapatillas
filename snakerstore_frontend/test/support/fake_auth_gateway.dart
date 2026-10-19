import 'dart:async';

import 'package:sneakerstore/features/auth/domain/auth_gateway.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.currentUid});
  String? currentUid;
  final changes = StreamController<String?>.broadcast();
  final calls = <String>[];
  bool refreshed = false;
  Object? signInError;
  @override
  String? get uid => currentUid;
  @override
  Stream<String?> get userChanges async* {
    yield uid;
    yield* changes.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn');
    if (signInError != null) throw signInError!;
    currentUid = 'user-1';
    changes.add(uid);
  }

  @override
  Future<void> register(String name, String email, String password) async {
    calls.add('register');
    currentUid = 'user-1';
    changes.add(uid);
    await Future<void>.delayed(Duration.zero);
    calls.add('nameUpdated');
  }

  @override
  Future<void> resetPassword(String email) async {
    calls.add('reset');
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    calls.add(forceRefresh ? 'refreshToken' : 'token');
    if (uid == null) return null;
    if (forceRefresh) refreshed = true;
    return refreshed ? 'test-fresh-token' : 'test-cached-token';
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    currentUid = null;
    changes.add(null);
  }

  Future<void> dispose() => changes.close();
}
