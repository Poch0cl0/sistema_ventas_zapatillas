import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final form = GlobalKey<FormState>();
  bool delivery = false;
  String? zoneId;
  String recipient = '', phone = '', address = '', reference = '';
  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final zones = ref.watch(zonesProvider).where((z) => z.active).toList();
    final zone = zones.where((z) => z.id == zoneId).firstOrNull;
    final subtotal = lines.fold(0, (sum, l) => sum + l.total);
    return StorePage(
      title: 'Entrega y resumen',
      child: lines.isEmpty
          ? EmptyState(
              'El carrito está vacío',
              'Agrega un producto antes de continuar.',
              action: () => context.go('/catalogo'),
            )
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Heading(
                    '¿Cómo lo recibes?',
                    subtitle: 'Un paso más cerca de tu próximo par.',
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Recojo'),
                        icon: Icon(Icons.storefront_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Delivery'),
                        icon: Icon(Icons.local_shipping_outlined),
                      ),
                    ],
                    selected: {delivery},
                    onSelectionChanged: (v) =>
                        setState(() => delivery = v.first),
                  ),
                  const SizedBox(height: 22),
                  if (!delivery)
                    const SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recojo en tienda',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 8),
                          Text('Sin costo de entrega.'),
                          InfoNote(
                            'La dirección y el horario reales se cargarán desde la configuración de la tienda.',
                          ),
                        ],
                      ),
                    ),
                  if (delivery) ...[
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Nombre del destinatario',
                      ),
                      validator: requiredText,
                      onSaved: (v) => recipient = v!.trim(),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Celular'),
                      keyboardType: TextInputType.phone,
                      validator: phoneValidator,
                      onSaved: (v) => phone = v!.trim(),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: zone?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Zona de entrega',
                      ),
                      items: [
                        for (final z in zones)
                          DropdownMenuItem(
                            value: z.id,
                            child: Text('${z.name} · ${money(z.feeCents)}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => zoneId = v),
                      validator: (v) =>
                          v == null ? 'Selecciona una zona activa' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Dirección completa',
                      ),
                      validator: requiredText,
                      onSaved: (v) => address = v!.trim(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Referencia de dirección (opcional)',
                      ),
                      onSaved: (v) => reference = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 20),
                  ],
                  SheetCard(
                    child: Column(
                      children: [
                        AmountRow('Subtotal estimado', subtotal),
                        AmountRow(
                          'Entrega',
                          delivery ? zone?.feeCents ?? 0 : 0,
                        ),
                        const Divider(),
                        AmountRow(
                          'Total estimado',
                          subtotal + (delivery ? zone?.feeCents ?? 0 : 0),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const InfoNote(
                    'Simulación local: no se enviará un pedido ni se reservará stock real. La compra real requiere autenticación y cálculo del servidor.',
                  ),
                  FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) {
                        return;
                      }
                      form.currentState!.save();
                      final inventory = ref.read(inventoryProvider);
                      if (lines.any(
                        (l) =>
                            !ref
                                .read(productsProvider)
                                .any((p) => p.id == l.product.id && p.active) ||
                            (inventory[l.key] ?? 0) < l.quantity,
                      )) {
                        notice(
                          context,
                          'Uno de los productos ya no está disponible en esa cantidad. Revisa el carrito.',
                        );
                        return;
                      }
                      final now = DateTime.now();
                      final order = PreviewOrder(
                        id: 'DEMO-${now.millisecondsSinceEpoch}',
                        items: List.unmodifiable(lines),
                        createdAt: now,
                        expiresAt: now.add(const Duration(hours: 24)),
                        delivery: delivery,
                        zone: delivery ? zone!.name : '',
                        feeCents: delivery ? zone!.feeCents : 0,
                        recipient: delivery
                            ? recipient
                            : ref.read(profileProvider).name,
                        phone: phone,
                        address: address,
                        deliveryReference: reference,
                      );
                      ref.read(ordersProvider.notifier).save(order);
                      ref.read(cartProvider.notifier).clear();
                      context.go('/pago/${order.id}');
                    },
                    child: const Text('Crear pedido de ejemplo'),
                  ),
                ],
              ),
            ),
    );
  }
}
