import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import '../admin/store_read_repository.dart';
import 'store_repository.dart';
import 'receipt_screen.dart';

final checkoutOptionsProvider = FutureProvider.autoDispose<Json>(
  (ref) =>
      ref.watch(storeRepositoryProvider).get('/checkout-options', public: true),
);

class SimulationPaymentScreen extends ConsumerStatefulWidget {
  const SimulationPaymentScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<SimulationPaymentScreen> createState() => _SimulationState();
}

class _SimulationState extends ConsumerState<SimulationPaymentScreen> {
  bool busy = false;
  Future<void> complete(String action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .write(
            'POST',
            '/orders/${widget.id}/simulation',
            data: {'action': action},
          );
      if (!mounted) return;
      ref.invalidate(storeDocumentProvider('/orders/${widget.id}'));
      ref.invalidate(storePageProvider);
      ref.invalidate(adminOverviewProvider);
      ref.invalidate(availabilityProvider);
      notice(
        context,
        action == 'PAY'
            ? receiptStatusMessage(result['receiptStatus'] as String?)
            : 'Pedido confirmado sin pago. No se cobró dinero.',
      );
      context.go('/pedido/${widget.id}');
    } catch (e) {
      if (mounted) notice(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(storeDocumentProvider('/orders/${widget.id}'));
    return KineticScaffold(
      appBar: const StoreAppBar(title: 'Tu compra', back: true),
      bottomNavigationBar: const StoreBottomBar(index: 3),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          'No pudimos cargar el pedido',
          errorMessage(e),
          label: 'Reintentar',
          action: () =>
              ref.invalidate(storeDocumentProvider('/orders/${widget.id}')),
        ),
        data: (value) {
          final expires = DateTime.tryParse(
            value['reservationExpiresAt'] as String? ?? '',
          );
          final available =
              value['reservationState'] == 'ACTIVE' &&
              expires != null &&
              expires.isAfter(DateTime.now()) &&
              value['currentPaymentId'] == null;
          final skipped =
              value['isSimulation'] == true &&
              value['paymentStatus'] == 'NO_REQUERIDO';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: spaced([
              const SectionHeading(
                'El pago es opcional',
                eyebrow: 'Finalizar pedido',
                subtitle: 'Elige cómo finalizar tu pedido y obtener tu boleta.',
              ),
              SurfaceSection(
                title: 'Pedido ${shortOrder(widget.id)}',
                icon: Icons.shopping_bag_outlined,
                child: Column(
                  children: [
                    for (final item in value['items'] as List)
                      OrderItemRow(Json.from(item as Map)),
                    const Divider(height: 24),
                    AmountRow(
                      'Valor de referencia',
                      value['totalCents'] as int,
                    ),
                    const AmountRow('Importe a cobrar', 0, bold: true),
                  ],
                ),
              ),
              if (available || skipped) ...[
                FilledButton.icon(
                  onPressed: busy ? null : () => complete('PAY'),
                  style: accentButton,
                  icon: const Icon(Icons.payment_outlined, size: 19),
                  label: Text(
                    busy ? 'Procesando…' : 'Realizar pago y generar boleta',
                  ),
                ),
                if (available)
                  OutlinedButton(
                    onPressed: busy ? null : () => complete('SKIP'),
                    child: const Text('Continuar sin pagar'),
                  ),
                const InfoNote(
                  'Recibirás tu boleta en el correo registrado cuando el servicio esté disponible.',
                ),
              ] else ...[
                StatusPill(value['paymentStatus'] as String),
                if (value['paymentStatus'] == 'SIMULADO')
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ReceiptScreen(id: widget.id),
                      ),
                    ),
                    child: const Text('Ver boleta'),
                  ),
                TextButton(
                  onPressed: () => context.go('/pedido/${widget.id}'),
                  child: const Text('Volver al pedido'),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}
