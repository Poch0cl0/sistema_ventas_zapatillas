import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'product_image.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  String? size;
  int quantity = 1;
  @override
  Widget build(BuildContext context) {
    final p = ref
        .watch(productsProvider)
        .where((p) => p.id == widget.id && p.active)
        .firstOrNull;
    if (p == null) {
      return const StorePage(
        title: 'Producto',
        child: EmptyState(
          'Producto no disponible',
          'Vuelve al catálogo para explorar otros modelos.',
        ),
      );
    }
    final stock = ref.watch(inventoryProvider);
    final available = size == null ? 0 : stock['${p.id}-$size'] ?? 0;
    return StorePage(
      title: 'Detalle del producto',
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: size == null || available < quantity
              ? null
              : () {
                  ref.read(cartProvider.notifier).add(p, size!, quantity);
                  notice(context, 'Agregado al carrito de ejemplo');
                },
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(
            size == null
                ? 'Selecciona tu talla'
                : 'Agregar · ${money(p.priceCents * quantity)}',
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ProductImage(p, height: 300),
          const SizedBox(height: 20),
          Tag(p.brand.toUpperCase(), color: ink),
          const SizedBox(height: 12),
          Heading(p.name, subtitle: '${p.category} · Colección urbana'),
          Text(
            money(p.priceCents),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(p.description),
          const SizedBox(height: 24),
          const Text(
            'ELIGE TU TALLA · EU',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .7),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ['38', '39', '40', '41', '42', '43'])
                ChoiceChip(
                  label: Text(s),
                  selected: size == s,
                  onSelected: (stock['${p.id}-$s'] ?? 0) == 0
                      ? null
                      : (_) => setState(() {
                          size = s;
                          quantity = 1;
                        }),
                ),
            ],
          ),
          InfoNote(
            size == null
                ? 'Las tallas deshabilitadas no tienen stock.'
                : '$available unidades disponibles en la vista previa.',
            icon: Icons.inventory_2_outlined,
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cantidad',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Reducir cantidad',
                onPressed: quantity > 1
                    ? () => setState(() => quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$quantity'),
              IconButton(
                tooltip: 'Aumentar cantidad',
                onPressed: quantity < available && quantity < 9
                    ? () => setState(() => quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          OutlinedButton(
            onPressed: () => context.push('/carrito'),
            child: const Text('Ver mi carrito'),
          ),
          const InfoNote(
            'El precio y las existencias finales se validan en el servidor al confirmar.',
          ),
        ],
      ),
    );
  }
}
