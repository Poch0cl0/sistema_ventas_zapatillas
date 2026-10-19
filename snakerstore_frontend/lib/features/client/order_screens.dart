import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String filter = 'Todos';
  @override
  Widget build(BuildContext context) {
    final orders = ref
        .watch(ordersProvider)
        .where(
          (o) =>
              filter == 'Todos' ||
              (filter == 'Pendientes' &&
                  o.payment != PaymentState.approved &&
                  o.stage != OrderStage.cancelled) ||
              (filter == 'Entregados' && o.stage == OrderStage.delivered) ||
              (filter == 'Cancelados' && o.stage == OrderStage.cancelled),
        )
        .toList();
    return StorePage(
      title: 'Mis pedidos',
      tab: 2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Heading(
            'Cada paso cuenta.',
            subtitle: 'Sigue tus pedidos de principio a fin.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final f in [
                'Todos',
                'Pendientes',
                'Entregados',
                'Cancelados',
              ])
                ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (orders.isEmpty)
            const EmptyState(
              'Sin pedidos por aquí',
              'Tus pedidos aparecerán en esta sección.',
            ),
          for (final order in orders) OrderCard(order: order),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.admin = false});
  final PreviewOrder order;
  final bool admin;
  @override
  Widget build(BuildContext context) => SheetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(order.id, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag(
              paymentLabel(order.payment),
              color: order.payment == PaymentState.approved
                  ? Colors.green.shade800
                  : orange,
            ),
            Tag(
              stageLabel(order.stage, delivery: order.delivery),
              color: muted,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          order.items
              .map((l) => '${l.product.name} · EU ${l.size} × ${l.quantity}')
              .join('\n'),
        ),
        const SizedBox(height: 8),
        Text(
          '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} · ${order.delivery ? 'Delivery' : 'Recojo en tienda'}',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        AmountRow('Total', order.total, bold: true),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push(
              admin
                  ? '/preview/admin/pedido/${order.id}'
                  : '/pedido/${order.id}',
            ),
            child: const Text('Ver detalle →'),
          ),
        ),
      ],
    ),
  );
}

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref
        .watch(ordersProvider)
        .where((o) => o.id == id)
        .firstOrNull;
    return StorePage(
      title: 'Seguimiento del pedido',
      child: order == null
          ? const EmptyState('Pedido no encontrado', 'Vuelve a Mis pedidos.')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Heading(order.id, subtitle: 'Tu pedido, paso a paso.'),
                OrderSummary(order: order),
                if (order.canPay)
                  FilledButton(
                    onPressed: () => context.push('/pago/$id'),
                    child: Text(
                      order.payment == PaymentState.rejected
                          ? 'Reenviar referencia'
                          : 'Completar pago',
                    ),
                  ),
                if (order.payment != PaymentState.approved &&
                    order.stage != OrderStage.cancelled)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('¿Cancelar pedido de ejemplo?'),
                          content: const Text(
                            'Se cancelará este pedido de la vista previa.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Volver'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Cancelar pedido'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        ref
                            .read(ordersProvider.notifier)
                            .save(order.copyWith(stage: OrderStage.cancelled));
                      }
                    },
                    child: const Text(
                      'Cancelar pedido',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                TextButton(
                  onPressed: () => context.go('/pedidos'),
                  child: const Text('Volver a mis pedidos'),
                ),
              ],
            ),
    );
  }
}

class OrderSummary extends StatelessWidget {
  const OrderSummary({super.key, required this.order});
  final PreviewOrder order;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SheetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado del pago',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Tag(paymentLabel(order.payment)),
            if (order.reference.isNotEmpty)
              Text('${order.method} · ${order.reference}'),
            if (order.rejection.isNotEmpty)
              InfoNote('Motivo de rechazo: ${order.rejection}'),
            if (order.expired &&
                order.payment != PaymentState.approved &&
                order.stage != OrderStage.cancelled)
              const InfoNote(
                'Reserva vencida. Cancelación pendiente de procesamiento manual.',
              ),
            if (order.stage == OrderStage.cancelled)
              const InfoNote('Pedido cancelado. No se permiten nuevos pagos.'),
          ],
        ),
      ),
      SheetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento de entrega',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            for (final stage in [
              OrderStage.pending,
              OrderStage.preparing,
              OrderStage.ready,
              OrderStage.delivered,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Icon(
                      order.stage != OrderStage.cancelled &&
                              order.stage.index >= stage.index
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          order.stage != OrderStage.cancelled &&
                              order.stage.index >= stage.index
                          ? ink
                          : muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stage == OrderStage.pending
                            ? 'Confirmación del pedido'
                            : stageLabel(stage, delivery: order.delivery),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      SheetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in order.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.product.name),
                subtitle: Text('EU ${line.size} · ${line.quantity} par(es)'),
                trailing: Text(money(line.total)),
              ),
            const Divider(),
            AmountRow('Subtotal', order.subtotal),
            AmountRow('Entrega', order.feeCents),
            AmountRow('Total', order.total, bold: true),
          ],
        ),
      ),
      SheetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.delivery ? 'Delivery · ${order.zone}' : 'Recojo en tienda',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(order.recipient),
            if (order.phone.isNotEmpty) Text(order.phone),
            if (order.delivery) Text(order.address),
            if (order.deliveryReference.isNotEmpty)
              Text(order.deliveryReference),
            if (!order.delivery)
              const InfoNote(
                'Dirección de recojo pendiente de conectar con la configuración de tienda.',
              ),
          ],
        ),
      ),
    ],
  );
}
