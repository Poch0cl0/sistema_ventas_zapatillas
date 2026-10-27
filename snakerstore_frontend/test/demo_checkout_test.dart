import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sneakerstore/features/store/demo_checkout_screen.dart';
import 'package:sneakerstore/features/store/store_repository.dart';

class FakeDemoRepository extends StoreRepository {
  FakeDemoRepository() : super(Dio());
  final List<Object?> requests = [];
  @override
  Future<Json> write(
    String method,
    String path, {
    Object? data,
    String? key,
  }) async {
    requests.add(data);
    return {
      'id': 'demo1',
      'orderId': 'order1',
      'testMode': true,
      'amountCents': 25990,
      'status': data is Map ? data['scenario'] : 'CREATED',
    };
  }
}

void main() {
  testWidgets(
    'checkout demo permite pendiente, rechazo y aprobación sin pedir datos de tarjetas',
    (tester) async {
      final repository = FakeDemoRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: DemoCheckoutScreen(orderId: 'order1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pasarela demo · Sin cobros reales'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('•••• 3155 · Dejar pendiente'));
      await tester.ensureVisible(find.text('Ejecutar pago de prueba'));
      await tester.tap(find.text('Ejecutar pago de prueba'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pago demo pendiente.'), findsOneWidget);
      await tester.ensureVisible(find.text('•••• 0002 · Rechazar'));
      await tester.tap(find.text('•••• 0002 · Rechazar'));
      await tester.ensureVisible(find.text('Ejecutar pago de prueba'));
      await tester.tap(find.text('Ejecutar pago de prueba'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pago demo rechazado.'), findsOneWidget);
      await tester.ensureVisible(find.text('•••• 4242 · Aprobar'));
      await tester.tap(find.text('•••• 4242 · Aprobar'));
      await tester.ensureVisible(find.text('Ejecutar pago de prueba'));
      await tester.tap(find.text('Ejecutar pago de prueba'));
      await tester.pumpAndSettle();
      expect(find.text('Pago demo aprobado'), findsOneWidget);
      expect(find.text('Ejecutar pago de prueba'), findsNothing);
      expect(repository.requests, [
        null,
        {'scenario': 'PENDING'},
        {'scenario': 'REJECTED'},
        {'scenario': 'APPROVED'},
      ]);
    },
  );
}
