import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import '../auth/application/session.dart';
import '../store/commerce_screens.dart';
import 'catalog_repository.dart';
import 'product_visual.dart';
export 'product_visual.dart';

class ConnectedCatalogScreen extends ConsumerStatefulWidget {
  const ConnectedCatalogScreen({
    super.key,
    this.admin = false,
    this.home = false,
  });
  final bool admin, home;
  @override
  ConsumerState<ConnectedCatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<ConnectedCatalogScreen> {
  final search = TextEditingController();
  String query = '', category = '', brand = '';
  final cursors = <String?>[null];
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void resetFilters() {
    query = '';
    category = '';
    brand = '';
    search.clear();
  }

  @override
  Widget build(BuildContext context) {
    final request = (admin: widget.admin, after: cursors.last);
    final page = ref.watch(catalogPageProvider(request));
    final profile = ref.watch(sessionProvider).profile;
    return KineticScaffold(
      appBar: StoreAppBar(
        admin: widget.admin,
        actions: [
          IconButton(
            tooltip: 'Actualizar catálogo',
            onPressed: () => ref.invalidate(catalogPageProvider(request)),
            icon: const Icon(Icons.refresh, size: 21),
          ),
        ],
      ),
      bottomNavigationBar: StoreBottomBar(
        index: widget.admin
            ? 1
            : widget.home
            ? 0
            : 1,
        admin: widget.admin,
      ),
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          'No pudimos cargar el catálogo',
          errorMessage(e),
          label: 'Reintentar',
          action: () => ref.invalidate(catalogPageProvider(request)),
        ),
        data: (data) {
          final categories = data.items.map((p) => p.category).toSet().toList()
            ..sort();
          final brands = data.items.map((p) => p.brand).toSet().toList()
            ..sort();
          final products = data.items
              .where(
                (p) =>
                    '${p.name} ${p.brand} ${p.category}'.toLowerCase().contains(
                      query.toLowerCase(),
                    ) &&
                    (category.isEmpty || p.category == category) &&
                    (brand.isEmpty || p.brand == brand),
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(catalogPageProvider(request));
              try {
                await ref.read(catalogPageProvider(request).future);
              } catch (_) {
                /* provider renders the error */
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                SectionHeading(
                  widget.admin
                      ? 'Productos'
                      : widget.home
                      ? 'Tu próximo paso.'
                      : 'Encuentra tu próximo par.',
                  eyebrow: widget.admin
                      ? 'Administración / Catálogo'
                      : profile?.name == null
                      ? 'Bienvenido a SneakerStore'
                      : 'Hola, ${profile!.name}',
                  subtitle: widget.admin
                      ? 'Gestiona el catálogo y su visibilidad en la tienda.'
                      : 'Explora modelos, elige tu talla y hazlos tuyos.',
                ),
                if (widget.admin) ...[
                  FilledButton.icon(
                    onPressed: () => context.push('/admin/productos/nuevo'),
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('Nuevo producto'),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: search,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar modelo o marca en esta página',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () => setState(() {
                              query = '';
                              search.clear();
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                if (!widget.admin &&
                    data.items.isNotEmpty &&
                    cursors.length == 1) ...[
                  _CatalogHero(product: data.items.first),
                  const SizedBox(height: 24),
                ],
                if (categories.isNotEmpty) ...[
                  const Text(
                    'CATEGORÍAS PRINCIPALES',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in ['', ...categories])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c.isEmpty ? 'Todos' : c),
                              selected: category == c,
                              labelStyle: TextStyle(
                                color: category == c ? Colors.white : ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) => setState(() => category = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (brands.isNotEmpty)
                  SurfaceSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MARCA',
                          style: TextStyle(
                            fontSize: 10,
                            color: muted,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final b in ['', ...brands])
                              ChoiceChip(
                                label: Text(b.isEmpty ? 'Todas' : b),
                                selected: brand == b,
                                labelStyle: TextStyle(
                                  color: brand == b ? Colors.white : ink,
                                  fontSize: 11,
                                ),
                                onSelected: (_) => setState(() => brand = b),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${products.length} modelos en esta página',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (query.isNotEmpty ||
                        category.isNotEmpty ||
                        brand.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(resetFilters),
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(color: Color(0xFFAB3500)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (products.isEmpty)
                  EmptyState(
                    data.items.isEmpty
                        ? 'Próximamente, nuevos pares'
                        : 'No encontramos ese par',
                    data.items.isEmpty
                        ? 'Los productos de la tienda aparecerán aquí.'
                        : 'Prueba con otra búsqueda o limpia los filtros.',
                  ),
                if (widget.admin) ...[
                  for (final p in products) _AdminProductCard(product: p),
                ] else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final scale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final columns = constraints.maxWidth < 320 || scale > 1.3
                          ? 1
                          : constraints.maxWidth > 650
                          ? 3
                          : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: width + 155 * scale,
                        ),
                        itemBuilder: (_, index) =>
                            _ProductCard(product: products[index]),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: cursors.length == 1
                            ? null
                            : () => setState(() {
                                cursors.removeLast();
                                resetFilters();
                              }),
                        child: const Text('Anterior'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '${cursors.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: data.nextCursor == null
                            ? null
                            : () => setState(() {
                                cursors.add(data.nextCursor);
                                resetFilters();
                              }),
                        child: const Text('Siguiente'),
                      ),
                    ),
                  ],
                ),
                if (!widget.admin) ...[
                  const SizedBox(height: 26),
                  SurfaceSection(
                    child: Column(
                      children: [
                        _benefit(
                          Icons.verified_user_outlined,
                          'Pagos con verificación',
                          'Envía tu referencia y consulta el estado desde tu pedido.',
                        ),
                        const SizedBox(height: 20),
                        _benefit(
                          Icons.timer_outlined,
                          'Reserva por 24 horas',
                          'Tu stock se reserva al confirmar el pedido.',
                        ),
                        const SizedBox(height: 20),
                        _benefit(
                          Icons.local_shipping_outlined,
                          'Delivery o recojo',
                          'Consulta las zonas y tarifas disponibles en el checkout.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'SNEAKERSTORE\nENCUENTRA TU PRÓXIMO PASO.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.8,
                      color: muted,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: accentWash,
        child: Icon(icon, color: const Color(0xFFAB3500), size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CatalogHero extends StatelessWidget {
  const _CatalogHero({required this.product});
  final CatalogProduct product;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(colors: [Colors.black, Color(0xFF29170D)]),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag('EXPLORA LA COLECCIÓN'),
        const SizedBox(height: 16),
        RemoteProductImage(product, height: 190),
        const SizedBox(height: 18),
        Text(
          product.name.toUpperCase(),
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: -.7,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${product.brand} · ${money(product.priceCents)}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: accentButton,
            onPressed: () =>
                context.push('/producto/${Uri.encodeComponent(product.id)}'),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Descubrir este modelo'),
          ),
        ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final CatalogProduct product;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/producto/${Uri.encodeComponent(product.id)}'),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: RemoteProductImage(product, height: double.infinity),
            ),
            const SizedBox(height: 12),
            Text(
              product.brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: muted,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              money(product.priceCents),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -.5,
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Ver tallas  →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminProductCard extends StatelessWidget {
  const _AdminProductCard({required this.product});
  final CatalogProduct product;
  @override
  Widget build(BuildContext context) => SheetCard(
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 80, child: RemoteProductImage(product, height: 80)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand.toUpperCase(),
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    money(product.priceCents),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            StatusPill(product.active ? 'Activo' : 'Inactivo'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push(
                '/admin/producto/${Uri.encodeComponent(product.id)}/editar',
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar'),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push(
              '/admin/producto/${Uri.encodeComponent(product.id)}',
            ),
            child: const Text('Ver producto'),
          ),
        ),
      ],
    ),
  );
}

class _ProductGallery extends StatefulWidget {
  const _ProductGallery(this.product);
  final CatalogProduct product;
  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  final controller = PageController();
  int index = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget image(String url) => Image.network(
    url,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        const Center(child: Icon(Icons.broken_image_outlined, color: muted)),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 1.05,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.product.images.isEmpty
              ? const Center(
                  child: Icon(Icons.image_outlined, color: muted, size: 48),
                )
              : PageView(
                  controller: controller,
                  onPageChanged: (i) => setState(() => index = i),
                  children: widget.product.images.map(image).toList(),
                ),
        ),
      ),
      if (widget.product.images.length > 1) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.product.images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => InkWell(
              onTap: () => controller.animateToPage(
                i,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: index == i ? ink : line),
                ),
                child: image(widget.product.images[i]),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class ConnectedProductScreen extends ConsumerWidget {
  const ConnectedProductScreen({
    super.key,
    required this.id,
    this.admin = false,
  });
  final String id;
  final bool admin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (admin: admin, id: id);
    return KineticScaffold(
      appBar: StoreAppBar(admin: admin, back: true),
      bottomNavigationBar: StoreBottomBar(index: 1, admin: admin),
      body: ref
          .watch(catalogProductProvider(query))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              'Producto no disponible',
              errorMessage(e),
              label: 'Reintentar',
              action: () => ref.invalidate(catalogProductProvider(query)),
            ),
            data: (p) => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'CATÁLOGO / ${p.category.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: muted,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 16),
                _ProductGallery(p),
                const SizedBox(height: 24),
                Text(
                  p.brand.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(p.category, style: const TextStyle(color: muted)),
                const SizedBox(height: 12),
                Text(
                  money(p.priceCents),
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 20),
                const SurfaceSection(
                  tint: soft,
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, color: Color(0xFFAB3500)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Elige tu par y consulta los métodos de pago habilitados al confirmar tu pedido.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!admin)
                  AddToCart(p)
                else
                  SurfaceSection(
                    title: 'Gestión del producto',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusPill(p.active ? 'Activo' : 'Inactivo'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.push(
                            '/admin/producto/${Uri.encodeComponent(id)}/editar',
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar producto y fotos'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SurfaceSection(
                  child: Column(
                    children: [
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 18),
                        shape: const Border(),
                        leading: const Icon(Icons.bolt, color: orange),
                        title: const Text(
                          'Detalles del producto',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        initiallyExpanded: true,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              p.description,
                              style: const TextStyle(color: muted, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        shape: const Border(),
                        leading: const Icon(
                          Icons.local_shipping_outlined,
                          color: orange,
                        ),
                        title: const Text(
                          'Envío y recojo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Elige entre las zonas de delivery y el recojo habilitados por la tienda. La tarifa se confirma antes de generar tu pedido.',
                              style: TextStyle(color: muted, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextButton.icon(
                  onPressed: () =>
                      context.go(admin ? '/admin/productos' : '/catalogo'),
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: const Text('Seguir explorando el catálogo'),
                ),
              ],
            ),
          ),
    );
  }
}
