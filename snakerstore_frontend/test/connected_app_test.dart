import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sneakerstore/app/app.dart';
import 'package:sneakerstore/core/network/api_page.dart';
import 'package:sneakerstore/features/auth/application/session.dart';
import 'package:sneakerstore/features/auth/auth_screen.dart';
import 'package:sneakerstore/features/auth/data/auth_repository.dart';
import 'package:sneakerstore/features/auth/data/firebase_auth_gateway.dart';
import 'package:sneakerstore/features/auth/domain/user_profile.dart';
import 'package:sneakerstore/features/catalog/catalog_repository.dart';
import 'package:sneakerstore/features/catalog/connected_catalog_screen.dart';
import 'package:sneakerstore/features/admin/connected_admin_screen.dart';

import 'support/fake_auth_gateway.dart';

class MockRepository extends Mock implements AuthRepository {}

class MockCatalog extends Mock implements CatalogRepository {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late FakeAuthGateway gateway;
  late MockRepository repository;
  late MockCatalog catalog;
  late ProviderContainer container;
  setUp(() {
    gateway = FakeAuthGateway();
    repository = MockRepository();
    catalog = MockCatalog();
    when(() => catalog.list(admin: false, after: null))
        .thenAnswer((_) async => const ApiPage([], null));
    when(() => catalog.list(admin: true, after: null))
        .thenAnswer((_) async => const ApiPage([], null));
    when(() => repository.me()).thenAnswer(
      (_) async => const UserProfile(
        uid: 'user-1',
        role: UserRole.client,
        name: 'Mi cliente',
        email: 'cliente@example.invalid',
      ),
    );
    container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(gateway),
        authRepositoryProvider.overrideWithValue(repository),
        catalogRepositoryProvider.overrideWithValue(catalog),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await gateway.dispose();
  });
  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SneakerStoreApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Login conectado consulta NestJS, abre catálogo y permite cerrar sesión',
    (tester) async {
      await start(tester);
      expect(find.text('Vista previa de administrador'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('email')),
        'cliente@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('password')),
        'only-for-tests',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(gateway.calls, contains('signIn'));
      expect(find.byType(ConnectedCatalogScreen), findsOneWidget);
      verify(() => repository.me()).called(1);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('cliente@example.invalid'), findsWidgets);
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(container.read(sessionProvider).profile, isNull);
      expect(gateway.calls, contains('signOut'));
    },
  );
  testWidgets(
    'La sesión restaurada de administrador abre su interfaz exclusiva',
    (tester) async {
      gateway.currentUid = 'user-1';
      when(() => repository.me()).thenAnswer(
        (_) async => const UserProfile(
          uid: 'user-1',
          role: UserRole.administrator,
          name: 'Mi administrador',
        ),
      );
      await start(tester);
      expect(find.byType(ConnectedAdminScreen), findsOneWidget);
      final router = GoRouter.of(
        tester.element(find.byType(ConnectedAdminScreen)),
      );
      router.go('/catalogo');
      await tester.pumpAndSettle();
      expect(find.byType(ConnectedAdminScreen), findsOneWidget);
      router.go('/admin/productos');
      await tester.pumpAndSettle();
      expect(find.byType(ConnectedCatalogScreen), findsOneWidget);
      verify(() => catalog.list(admin: true, after: null)).called(1);
    },
  );
  testWidgets(
    'Cliente no puede abrir rutas administrativas ni el modo de muestra',
    (tester) async {
      gateway.currentUid = 'user-1';
      await start(tester);
      final router = GoRouter.of(
        tester.element(find.byType(ConnectedCatalogScreen)),
      );
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(find.byType(ConnectedCatalogScreen), findsOneWidget);
      router.go('/preview/admin');
      await tester.pumpAndSettle();
      expect(find.byType(ConnectedAdminScreen), findsNothing);
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
    },
  );
  testWidgets('Recuperación envía correo con mensaje genérico', (tester) async {
    await start(tester);
    final router = GoRouter.of(tester.element(find.byType(AuthScreen)));
    router.go('/recuperar');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('email')),
      'cliente@example.invalid',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(gateway.calls, contains('reset'));
    expect(find.textContaining('Si el correo está registrado'), findsOneWidget);
  });
  test(
    'Firebase actualiza nombre y fuerza renovación antes de crear perfil',
    () async {
      final firebase = MockFirebaseAuth();
      final credential = MockCredential();
      final user = MockUser();
      when(
        () => firebase.createUserWithEmailAndPassword(
          email: 'cliente@example.invalid',
          password: 'only-for-tests',
        ),
      ).thenAnswer((_) async => credential);
      when(() => credential.user).thenReturn(user);
      when(() => user.updateDisplayName('Cliente')).thenAnswer((_) async {});
      when(() => user.getIdToken(true)).thenAnswer((_) async => 'test-token');
      await FirebaseAuthGateway(firebase)
          .register(' Cliente ', ' cliente@example.invalid ', 'only-for-tests');
      verifyInOrder([
        () => user.updateDisplayName('Cliente'),
        () => user.getIdToken(true),
      ]);
    },
  );
}
