import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sneakerstore/app/app.dart';
import 'package:sneakerstore/features/auth/auth_screen.dart';
import 'package:sneakerstore/preview/preview_state.dart';

void main() {
  testWidgets('Aprobar un pago de ejemplo habilita preparación y entrega', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SneakerStoreApp(preview: true),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(AuthScreen)));
    router.go('/preview/admin/pedido/SK-84920');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Aprobar pago de ejemplo'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Aprobar pago de ejemplo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprobar pago de ejemplo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    var order = container
        .read(ordersProvider)
        .firstWhere((o) => o.id == 'SK-84920');
    expect(order.payment, PaymentState.approved);
    expect(order.stage, OrderStage.preparing);
    await tester.scrollUntilVisible(
      find.text('Marcar listo para recojo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Marcar listo para recojo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar listo para recojo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Marcar entregado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar entregado'));
    await tester.pumpAndSettle();
    order = container
        .read(ordersProvider)
        .firstWhere((o) => o.id == 'SK-84920');
    expect(order.stage, OrderStage.delivered);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El menú permite revisar carga y error sin enviar credenciales', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SneakerStoreApp(preview: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previsualizar estados del formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargando'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-submit')))
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Previsualizar estados del formulario'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Error').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Estado de ejemplo: no pudimos'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
