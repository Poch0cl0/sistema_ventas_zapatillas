import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import 'store_repository.dart';

String receiptStatusMessage(String? status) => switch (status) {
  'SENT' => 'La boleta se envió al servicio de correo. Revisa también la carpeta de spam.',
  'SENDING' =>
    'El envío está en curso. Actualiza esta pantalla en unos segundos.',
  'NOT_CONFIGURED' => 'La boleta está generada. Falta configurar el correo de la tienda para enviarla.',
  'NO_EMAIL' =>
    'No encontramos un correo en la cuenta registrada para enviar la boleta.',
  'FAILED' => 'No se pudo enviar el correo. La boleta y el pedido se conservaron; puedes reintentar.',
  _ => 'Tu boleta está disponible. Puedes enviarla al correo de tu cuenta.',
};

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.id, this.admin = false});
  final String id;
  final bool admin;
  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptState();
}

class _ReceiptState extends ConsumerState<ReceiptScreen> {
  late Future<Json> data;
  bool sending = false;
  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Json> load() =>
      ref.read(storeRepositoryProvider).get('/orders/${widget.id}/receipt');
  Future<void> send() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .write('POST', '/orders/${widget.id}/receipt/send');
      if (!mounted) return;
      notice(context, receiptStatusMessage(result['status'] as String?));
      setState(() => data = load());
    } catch (e) {
      if (mounted) notice(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => KineticScaffold(
    appBar: StoreAppBar(
      title: 'Boleta',
      back: true,
      admin: widget.admin,
      actions: [
        IconButton(
          tooltip: 'Actualizar estado',
          onPressed: sending ? null : () => setState(() => data = load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: StoreBottomBar(index: 3, admin: widget.admin),
    body: FutureBuilder<Json>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return EmptyState(
            'No pudimos cargar la boleta',
            errorMessage(snapshot.error!),
            label: 'Reintentar',
            action: () => setState(() => data = load()),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final receipt = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: spaced([
            const SectionHeading('Tu boleta', eyebrow: 'Tu compra'),
            SurfaceSection(
              title: receipt['storeName'] as String,
              icon: Icons.receipt_long_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Tag('PAGO REALIZADO'),
                  const SizedBox(height: 16),
                  SelectableText(
                    'Número: ${receipt['number']}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${receipt['customer']}\n${receipt['email'] ?? 'Sin correo registrado'}',
                    style: const TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 12),
                  for (final item in receipt['items'] as List)
                    OrderItemRow(Json.from(item as Map)),
                  const Divider(height: 26),
                  AmountRow('Subtotal', receipt['subtotalCents'] as int),
                  AmountRow('Envío', receipt['deliveryFeeCents'] as int),
                  AmountRow('Total', receipt['totalCents'] as int, bold: true),
                  const SizedBox(height: 12),
                  const AmountRow('Importe realmente cobrado', 0, bold: true),
                  const InfoNote(
                    'Documento de demostración sin valor tributario. No acredita una transferencia real.',
                  ),
                ],
              ),
            ),
            SurfaceSection(
              title: 'Envío por correo',
              icon: Icons.mail_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    receiptStatusMessage(receipt['status'] as String?),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  if (!widget.admin &&
                      receipt['status'] != 'SENT' &&
                      receipt['status'] != 'SENDING') ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: sending ? null : send,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: Text(
                        sending ? 'Enviando…' : 'Enviar al correo registrado',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'El correo incluye la boleta en PDF.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ]),
        );
      },
    ),
  );
}
