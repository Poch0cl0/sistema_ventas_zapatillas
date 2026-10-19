import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sneakerstore/app/session_redirect.dart';
import 'package:sneakerstore/core/network/app_failure.dart';
import 'package:sneakerstore/features/auth/application/session.dart';
import 'package:sneakerstore/features/auth/data/auth_repository.dart';
import 'package:sneakerstore/features/auth/domain/user_profile.dart';

import 'support/fake_auth_gateway.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const client = UserProfile(
  uid: 'user-1',
  role: UserRole.client,
  name: 'Cliente',
);
const admin = UserProfile(
  uid: 'user-1',
  role: UserRole.administrator,
  name: 'Administrador',
);
Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuthGateway auth;
  late MockAuthRepository repository;
  late ProviderContainer container;
  setUp(() {
    auth = FakeAuthGateway();
    repository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await auth.dispose();
  });

  test(
    'Restaura la sesión y obtiene el rol exclusivamente de NestJS',
    () async {
      auth.currentUid = 'user-1';
      when(() => repository.me()).thenAnswer((_) async => admin);
      expect(container.read(sessionProvider).status, SessionStatus.loading);
      await flush();
      expect(container.read(sessionProvider).profile?.isAdmin, isTrue);
      expect(
        sessionRedirect(container.read(sessionProvider), '/login'),
        '/admin',
      );
      verify(() => repository.me()).called(1);
    },
  );
  test(
    'Registro espera la actualización de nombre antes de consultar el perfil',
    () async {
      when(() => repository.me()).thenAnswer((_) async {
        expect(auth.calls, contains('nameUpdated'));
        return client;
      });
      container.read(sessionProvider);
      await flush();
      await container
          .read(sessionProvider.notifier)
          .register('Cliente', 'cliente@example.invalid', 'only-for-tests');
      await flush();
      expect(
        container.read(sessionProvider).status,
        SessionStatus.authenticated,
      );
      verify(() => repository.me()).called(1);
    },
  );
  test(
    'Si NestJS falla, no se concede un rol y se permite reintentar',
    () async {
      auth.currentUid = 'user-1';
      when(() => repository.me()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          type: DioExceptionType.connectionError,
        ),
      );
      container.read(sessionProvider);
      await flush();
      expect(container.read(sessionProvider).status, SessionStatus.unavailable);
      expect(container.read(sessionProvider).profile, isNull);
      expect(auth.uid, 'user-1');
      when(() => repository.me()).thenAnswer((_) async => client);
      await container.read(sessionProvider.notifier).retry();
      expect(container.read(sessionProvider).profile?.role, UserRole.client);
    },
  );
  test(
    'Cerrar sesión descarta una respuesta tardía del perfil anterior',
    () async {
      auth.currentUid = 'user-1';
      final pending = Completer<UserProfile>();
      when(() => repository.me()).thenAnswer((_) => pending.future);
      container.read(sessionProvider);
      await flush();
      await container.read(sessionProvider.notifier).signOut();
      pending.complete(admin);
      await flush();
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(container.read(sessionProvider).profile, isNull);
    },
  );
  test(
    'Un perfil con uid ajeno o rol desconocido no habilita acceso',
    () async {
      expect(
        () => UserProfile.fromJson({'uid': 'x', 'role': 'ROOT'}),
        throwsA(isA<AppFailure>()),
      );
      auth.currentUid = 'user-1';
      when(() => repository.me()).thenAnswer(
        (_) async =>
            const UserProfile(uid: 'other-user', role: UserRole.administrator),
      );
      container.read(sessionProvider);
      await flush();
      expect(container.read(sessionProvider).status, SessionStatus.unavailable);
      expect(container.read(sessionProvider).profile, isNull);
    },
  );
  test(
    'Las rutas separan cliente y administrador y conservan catálogo público',
    () {
      const signedOut = SessionState.signedOut();
      expect(sessionRedirect(signedOut, '/catalogo'), isNull);
      expect(sessionRedirect(signedOut, '/admin'), '/login');
      expect(sessionRedirect(signedOut, '/perfil'), '/login');
      expect(
        sessionRedirect(
          const SessionState(SessionStatus.authenticated, profile: client),
          '/admin/productos',
        ),
        '/catalogo',
      );
      expect(
        sessionRedirect(
          const SessionState(SessionStatus.authenticated, profile: admin),
          '/catalogo',
        ),
        '/admin',
      );
      expect(
        sessionRedirect(
          const SessionState(SessionStatus.unavailable),
          '/admin',
        ),
        '/session',
      );
    },
  );
}
