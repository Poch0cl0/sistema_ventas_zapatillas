import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sneakerstore/preview/preview_state.dart';

void main() {
  test('El carrito combina producto y talla y elimina cantidades en cero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.add(sampleProducts.first, '40', 1);
    cart.add(sampleProducts.first, '40', 2);
    cart.add(sampleProducts.first, '41', 1);
    expect(container.read(cartProvider).length, 2);
    expect(container.read(cartProvider).first.quantity, 3);
    expect(container.read(cartProvider).first.total, 158700);
    cart.quantity('air-volt-40', 0);
    expect(container.read(cartProvider).single.size, '41');
  });

  test(
    'Un pago rechazado conserva vencimiento y admite reenvío dentro del plazo',
    () {
      final now = DateTime.now();
      final order = PreviewOrder(
        id: 'test',
        items: const [],
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      final rejected = order.copyWith(
        payment: PaymentState.rejected,
        rejection: 'Referencia incorrecta',
      );
      expect(rejected.expiresAt, order.expiresAt);
      expect(rejected.canPay, isTrue);
      expect(rejected.copyWith(stage: OrderStage.cancelled).canPay, isFalse);
      expect(rejected.copyWith(payment: PaymentState.approved).canPay, isFalse);
      final expired = PreviewOrder(
        id: 'old',
        items: const [],
        createdAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.subtract(const Duration(days: 1)),
      );
      expect(expired.canPay, isFalse);
    },
  );

  test('Las tarifas y precios se conservan como céntimos enteros', () {
    final now = DateTime.now();
    final order = PreviewOrder(
      id: 'test',
      items: [CartLine(sampleProducts.first, '40', 2)],
      createdAt: now,
      expiresAt: now,
      feeCents: 1500,
    );
    expect(order.total, 107300);
  });
}
