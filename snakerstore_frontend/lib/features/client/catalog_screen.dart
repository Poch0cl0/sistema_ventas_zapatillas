import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'product_image.dart';

enum CatalogState { content, loading, offline, error, empty }

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String query = '', brand = 'Todas', category = 'Todos', size = 'Todas';
  CatalogState view = CatalogState.content;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stock = ref.watch(inventoryProvider);
    final products = ref
        .watch(productsProvider)
        .where(
          (p) =>
              p.active &&
              '${p.name} ${p.brand}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (brand == 'Todas' || p.brand == brand) &&
              (category == 'Todos' || p.category == category) &&
              (size == 'Todas' || (stock['${p.id}-$size'] ?? 0) > 0),
        )
        .toList();
    return StorePage(
      title: 'SNEAKERSTORE',
      tab: 0,
      actions: [
        IconButton(
          tooltip: 'Iniciar sesión',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.person_outline),
        ),
        PopupMenuButton<CatalogState>(
          tooltip: 'Previsualizar estados del catálogo',
          onSelected: (v) => setState(() => view = v),
          itemBuilder: (_) => [
            for (final pair in [
              (CatalogState.content, 'Contenido'),
              (CatalogState.loading, 'Cargando'),
              (CatalogState.offline, 'Sin conexión'),
              (CatalogState.error, 'Error'),
              (CatalogState.empty, 'Vacío'),
            ])
              PopupMenuItem(value: pair.$1, child: Text(pair.$2)),
          ],
        ),
      ],
      child: switch (view) {
        CatalogState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        CatalogState.offline || CatalogState.error => EmptyState(
          view == CatalogState.offline
              ? 'Sin conexión'
              : 'No pudimos cargar el catálogo',
          'Este es un estado de ejemplo. Intenta nuevamente.',
          icon: Icons.wifi_off_rounded,
          action: () => setState(() => view = CatalogState.content),
          label: 'Reintentar',
        ),
        CatalogState.empty => const EmptyState(
          'Próximamente, nuevos pares',
          'Todavía no hay productos disponibles.',
        ),
        CatalogState.content => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Heading(
              'Encuentra tu\npróximo paso.',
              subtitle: 'Zapatillas que siguen tu ritmo.',
            ),
            TextField(
              controller: search,
              decoration: const InputDecoration(
                hintText: 'Buscar modelo o marca',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Tag('NUEVA COLECCIÓN'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/sneaker_0.png',
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'HECHAS PARA\nSEGUIRTE EL RITMO.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Descubre nuestra selección de running y estilo urbano.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                for (final c in ['Todos', 'Running', 'Urbano'])
                  ChoiceChip(
                    label: Text(c),
                    selected: category == c,
                    onSelected: (_) => setState(() => category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: brand,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Marca'),
                    items: [
                      for (final b in [
                        'Todas',
                        'Nike',
                        'Jordan',
                        'Adidas',
                        'New Balance',
                      ])
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => brand = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: size,
                    decoration: const InputDecoration(labelText: 'Talla EU'),
                    items: [
                      for (final s in [
                        'Todas',
                        '38',
                        '39',
                        '40',
                        '41',
                        '42',
                        '43',
                      ])
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => size = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '${products.length} modelos para descubrir',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              EmptyState(
                'No encontramos ese par',
                'Prueba con otra marca, talla o búsqueda.',
                label: 'Limpiar filtros',
                action: () => setState(() {
                  query = '';
                  search.clear();
                  brand = 'Todas';
                  category = 'Todos';
                  size = 'Todas';
                }),
              ),
            LayoutBuilder(
              builder: (_, box) {
                final columns = box.maxWidth < 340
                    ? 1
                    : box.maxWidth > 580
                    ? 3
                    : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 320,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/producto/${p.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProductImage(p, height: 145),
                              const SizedBox(height: 12),
                              Text(
                                p.brand.toUpperCase(),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                money(p.priceCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Tallas EU 38 – 43',
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                              const SizedBox(height: 5),
                              const Row(
                                children: [
                                  Text(
                                    'Ver detalles',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const SheetCard(
              child: Column(
                children: [
                  InfoNote(
                    'Yape, Plin y transferencia. Verificación manual del pago.',
                    icon: Icons.verified_user_outlined,
                  ),
                  InfoNote(
                    'Tu carrito no reserva stock. La reserva empieza al confirmar un pedido.',
                    icon: Icons.schedule,
                  ),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }
}
