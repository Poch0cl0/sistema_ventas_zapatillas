import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sneakerstore/features/admin/sales_chart.dart';
import 'package:sneakerstore/features/catalog/catalog_repository.dart';
import 'package:sneakerstore/features/catalog/product_attributes.dart';

void main() {
  test('ventas agrupa por día peruano, excluye demo, pendientes y fechas fuera del rango', () {
    final values = salesByDay(
      [
        {
          'paymentStatus': 'APROBADO',
          'totalCents': 1000,
          'createdAt': '2026-10-27T04:59:00Z',
        },
        {
          'paymentStatus': 'APROBADO',
          'totalCents': 500,
          'createdAt': '2026-10-26T12:00:00Z',
          'approvedAt': '2026-10-27T05:00:00Z',
        },
        {
          'paymentStatus': 'APROBADO',
          'isSimulation': true,
          'totalCents': 99999,
          'createdAt': '2026-10-27T12:00:00Z',
        },
        {
          'paymentStatus': 'PENDIENTE',
          'totalCents': 99999,
          'createdAt': '2026-10-27T12:00:00Z',
        },
        {
          'paymentStatus': 'APROBADO',
          'totalCents': 99999,
          'createdAt': '2026-09-01T12:00:00Z',
        },
      ],
      7,
      DateTime.parse('2026-10-27T15:00:00Z'),
    );
    expect(values.length, 7);
    expect(values[5].cents, 1000);
    expect(values[6].cents, 500);
    expect(values.fold<int>(0, (sum, v) => sum + v.cents), 1500);
  });
  test('productos antiguos se leen sin inventar un género ni colores', () {
    final product = CatalogProduct.fromJson({
      'id': 'a',
      'name': 'Modelo',
      'brand': 'Marca',
      'category': 'Urbano',
      'description': 'Demo',
      'priceCents': 1000,
      'active': true,
    });
    expect(product.gender, 'SIN_ESPECIFICAR');
    expect(product.colors, isEmpty);
  });
  testWidgets(
    'gráfico y etiquetas de colores se adaptan a una pantalla pequeña',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                SalesChart([]),
                ProductColorLabels(['BLANCO', 'AZUL']),
              ],
            ),
          ),
        ),
      );
      expect(
        find.text('Sin ventas aprobadas en este período.'),
        findsOneWidget,
      );
      await tester.tap(find.text('90 días'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Azul'), findsOneWidget);
    },
  );
}
