import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_navigation.dart';
import '../client/product_image.dart';

class AdminProducts extends ConsumerStatefulWidget {
  const AdminProducts({super.key});
  @override
  ConsumerState<AdminProducts> createState() => _AdminProductsState();
}

class _AdminProductsState extends ConsumerState<AdminProducts> {
  String query = '', status = 'Todos';
  @override
  Widget build(BuildContext context) {
    final products = ref
        .watch(productsProvider)
        .where(
          (p) =>
              '${p.name} ${p.brand}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (status == 'Todos' ||
                  (status == 'Activos' ? p.active : !p.active)),
        )
        .toList();
    return StorePage(
      title: 'Productos',
      admin: true,
      tab: 1,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Heading(
            'Tu catálogo.',
            subtitle: 'Cada modelo, en un solo lugar.',
          ),
          FilledButton.icon(
            onPressed: () => context.push('$adminRoot/producto/nuevo'),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo producto'),
          ),
          const SizedBox(height: 18),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar producto o marca',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ['Todos', 'Activos', 'Inactivos'])
                ChoiceChip(
                  label: Text(s),
                  selected: status == s,
                  onSelected: (_) => setState(() => status = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const EmptyState(
              'Sin productos',
              'Prueba otra búsqueda o crea un nuevo producto.',
            ),
          for (final p in products)
            SheetCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 78, child: ProductImage(p, height: 78)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(p.brand, style: const TextStyle(color: muted)),
                            Text(
                              money(p.priceCents),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Tag(
                        p.active ? 'Activo' : 'Inactivo',
                        color: p.active ? Colors.green.shade800 : muted,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Editar producto',
                        onPressed: () =>
                            context.push('$adminRoot/producto/${p.id}'),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: p.active
                            ? 'Desactivar producto'
                            : 'Activar producto',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text(
                                p.active
                                    ? '¿Desactivar producto?'
                                    : '¿Activar producto?',
                              ),
                              content: const Text(
                                'Esta acción modifica únicamente el catálogo de ejemplo.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Confirmar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            ref
                                .read(productsProvider.notifier)
                                .save(p.copyWith(active: !p.active));
                          }
                        },
                        icon: Icon(
                          p.active
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
