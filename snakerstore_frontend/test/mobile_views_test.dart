import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sneakerstore/app/app.dart';
import 'package:sneakerstore/features/auth/auth_screen.dart';
import 'package:sneakerstore/preview/preview_state.dart';

void main() {
  Future<GoRouter> start(
    WidgetTester tester, {
    double width = 360,
    ProviderContainer? container,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      container == null
          ? const ProviderScope(child: SneakerStoreApp(preview: true))
          : UncontrolledProviderScope(
              container: container,
              child: const SneakerStoreApp(preview: true),
            ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(AuthScreen)));
  }

  testWidgets('Login valida correo y contraseña sin simular autenticación', (
    tester,
  ) async {
    await start(tester);
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Usa al menos 6 caracteres'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('email')),
      'persona@example.com',
    );
    await tester.enterText(find.byKey(const Key('password')), 'ejemplo123');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firebase y NestJS todavía'), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Las pantallas navegan sin errores a ${width.toInt()} px', (
      tester,
    ) async {
      final router = await start(tester, width: width);
      for (final route in [
        '/registro',
        '/recuperar',
        '/catalogo',
        '/producto/air-volt',
        '/carrito',
        '/checkout',
        '/pedidos',
        '/pedido/SK-84920',
        '/pago/SK-84920',
        '/perfil',
        '/preview/admin',
        '/preview/admin/productos',
        '/preview/admin/producto/nuevo',
        '/preview/admin/producto/air-volt',
        '/preview/admin/inventario',
        '/preview/admin/pedidos',
        '/preview/admin/pedido/SK-84920',
        '/preview/admin/zonas',
        '/preview/admin/perfil',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Error en $route a $width px',
        );
      }
    });
  }

  testWidgets(
    'Checkout exige destinatario y crea pedido local con referencia en revisión',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).add(sampleProducts.first, '40', 1);
      final router = await start(tester, container: container);
      router.go('/checkout');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Crear pedido de ejemplo'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Crear pedido de ejemplo'));
      await tester.pumpAndSettle();
      expect(container.read(ordersProvider).length, 2);
      expect(tester.takeException(), isNull);
      // Pickup allows previewing checkout without entering real recipient details.
      await tester.scrollUntilVisible(
        find.text('Recojo'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Recojo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Crear pedido de ejemplo'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Crear pedido de ejemplo'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(ordersProvider).first.total, 52900);
      expect(
        container.read(ordersProvider).first.payment,
        PaymentState.pending,
      );
      await tester.scrollUntilVisible(
        find.text('Simular envío a revisión'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Simular envío a revisión'));
      await tester.pumpAndSettle();
      expect(find.text('Completa este campo'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'DEMO-123456');
      await tester.ensureVisible(find.text('Simular envío a revisión'));
      await tester.tap(find.text('Simular envío a revisión'));
      await tester.pumpAndSettle();
      expect(container.read(ordersProvider).first.payment, PaymentState.review);
      expect(container.read(ordersProvider).first.reference, 'DEMO-123456');
      expect(tester.takeException(), isNull);
    },
  );
}
