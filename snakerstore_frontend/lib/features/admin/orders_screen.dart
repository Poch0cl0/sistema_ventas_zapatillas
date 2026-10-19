import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../client/order_screens.dart';

class AdminOrders extends ConsumerStatefulWidget {
  const AdminOrders({super.key});
  @override
  ConsumerState<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends ConsumerState<AdminOrders> {
  String query = '', filter = 'Todos', delivery = 'Todos';
  @override
  Widget build(BuildContext context) {
    final orders = ref
        .watch(ordersProvider)
        .where(
          (o) =>
              o.id.toLowerCase().contains(query.toLowerCase()) &&
              (filter == 'Todos' ||
                  (filter == 'Por verificar' &&
                      o.payment == PaymentState.review &&
                      o.stage != OrderStage.cancelled) ||
                  (filter == 'Aprobados' &&
                      o.payment == PaymentState.approved) ||
                  (filter == 'Cancelados' &&
                      o.stage == OrderStage.cancelled)) &&
              (delivery == 'Todos' ||
                  (delivery == 'Delivery' ? o.delivery : !o.delivery)),
        )
        .toList();
    return StorePage(
      title: 'Pedidos online',
      admin: true,
      tab: 3,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Heading(
            'Del pedido al destino.',
            subtitle: 'Gestiona pagos y preparación por separado.',
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por código',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final f in [
                'Todos',
                'Por verificar',
                'Aprobados',
                'Cancelados',
              ])
                ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: delivery,
            decoration: const InputDecoration(
              labelText: 'Modalidad de entrega',
            ),
            items: [
              for (final d in ['Todos', 'Delivery', 'Recojo'])
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) => setState(() => delivery = v!),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Procesar vencimientos de ejemplo'),
                  content: const Text(
                    'Se cancelarán manualmente los pedidos de ejemplo vencidos sin pago aprobado.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Volver'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Procesar'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) {
                return;
              }
              final expired = ref
                  .read(ordersProvider)
                  .where(
                    (o) =>
                        o.expired &&
                        o.payment != PaymentState.approved &&
                        o.stage != OrderStage.cancelled,
                  )
                  .toList();
              for (final o in expired) {
                ref
                    .read(ordersProvider.notifier)
                    .save(o.copyWith(stage: OrderStage.cancelled));
              }
              if (context.mounted) {
                notice(
                  context,
                  '${expired.length} pedidos de ejemplo cancelados por vencimiento',
                );
              }
            },
            icon: const Icon(Icons.schedule),
            label: const Text('Procesar vencimientos · ejemplo'),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const EmptyState(
              'Sin pedidos',
              'No hay pedidos para estos filtros.',
            ),
          for (final o in orders) OrderCard(order: o, admin: true),
        ],
      ),
    );
  }
}
