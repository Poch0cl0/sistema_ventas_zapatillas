import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import '../auth/application/session.dart';
import '../catalog/catalog_repository.dart';
import '../store/store_repository.dart';
import '../store/commerce_screens.dart';
import 'store_read_repository.dart';
import 'sales_chart.dart';

class ConnectedAdminScreen extends ConsumerWidget {
  const ConnectedAdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final overview = ref.watch(adminOverviewProvider);
    return KineticScaffold(
      appBar: StoreAppBar(
        admin: true,
        actions: [
          IconButton(
            tooltip: 'Configurar tienda',
            onPressed: () => context.push('/admin/configuracion'),
            icon: const Icon(Icons.settings_outlined, size: 21),
          ),
          IconButton(
            tooltip: 'Actualizar resumen',
            onPressed: () => ref.invalidate(adminOverviewProvider),
            icon: const Icon(Icons.refresh, size: 21),
          ),
        ],
      ),
      bottomNavigationBar: const StoreBottomBar(index: 0, admin: true),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          'No pudimos cargar el resumen',
          errorMessage(e),
          label: 'Reintentar',
          action: () => ref.invalidate(adminOverviewProvider),
        ),
        data: (data) {
          final pending = data.orders
              .where((o) => o['paymentStatus'] == 'PENDIENTE_VERIFICACION')
              .toList();
          final low = data.inventory
              .where((s) => (s['available'] as int) <= 2)
              .toList();
          final paid = data.orders
              .where(
                (o) =>
                    o['paymentStatus'] == 'APROBADO' &&
                    o['isSimulation'] != true,
              )
              .fold<int>(0, (sum, o) => sum + (o['totalCents'] as int));
          final names = {for (final p in data.products) p['id']: p['name']};
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionHeading(
                'Panel de control\ncomercial',
                eyebrow: profile?.name == null
                    ? 'Administración'
                    : 'Hola, ${profile!.name}',
                subtitle: 'Tu catálogo, pagos e inventario en una sola vista.',
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/admin/productos/nuevo'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo producto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = [
                    MiniMetric(
                      'Ventas aprobadas',
                      money(paid),
                      Icons.payments_outlined,
                    ),
                    MiniMetric(
                      'Pagos por revisar',
                      '${pending.length}',
                      Icons.receipt_long_outlined,
                      highlight: true,
                    ),
                    MiniMetric(
                      'Productos activos',
                      '${data.products.where((p) => p['active'] == true).length}',
                      Icons.inventory_2_outlined,
                    ),
                    MiniMetric(
                      'Tallas con stock bajo',
                      '${low.length}',
                      Icons.warning_amber_outlined,
                      highlight: true,
                    ),
                  ];
                  final columns =
                      constraints.maxWidth < 330 ||
                          MediaQuery.textScalerOf(context).scale(14) > 19
                      ? 1
                      : 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width:
                              (constraints.maxWidth - 12 * (columns - 1)) /
                              columns,
                          child: metric,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Resumen de los registros actuales. Ventas: todos los pedidos con pago aprobado.',
                style: TextStyle(fontSize: 10, color: muted),
              ),
              const SizedBox(height: 24),
              SurfaceSection(
                title: 'Gráfico de ventas',
                icon: Icons.bar_chart,
                child: SalesChart(data.orders),
              ),
              const SizedBox(height: 24),
              SurfaceSection(
                title: 'Validación de pagos',
                icon: Icons.fact_check_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'No tienes pagos pendientes de revisión.',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                    for (final o in pending.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(o['delivery'] as Map)['recipientName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${shortOrder(o['id'] as String)} · ${money(o['totalCents'] as int)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () =>
                                      context.push('/admin/pedido/${o['id']}'),
                                  child: const Text('Revisar pago'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => context.go('/admin/pedidos'),
                      child: const Text('Ver todos los pedidos →'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SurfaceSection(
                title: 'Alertas de inventario',
                icon: Icons.warning_amber_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (low.isEmpty)
                      const Text(
                        'No hay tallas con 2 o menos unidades disponibles.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    for (final stock in low.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentWash,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.layers_outlined,
                                size: 20,
                                color: Color(0xFFAB3500),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${names[stock['productId']] ?? 'Producto'}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'EU ${stock['size']} · ${stock['available']} disponibles',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ajustar stock',
                              onPressed: () => context.push(
                                '/admin/inventario/${stock['id']}/editar',
                              ),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                            ),
                          ],
                        ),
                      ),
                    TextButton(
                      onPressed: () => context.go('/admin/inventario'),
                      child: const Text('Abrir inventario →'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SurfaceSection(
                title: 'Tu tienda',
                icon: Icons.storefront_outlined,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Zonas de delivery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${data.zones.where((z) => z['active'] == true).length} zonas activas',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/admin/zonas'),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Tienda, recojo y pagos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text('Configura los datos de compra'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/configuracion'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ConnectedRecordsScreen extends ConsumerStatefulWidget {
  const ConnectedRecordsScreen({
    super.key,
    required this.path,
    required this.title,
    this.client = false,
  });
  final String path, title;
  final bool client;
  @override
  ConsumerState<ConnectedRecordsScreen> createState() => _RecordsState();
}

class _RecordsState extends ConsumerState<ConnectedRecordsScreen> {
  final cursors = <String?>[null];
  bool busy = false;
  String search = '', filter = 'Todos';
  DateTimeRange? dates;
  Future<void> selectDates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: dates,
      helpText: 'Filtrar pedidos por fecha de creación',
    );
    if (result != null && mounted) {
      setState(() {
        dates = result;
        cursors
          ..clear()
          ..add(null);
      });
    }
  }

  bool get orders => widget.path.endsWith('orders');
  bool get zones => widget.path.endsWith('delivery-zones');
  Future<void> expire() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .write('POST', '/admin/orders/expire');
      if (!mounted) return;
      ref.invalidate(storePageProvider);
      ref.invalidate(adminOverviewProvider);
      notice(
        context,
        '${result['expiredCount']} reservas liberadas; ${result['failedCount']} pendientes de revisión.',
      );
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(StoreEntry entry) async {
    await context.push(
      orders
          ? '${widget.client ? '' : '/admin'}/pedido/${Uri.encodeComponent(entry.id)}'
          : zones
          ? '/admin/zonas/${Uri.encodeComponent(entry.id)}/editar'
          : '/admin/inventario/${Uri.encodeComponent(entry.id)}/editar',
    );
    if (mounted) {
      ref.invalidate(storePageProvider);
      ref.invalidate(adminOverviewProvider);
    }
  }

  bool matches(StoreEntry entry) {
    final productId = entry.data['productId'] as String?;
    final name = !orders && !zones && productId != null
        ? ref
                  .watch(catalogProductProvider((admin: true, id: productId)))
                  .asData
                  ?.value
                  .name ??
              ''
        : '';
    if (!'$name ${entry.title} ${entry.subtitle} ${entry.data['delivery'] ?? ''}'
        .toLowerCase()
        .contains(search.toLowerCase()))
      return false;
    if (filter == 'Todos') return true;
    final value = entry.data;
    if (zones)
      return filter == 'Activas'
          ? value['active'] == true
          : value['active'] != true;
    if (!orders)
      return filter == 'Agotados'
          ? value['available'] == 0
          : ((value['available'] as int?) ?? 0) <= 2;
    if (filter == 'Entregados')
      return value['fulfillmentStatus'] == 'ENTREGADO';
    if (filter == 'En preparación')
      return [
        'PREPARANDO',
        'LISTO_RECOJO',
        'EN_REPARTO',
      ].contains(value['fulfillmentStatus']);
    return [
      'PENDIENTE',
      'PENDIENTE_VERIFICACION',
      'RECHAZADO',
    ].contains(value['paymentStatus']);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (widget.client && session.profile == null) {
      final unavailable = session.status == SessionStatus.unavailable;
      return KineticScaffold(
        appBar: const StoreAppBar(),
        bottomNavigationBar: const StoreBottomBar(index: 3),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeading('Mis pedidos', eyebrow: 'Tus compras'),
            SurfaceSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 56,
                      color: muted,
                    ),
                  ),
                  Text(
                    unavailable
                        ? 'No pudimos verificar tu cuenta'
                        : 'Tus pedidos te esperan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    unavailable
                        ? session.message ?? 'Intenta conectarte nuevamente.'
                        : 'Inicia sesión para consultar tus compras, pagos y entregas. Mientras tanto, puedes explorar el catálogo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (unavailable) {
                        ref.read(sessionProvider.notifier).retry();
                      } else {
                        context.go('/login');
                      }
                    },
                    child: Text(
                      unavailable ? 'Reintentar conexión' : 'Iniciar sesión',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/catalogo'),
                    child: const Text('Explorar catálogo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    String day(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final datedPath = orders && !widget.client && dates != null
        ? '${widget.path}?from=${day(dates!.start)}&to=${day(dates!.end)}'
        : widget.path;
    final query = (path: datedPath, after: cursors.last);
    final page = ref.watch(storePageProvider(query));
    return KineticScaffold(
      appBar: StoreAppBar(
        admin: !widget.client,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(storePageProvider(query)),
            icon: const Icon(Icons.refresh, size: 21),
          ),
        ],
      ),
      bottomNavigationBar: StoreBottomBar(
        index: widget.client
            ? 3
            : orders
            ? 3
            : zones
            ? 4
            : 2,
        admin: !widget.client,
      ),
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          'No pudimos cargar esta sección',
          errorMessage(e),
          label: 'Reintentar',
          action: () => ref.invalidate(storePageProvider(query)),
        ),
        data: (data) {
          final entries = data.items.where(matches).toList();
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionHeading(
                widget.title,
                eyebrow: widget.client ? 'Tus compras' : 'Administración',
                subtitle: orders
                    ? 'Consulta pagos y el avance de cada pedido.'
                    : zones
                    ? 'Gestiona la cobertura y las tarifas de envío.'
                    : 'Controla las existencias por producto y talla.',
              ),
              if (!widget.client) ...[
                if (!orders)
                  FilledButton.icon(
                    onPressed: () => context.push(
                      zones ? '/admin/zonas/nueva' : '/admin/inventario/nuevo',
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      zones ? 'Agregar zona' : 'Agregar talla y stock',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: busy ? null : expire,
                    icon: const Icon(Icons.timer_off_outlined, size: 18),
                    label: const Text('Liberar reservas vencidas'),
                  ),
                const SizedBox(height: 20),
              ],
              if (zones) ...[
                SurfaceSection(
                  tint: accentWash,
                  child: const Text(
                    'Las tarifas de las zonas activas se muestran en el checkout y se aplican al confirmar el pedido.',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: orders
                      ? 'Buscar pedido o destinatario en esta página'
                      : zones
                      ? 'Buscar zona en esta página'
                      : 'Buscar producto o talla en esta página',
                ),
              ),
              const SizedBox(height: 14),
              if (orders && !widget.client) ...[
                OutlinedButton.icon(
                  onPressed: selectDates,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    dates == null
                        ? 'Filtrar por fecha o rango'
                        : '${day(dates!.start)} al ${day(dates!.end)}',
                  ),
                ),
                if (dates != null)
                  TextButton(
                    onPressed: () => setState(() {
                      dates = null;
                      cursors
                        ..clear()
                        ..add(null);
                    }),
                    child: const Text('Quitar filtro de fechas'),
                  ),
                const Text(
                  'Fechas de creación de pedidos, zona horaria de Perú.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 14),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in [
                      'Todos',
                      if (orders) ...[
                        'Pendientes',
                        'En preparación',
                        'Entregados',
                      ] else if (zones) ...[
                        'Activas',
                        'Inactivas',
                      ] else ...[
                        'Stock bajo',
                        'Agotados',
                      ],
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: filter == f,
                          labelStyle: TextStyle(
                            color: filter == f ? Colors.white : ink,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() => filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${entries.length} registros en esta página',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                const EmptyState(
                  'Sin registros por aquí',
                  'Los registros disponibles aparecerán en esta sección. Si aplicaste filtros, prueba con Todos.',
                ),
              for (final entry in entries)
                orders
                    ? _order(entry)
                    : zones
                    ? _zone(entry)
                    : _inventory(entry),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cursors.length == 1
                          ? null
                          : () => setState(() {
                              cursors.removeLast();
                              filter = 'Todos';
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
                              filter = 'Todos';
                            }),
                      child: const Text('Siguiente'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _order(StoreEntry entry) {
    final order = entry.data;
    final delivery = order['delivery'] is Map
        ? Json.from(order['delivery'] as Map)
        : <String, dynamic>{};
    final items = order['items'] as List? ?? [];
    return SheetCard(
      color:
          order['status'] == 'CANCELADO' ||
              order['paymentStatus'] == 'CANCELADO'
          ? const Color(0xFFFFEBEE)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order['paymentStatus'] == 'SIMULADO')
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tag('PAGO REALIZADO'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  shortOrder(entry.id),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Flexible(
                child: StatusPill(
                  order['paymentStatus'] as String? ?? 'PENDIENTE',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!widget.client)
            Text(
              '${delivery['recipientName'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          if (order['createdAt'] != null)
            Text(
              _date(order['createdAt'] as String),
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          const SizedBox(height: 10),
          if (order['reservationState'] == 'ACTIVE')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Reserva hasta ${_date(order['reservationExpiresAt'] as String? ?? '')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFAB3500)),
              ),
            ),
          for (final item in items) OrderItemRow(Json.from(item as Map)),
          if (items.isEmpty) Text(entry.subtitle),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL DEL PEDIDO',
                      style: TextStyle(
                        fontSize: 9,
                        color: muted,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      money(entry.amountCents ?? 0),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: StatusPill(
                  order['fulfillmentStatus'] as String? ?? 'SIN_INICIAR',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => open(entry),
            style:
                order['paymentStatus'] == 'PENDIENTE' ||
                    order['paymentStatus'] == 'RECHAZADO'
                ? accentButton
                : null,
            child: Text(
              widget.client ? 'Ver detalle y pago →' : 'Gestionar pedido →',
            ),
          ),
        ],
      ),
    );
  }

  Widget _zone(StoreEntry entry) => SheetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Color(0xFFAB3500),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TARIFA DE ENVÍO',
                    style: TextStyle(
                      fontSize: 9,
                      color: muted,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    money(entry.amountCents ?? 0),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(entry.data['active'] == true ? 'Activa' : 'Inactiva'),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => open(entry),
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Editar zona y estado'),
        ),
      ],
    ),
  );
  Widget _inventory(StoreEntry entry) {
    final stock = entry.data;
    final productId = stock['productId'] as String?;
    final product = productId == null
        ? null
        : ref
              .watch(catalogProductProvider((admin: true, id: productId)))
              .asData
              ?.value;
    final available = stock['available'] as int? ?? 0,
        reserved = stock['reserved'] as int? ?? 0;
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product?.name ?? entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tag('EU ${stock['size'] ?? '—'}', color: ink),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final metric in [
                  ('Disponible', available),
                  ('Reservado', reserved),
                  ('Total', available + reserved),
                ])
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${metric.$2}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: metric.$1 == 'Disponible' && available <= 2
                                ? const Color(0xFFAB3500)
                                : ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          metric.$1,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (available <= 2)
            const Text(
              'Stock bajo: revisar reposición',
              style: TextStyle(color: Color(0xFFAB3500), fontSize: 11),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => open(entry),
            child: const Text('Ajustar existencias'),
          ),
        ],
      ),
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Fecha no disponible';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
