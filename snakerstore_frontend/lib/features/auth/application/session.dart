import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_failure.dart';
import '../data/auth_repository.dart';
import '../data/firebase_auth_gateway.dart';
import '../domain/auth_gateway.dart';
import '../domain/user_profile.dart';

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => FirebaseAuthGateway(FirebaseAuth.instance),
);
final apiClientProvider = Provider<Dio>((ref) {
  final client = createApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    auth: ref.watch(authGatewayProvider),
    onSessionExpired: (uid) {
      if (ref.mounted) {
        unawaited(ref.read(sessionProvider.notifier).expire(uid));
      }
    },
  );
  ref.onDispose(() => client.close());
  return client;
});
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

enum SessionStatus { loading, signedOut, authenticated, unavailable }

class SessionState {
  const SessionState(
    this.status, {
    this.profile,
    this.message,
    this.connectionIssue = false,
  });
  const SessionState.signedOut() : this(SessionStatus.signedOut);
  final SessionStatus status;
  final UserProfile? profile;
  final String? message;
  final bool connectionIssue;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  int _generation = 0;
  bool _busy = false;
  AuthGateway get _auth => ref.read(authGatewayProvider);
  @override
  SessionState build() {
    final subscription = ref
        .watch(authGatewayProvider)
        .userChanges
        .listen(
          (uid) {
            if (!_busy) unawaited(_resolve(uid));
          },
          onError: (Object error) {
            if (ref.mounted) {
              state = SessionState(
                SessionStatus.unavailable,
                message: errorMessage(error),
              );
            }
          },
        );
    ref.onDispose(() {
      _generation++;
      unawaited(subscription.cancel());
    });
    return const SessionState(SessionStatus.loading);
  }

  Future<void> _resolve(String? uid) async {
    final generation = ++_generation;
    if (uid == null) {
      state = const SessionState.signedOut();
      return;
    }
    state = const SessionState(SessionStatus.loading);
    try {
      final profile = await ref.read(authRepositoryProvider).me();
      if (!ref.mounted || generation != _generation || _auth.uid != uid) return;
      if (profile.uid != uid) {
        throw const AppFailure('No pudimos verificar la identidad del perfil.');
      }
      state = SessionState(SessionStatus.authenticated, profile: profile);
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = SessionState(
          SessionStatus.unavailable,
          message: errorMessage(error),
          connectionIssue:
              error is DioException &&
              ([
                    DioExceptionType.connectionError,
                    DioExceptionType.connectionTimeout,
                    DioExceptionType.receiveTimeout,
                    DioExceptionType.sendTimeout,
                  ].contains(error.type) ||
                  [502, 503, 504].contains(error.response?.statusCode)),
        );
      }
    }
  }

  Future<void> signIn(String email, String password) =>
      _authenticate(() => _auth.signIn(email, password));
  Future<void> register(String name, String email, String password) =>
      _authenticate(() => _auth.register(name, email, password));
  Future<void> _authenticate(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _generation++;
    try {
      await action();
      await _resolve(_auth.uid);
    } catch (_) {
      if (ref.mounted) state = const SessionState.signedOut();
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() => _resolve(_auth.uid);
  Future<void> signOut() async {
    // Drop the trusted role immediately, including during a late /auth/me response.
    _generation++;
    state = const SessionState.signedOut();
    await _auth.signOut();
  }

  Future<void> expire(String uid) async {
    if (_auth.uid != uid) return;
    try {
      await signOut();
    } catch (_) {
      /* No trusted role is kept if native sign-out fails. */
    }
  }
}
