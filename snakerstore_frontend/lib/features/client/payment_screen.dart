import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final form = GlobalKey<FormState>();
  String method = 'YAPE', reference = '';
  XFile? receipt;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) {
        return;
      }
      if (await file.length() > 5 * 1024 * 1024) {
        if (mounted) {
          notice(context, 'Selecciona una imagen de hasta 5 MB.');
        }
        return;
      }
      if (mounted) {
        setState(() => receipt = file);
      }
    } catch (_) {
      if (mounted) {
        notice(context, 'No pudimos abrir la galería. Revisa los permisos.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref
        .watch(ordersProvider)
        .where((o) => o.id == widget.id)
        .firstOrNull;
    if (order == null) {
      return const StorePage(
        title: 'Pago',
        child: EmptyState('Pedido no encontrado', 'Vuelve a tus pedidos.'),
      );
    }
    final duration = order.expiresAt.difference(DateTime.now());
    final seconds = duration.inSeconds.clamp(0, 86400);
    final clock =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return StorePage(
      title: 'Registrar pago',
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Heading(
              'Completa tu pedido',
              subtitle: 'El siguiente paso hacia tu nuevo par.',
            ),
            Text(order.id, style: const TextStyle(color: muted)),
            const SizedBox(height: 16),
            SheetCard(
              color: ink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL DEL PEDIDO DE EJEMPLO',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    money(order.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tiempo de reserva · $clock',
                    style: const TextStyle(color: Color(0xFFFFB59D)),
                  ),
                ],
              ),
            ),
            Tag(paymentLabel(order.payment)),
            if (order.payment == PaymentState.rejected)
              InfoNote(
                'Motivo: ${order.rejection}. Puedes reenviar dentro del plazo original.',
              ),
            if (order.expired && order.payment != PaymentState.approved)
              const InfoNote(
                'Plazo vencido. No se permiten nuevos pagos. El administrador procesa manualmente la cancelación.',
              ),
            if (order.canPay) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in ['YAPE', 'PLIN', 'TRANSFERENCIA'])
                    ChoiceChip(
                      label: Text(m),
                      selected: method == m,
                      onSelected: (_) => setState(() => method = m),
                    ),
                ],
              ),
              const SheetCard(
                child: InfoNote(
                  'Los datos de pago y el QR de la tienda se mostrarán al conectar el backend. No realices transferencias desde esta vista previa.',
                  icon: Icons.qr_code_2,
                ),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Referencia de operación',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
                maxLength: 80,
                validator: requiredText,
                onSaved: (v) => reference = v!.trim(),
              ),
              OutlinedButton.icon(
                onPressed: pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  receipt == null
                      ? 'Comprobante opcional · hasta 5 MB'
                      : receipt!.name,
                ),
              ),
              if (receipt != null)
                FutureBuilder<Uint8List>(
                  future: receipt!.readAsBytes(),
                  builder: (_, snapshot) => snapshot.hasData
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Image.memory(
                            snapshot.data!,
                            height: 160,
                            errorBuilder: (_, _, _) => const Text(
                              'No se pudo previsualizar esta imagen',
                            ),
                          ),
                        )
                      : const LinearProgressIndicator(),
                ),
              const InfoNote(
                'La referencia es obligatoria; la imagen es opcional. Enviar información no equivale a un pago aprobado.',
              ),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) {
                    return;
                  }
                  form.currentState!.save();
                  ref
                      .read(ordersProvider.notifier)
                      .save(
                        order.copyWith(
                          payment: PaymentState.review,
                          method: method,
                          reference: reference,
                        ),
                      );
                  notice(
                    context,
                    'Simulación: pago enviado a revisión. Ningún archivo fue subido.',
                  );
                  context.go('/pedido/${order.id}');
                },
                child: const Text('Simular envío a revisión'),
              ),
            ] else
              const InfoNote(
                'Consulta el estado de pago en el detalle de tu pedido.',
              ),
            TextButton(
              onPressed: () => context.go('/pedido/${order.id}'),
              child: const Text('Ver detalle del pedido'),
            ),
          ],
        ),
      ),
    );
  }
}
