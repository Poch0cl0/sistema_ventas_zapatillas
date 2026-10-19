import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'product_image.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    return StorePage(
      title: 'Mi carrito',
      tab: 1,
      bottom: lines.isEmpty
          ? null
          : SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/checkout'),
                child: const Text('Previsualizar checkout →'),
              ),
            ),
      child: lines.isEmpty
          ? EmptyState(
              'Tu próximo par te espera',
              'Explora el catálogo y agrega tus favoritos.',
              action: () => context.go('/catalogo'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Heading(
                  'Buen gusto.',
                  subtitle:
                      '${lines.fold(0, (n, l) => n + l.quantity)} pares en tu carrito',
                ),
                for (final line in lines)
                  SheetCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 85,
                              child: ProductImage(line.product, height: 85),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'EU ${line.size} · ${line.product.brand}',
                                    style: const TextStyle(color: muted),
                                  ),
                                  Text(
                                    money(line.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Eliminar producto',
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .quantity(line.key, 0),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Disminuir',
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .quantity(line.key, line.quantity - 1),
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${line.quantity}'),
                            IconButton(
                              tooltip: 'Aumentar',
                              onPressed: line.quantity >= 9
                                  ? null
                                  : () => ref
                                        .read(cartProvider.notifier)
                                        .quantity(line.key, line.quantity + 1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                SheetCard(
                  child: Column(
                    children: [
                      AmountRow(
                        'Subtotal estimado',
                        lines.fold(0, (sum, l) => sum + l.total),
                        bold: true,
                      ),
                      const InfoNote(
                        'El carrito no reserva existencias. Delivery y total se validarán al confirmar.',
                      ),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('Iniciar sesión para comprar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
