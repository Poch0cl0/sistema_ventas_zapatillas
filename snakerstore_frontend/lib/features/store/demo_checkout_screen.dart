import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../../core/network/app_failure.dart';
import '../admin/store_read_repository.dart';
import 'store_repository.dart';

class DemoCheckoutScreen extends ConsumerStatefulWidget {
  const DemoCheckoutScreen({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<DemoCheckoutScreen> createState() => _DemoCheckoutState();
}

class _DemoCheckoutState extends ConsumerState<DemoCheckoutScreen> {
  Json? checkout;
  String? error;
  String scenario = 'APPROVED';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .write('POST', '/orders/${widget.orderId}/demo-checkout');
      if (mounted) setState(() => checkout = result);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    if (busy || checkout == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .write(
            'POST',
            '/demo-checkouts/${checkout!['id']}/confirm',
            data: {'scenario': scenario},
          );
      ref.invalidate(storeDocumentProvider('/orders/${widget.orderId}'));
      ref.invalidate(storePageProvider);
      ref.invalidate(adminOverviewProvider);
      if (mounted) setState(() => checkout = result);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = checkout?['status'];
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout de prueba')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.science_outlined, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Pasarela demo · Sin cobros reales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Esta API local permite probar el checkout sin claves. El pedido se marcará como simulación y no contará como venta real. No ingreses datos de tarjetas.',
          ),
          const SizedBox(height: 20),
          if (checkout != null) ...[
            AmountRow(
              'Importe de prueba',
              checkout!['amountCents'] as int,
              bold: true,
            ),
            const SizedBox(height: 20),
            if (status == 'APPROVED')
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Pago demo aprobado'),
                subtitle: Text(
                  'Pedido en preparación. No se ha cobrado dinero.',
                ),
              )
            else ...[
              if (status == 'REJECTED')
                const Text(
                  'Pago demo rechazado. Puedes intentar otro escenario.',
                ),
              if (status == 'PENDING')
                const Text(
                  'Pago demo pendiente. El stock sigue reservado hasta el vencimiento. Puedes probar su aprobación o rechazo.',
                ),
              const SizedBox(height: 12),
              const Text('Elige una tarjeta de prueba ficticia'),
              for (final item in const {
                'APPROVED': '•••• 4242 · Aprobar',
                'REJECTED': '•••• 0002 · Rechazar',
                'PENDING': '•••• 3155 · Dejar pendiente',
              }.entries)
                Card(
                  child: ListTile(
                    leading: Icon(
                      scenario == item.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(item.value),
                    onTap: busy
                        ? null
                        : () => setState(() => scenario = item.key),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : confirm,
                child: Text(busy ? 'Procesando…' : 'Ejecutar pago de prueba'),
              ),
            ],
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (checkout == null)
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Reintentar'),
              ),
          ],
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver al pedido'),
          ),
        ],
      ),
    );
  }
}

class DemoCheckoutButton extends ConsumerWidget {
  const DemoCheckoutButton({super.key, required this.orderId, this.onComplete});
  final String orderId;
  final VoidCallback? onComplete;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref
            .watch(checkoutOptionsProvider)
            .asData
            ?.value['demoGatewayEnabled'] ==
        true;
    if (!enabled) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const Icon(Icons.science_outlined),
      label: const Text('Probar pasarela sin claves'),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Convertir a pedido de prueba'),
            content: const Text(
              'No se cobrará dinero. Este pedido quedará marcado como simulación y se excluirá de las ventas reales. Usará las existencias reservadas si apruebas el pago demo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Volver'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir checkout demo'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => DemoCheckoutScreen(orderId: orderId),
            ),
          );
          if (context.mounted) {
            ref.invalidate(storeDocumentProvider('/orders/$orderId'));
            onComplete?.call();
          }
        }
      },
    );
  }
}
