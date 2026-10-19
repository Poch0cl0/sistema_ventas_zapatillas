import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String query = '';
  bool lowOnly = false;
  final List<String> movements = [];
  Future<void> adjust(Product p, {String? size}) async {
    final form = GlobalKey<FormState>();
    String selectedSize = size ?? '40', quantity = '', reason = '';
    final stock = ref.read(inventoryProvider);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(size == null ? 'Agregar talla' : 'Ajustar existencias'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.name),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedSize,
                  decoration: const InputDecoration(labelText: 'Talla EU'),
                  items: [
                    for (final s in [
                      '38',
                      '39',
                      '40',
                      '41',
                      '42',
                      '43',
                      '44',
                      '45',
                    ])
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: size == null ? (v) => selectedSize = v! : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: size == null
                      ? ''
                      : '${stock['${p.id}-$size'] ?? 0}',
                  decoration: const InputDecoration(
                    labelText: 'Nueva cantidad disponible',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v != null && RegExp(r'^\d{1,5}$').hasMatch(v)
                      ? null
                      : 'Usa un entero entre 0 y 99999',
                  onSaved: (v) => quantity = v!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Motivo del ajuste',
                  ),
                  validator: requiredText,
                  onSaved: (v) => reason = v!.trim(),
                ),
                const InfoNote(
                  'Las unidades reservadas se gestionan desde pedidos.',
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
              final before = stock['${p.id}-$selectedSize'] ?? 0;
              ref
                  .read(inventoryProvider.notifier)
                  .adjust(p.id, selectedSize, int.parse(quantity));
              setState(
                () => movements.insert(
                  0,
                  '${p.name} · EU $selectedSize\n$before → $quantity disponibles · $reason',
                ),
              );
              Navigator.pop(c);
              notice(context, 'Existencias de ejemplo actualizadas');
            },
            child: const Text('Confirmar ajuste'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = ref.watch(inventoryProvider);
    final products = ref
        .watch(productsProvider)
        .where(
          (p) => '${p.name} ${p.brand}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return StorePage(
      title: 'Inventario',
      admin: true,
      tab: 2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Heading(
            'Cada par cuenta.',
            subtitle: 'Existencias disponibles por talla europea.',
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar producto',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo stock bajo (≤ 2)'),
            value: lowOnly,
            onChanged: (v) => setState(() => lowOnly = v),
          ),
          const InfoNote(
            'Inventario de demostración: los pedidos de ejemplo no generan reservas reales.',
          ),
          if (products.isEmpty)
            const EmptyState('Sin resultados', 'Prueba con otro producto.'),
          for (final p in products)
            SheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  for (final s in [
                    '38',
                    '39',
                    '40',
                    '41',
                    '42',
                    '43',
                    '44',
                    '45',
                  ])
                    if ((!lowOnly || (stock['${p.id}-$s'] ?? 0) <= 2) &&
                        stock.containsKey('${p.id}-$s'))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'EU $s · ${stock['${p.id}-$s']} disponibles',
                        ),
                        subtitle: const Text('Reservadas: 0 · Ejemplo'),
                        leading: Icon(
                          (stock['${p.id}-$s'] ?? 0) <= 2
                              ? Icons.warning_amber
                              : Icons.check_circle_outline,
                          color: (stock['${p.id}-$s'] ?? 0) <= 2
                              ? const Color(0xFFAB3500)
                              : muted,
                        ),
                        trailing: IconButton(
                          tooltip: 'Ajustar talla $s',
                          onPressed: () => adjust(p, size: s),
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                  TextButton.icon(
                    onPressed: () => adjust(p),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar talla'),
                  ),
                ],
              ),
            ),
          const Heading('Movimientos de esta sesión'),
          if (movements.isEmpty)
            const SheetCard(
              child: Text('Aún no has realizado ajustes de ejemplo.'),
            ),
          for (final m in movements) SheetCard(child: Text(m)),
        ],
      ),
    );
  }
}
