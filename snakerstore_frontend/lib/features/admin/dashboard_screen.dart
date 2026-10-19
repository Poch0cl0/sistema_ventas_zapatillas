import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_navigation.dart';
import '../client/order_screens.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final orders = ref.watch(ordersProvider);
    final inventory = ref.watch(inventoryProvider);
    final review = orders
        .where(
          (o) =>
              o.payment == PaymentState.review &&
              o.stage != OrderStage.cancelled,
        )
        .toList();
    final low = inventory.entries.where((e) => e.value <= 2).length;
    return StorePage(
      title: 'SNEAKERSTORE · ADMIN',
      admin: true,
      tab: 0,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Heading(
            'Todo bajo control.',
            subtitle: 'Pedidos online, catálogo e inventario.',
          ),
          LayoutBuilder(
            builder: (_, box) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [
                  (
                    Icons.receipt_long_outlined,
                    '${orders.length}',
                    'Pedidos online',
                    '$adminRoot/pedidos',
                  ),
                  (
                    Icons.fact_check_outlined,
                    '${review.length}',
                    'Pagos por verificar',
                    '$adminRoot/pedidos',
                  ),
                  (
                    Icons.inventory_2_outlined,
                    '${products.where((p) => p.active).length}',
                    'Productos activos',
                    '$adminRoot/productos',
                  ),
                  (
                    Icons.warning_amber_rounded,
                    '$low',
                    'Tallas con stock bajo',
                    '$adminRoot/inventario',
                  ),
                ])
                  SizedBox(
                    width: (box.maxWidth - 12) / 2,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => context.go(item.$4),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(item.$1, color: const Color(0xFFAB3500)),
                              const SizedBox(height: 14),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.$3,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('$adminRoot/producto/nuevo'),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo producto'),
          ),
          const SizedBox(height: 24),
          const Heading(
            'Pagos por revisar',
            subtitle: 'La aprobación siempre requiere verificación manual.',
          ),
          if (review.isEmpty)
            const SheetCard(
              child: Text('No hay pagos pendientes de revisión.'),
            ),
          for (final o in review) OrderCard(order: o, admin: true),
          const Heading('Accesos rápidos'),
          SheetCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Revisar inventario'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('$adminRoot/inventario'),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Zonas y tarifas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('$adminRoot/zonas'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
