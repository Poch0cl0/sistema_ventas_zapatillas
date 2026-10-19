import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});
  Future<void> edit(
    BuildContext context,
    WidgetRef ref, [
    DeliveryZone? zone,
  ]) async {
    final form = GlobalKey<FormState>();
    String name = '', price = '';
    bool active = zone?.active ?? true;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setModal) => AlertDialog(
          title: Text(zone == null ? 'Nueva zona' : 'Editar zona'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: zone?.name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la zona',
                    ),
                    validator: requiredText,
                    onSaved: (v) => name = v!.trim(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: zone == null
                        ? ''
                        : '${zone.feeCents ~/ 100}.${(zone.feeCents % 100).toString().padLeft(2, '0')}',
                    decoration: const InputDecoration(
                      labelText: 'Tarifa en soles',
                      prefixText: 'S/ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) =>
                        v != null &&
                            RegExp(r'^\d{1,4}([.,]\d{1,2})?$').hasMatch(v)
                        ? null
                        : 'Usa hasta 2 decimales',
                    onSaved: (v) => price = v!,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Zona activa'),
                    value: active,
                    onChanged: (v) => setModal(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) {
                  return;
                }
                form.currentState!.save();
                final parts = price.replaceAll(',', '.').split('.');
                final cents =
                    int.parse(parts[0]) * 100 +
                    int.parse(
                      (parts.length == 2 ? parts[1] : '').padRight(2, '0'),
                    );
                ref
                    .read(zonesProvider.notifier)
                    .save(
                      DeliveryZone(
                        zone?.id ??
                            'demo-${DateTime.now().millisecondsSinceEpoch}',
                        name,
                        cents,
                        active: active,
                      ),
                    );
                Navigator.pop(c);
                notice(context, 'Zona guardada en la vista previa');
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider);
    return StorePage(
      title: 'Zonas de delivery',
      admin: true,
      tab: 4,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Heading(
            'Llega más lejos.',
            subtitle: 'Zonas y tarifas para pedidos online.',
          ),
          FilledButton.icon(
            onPressed: () => edit(context, ref),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Nueva zona'),
          ),
          const SizedBox(height: 20),
          if (zones.isEmpty)
            const EmptyState(
              'Aún no hay zonas',
              'Agrega una zona y define su tarifa.',
            ),
          for (final z in zones)
            SheetCard(
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          z.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(money(z.feeCents)),
                        Tag(
                          z.active ? 'Activa' : 'Inactiva',
                          color: z.active ? Colors.green.shade800 : muted,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar zona',
                    onPressed: () => edit(context, ref, z),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          const InfoNote(
            'Las zonas inactivas no se ofrecen en checkout. El recojo en tienda tiene tarifa cero.',
          ),
        ],
      ),
    );
  }
}
