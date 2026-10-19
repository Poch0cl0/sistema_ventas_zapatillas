import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../client/order_screens.dart';

class AdminOrderScreen extends ConsumerWidget {
  const AdminOrderScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref
        .watch(ordersProvider)
        .where((o) => o.id == id)
        .firstOrNull;
    if (order == null) {
      return const StorePage(
        title: 'Pedido',
        admin: true,
        child: EmptyState(
          'Pedido no encontrado',
          'Regresa al listado administrativo.',
        ),
      );
    }
    return StorePage(
      title: 'Detalle de pedido',
      admin: true,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Heading(order.id, subtitle: order.recipient),
          OrderSummary(order: order),
          if (order.payment == PaymentState.review &&
              order.stage != OrderStage.cancelled &&
              !order.expired)
            SheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revisión manual del pago',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const InfoNote(
                    'Comprueba el ingreso del dinero antes de aprobar. Esta vista solo modifica datos de ejemplo.',
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('¿Aprobar pago de ejemplo?'),
                          content: const Text(
                            'El pago quedará aprobado y el pedido pasará a preparación en la vista previa.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Aprobar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final current = ref
                            .read(ordersProvider)
                            .firstWhere((o) => o.id == id);
                        if (!current.expired &&
                            current.payment == PaymentState.review &&
                            current.stage != OrderStage.cancelled) {
                          ref
                              .read(ordersProvider.notifier)
                              .save(
                                current.copyWith(
                                  payment: PaymentState.approved,
                                  stage: OrderStage.preparing,
                                ),
                              );
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar pago de ejemplo'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final form = GlobalKey<FormState>();
                      String reason = '';
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Rechazar pago'),
                          content: Form(
                            key: form,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Motivo de rechazo',
                              ),
                              validator: requiredText,
                              onSaved: (v) => reason = v!.trim(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Volver'),
                            ),
                            FilledButton(
                              onPressed: () {
                                if (form.currentState!.validate()) {
                                  form.currentState!.save();
                                  Navigator.pop(c, true);
                                }
                              },
                              child: const Text('Rechazar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final current = ref
                            .read(ordersProvider)
                            .firstWhere((o) => o.id == id);
                        if (current.payment == PaymentState.review &&
                            current.stage != OrderStage.cancelled &&
                            !current.expired) {
                          ref
                              .read(ordersProvider.notifier)
                              .save(
                                current.copyWith(
                                  payment: PaymentState.rejected,
                                  rejection: reason,
                                ),
                              );
                        }
                      }
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Rechazar con motivo'),
                  ),
                ],
              ),
            ),
          if (order.payment == PaymentState.approved &&
              (order.stage == OrderStage.preparing ||
                  order.stage == OrderStage.ready))
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(ordersProvider.notifier)
                    .save(
                      order.copyWith(
                        stage: order.stage == OrderStage.preparing
                            ? OrderStage.ready
                            : OrderStage.delivered,
                      ),
                    );
              },
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                order.stage == OrderStage.preparing
                    ? (order.delivery
                          ? 'Marcar en reparto'
                          : 'Marcar listo para recojo')
                    : 'Marcar entregado',
              ),
            ),
        ],
      ),
    );
  }
}
