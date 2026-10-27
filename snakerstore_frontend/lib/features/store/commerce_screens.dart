import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../catalog/product_visual.dart';
import '../../core/network/app_failure.dart';
import '../auth/application/session.dart';
import '../catalog/catalog_repository.dart';
import 'store_repository.dart';
import '../delivery/delivery_repository.dart';
import '../delivery/delivery_location_screen.dart';
import '../admin/store_read_repository.dart';
import 'receipt_screen.dart';
import 'simulation_payment_screen.dart';
import 'demo_checkout_screen.dart';

void storeMessage(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(error))));

class AddToCart extends ConsumerStatefulWidget {
  const AddToCart(this.product, {super.key});
  final CatalogProduct product;
  @override
  ConsumerState<AddToCart> createState() => _AddToCartState();
}

class _AddToCartState extends ConsumerState<AddToCart> {
  String? selectedSize;
  int units = 1;
  @override
  void didUpdateWidget(covariant AddToCart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      selectedSize = null;
      units = 1;
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(availabilityProvider(widget.product.id))
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Column(
          children: [
            Text(errorMessage(e)),
            TextButton(
              onPressed: () =>
                  ref.invalidate(availabilityProvider(widget.product.id)),
              child: const Text('Recargar tallas'),
            ),
          ],
        ),
        data: (sizes) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tallas EU', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (sizes.every((s) => (s['available'] as int) <= 0))
              const Text('Sin stock disponible'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in sizes)
                  ChoiceChip(
                    label: Text('EU ${s['size']}'),
                    selected: selectedSize == s['size'],
                    labelStyle: TextStyle(
                      color: selectedSize == s['size']
                          ? Colors.white
                          : (s['available'] as int) <= 0
                          ? muted
                          : ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (s['available'] as int) <= 0
                        ? null
                        : (_) => setState(() {
                            selectedSize = s['size'] as String;
                            units = 1;
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              selectedSize == null
                  ? 'Selecciona una talla para continuar.'
                  : 'Talla seleccionada: EU $selectedSize',
            ),
            if (selectedSize != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 7, color: success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${sizes.where((s) => s['size'] == selectedSize).map((s) => s['available']).firstOrNull ?? 0} unidades disponibles en esta talla',
                        style: const TextStyle(fontSize: 12, color: success),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Cantidad',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Restar una unidad',
                        onPressed: units <= 1
                            ? null
                            : () => setState(() => units--),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Text(
                        '$units',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Sumar una unidad',
                        onPressed:
                            selectedSize == null ||
                                units >= 100 ||
                                !sizes.any(
                                  (s) =>
                                      s['size'] == selectedSize &&
                                      (s['available'] as int) > units,
                                )
                            ? null
                            : () => setState(() => units++),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Añadir al carrito'),
                onPressed:
                    selectedSize == null ||
                        !sizes.any(
                          (s) =>
                              s['size'] == selectedSize &&
                              (s['available'] as int) > 0,
                        )
                    ? null
                    : () {
                        if (ref.read(sessionProvider).profile == null) {
                          context.push('/login');
                          return;
                        }
                        try {
                          final size = sizes.firstWhere(
                            (s) => s['size'] == selectedSize,
                          );
                          ref
                              .read(cartProvider.notifier)
                              .add(
                                widget.product,
                                selectedSize!,
                                size['available'] as int,
                                units: units,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Producto agregado al carrito',
                              ),
                              action: SnackBarAction(
                                label: 'Ver carrito',
                                onPressed: () => context.push('/carrito'),
                              ),
                            ),
                          );
                        } catch (e) {
                          storeMessage(context, e);
                        }
                      },
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/carrito'),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Ver carrito'),
            ),
          ],
        ),
      );
}

class ConnectedCartScreen extends ConsumerWidget {
  const ConnectedCartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold<int>(
      0,
      (sum, e) => sum + e.product.priceCents * e.quantity,
    );
    final profile = ref.watch(sessionProvider).profile;
    final count = cart.fold<int>(0, (sum, e) => sum + e.quantity);
    return KineticScaffold(
      appBar: const StoreAppBar(),
      bottomNavigationBar: const StoreBottomBar(index: 2),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: spaced([
          SectionHeading(
            'Mi carrito ($count)',
            eyebrow: 'Revisión de orden',
            trailing: cart.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Vaciar', style: TextStyle(fontSize: 12)),
                  ),
          ),
          const CheckoutSteps(0),
          if (cart.isEmpty)
            const EmptyState(
              'Tu carrito está vacío',
              'Agrega un producto desde el catálogo.',
            ),
          if (cart.isNotEmpty)
            SurfaceSection(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: accentWash,
                    child: Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFFAB3500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Tu compra',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'El siguiente paso es elegir la entrega.',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < cart.length; i++)
            SheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 86,
                        child: RemoteProductImage(
                          cart[i].product,
                          height: 90,
                          showModel: false,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart[i].product.brand.toUpperCase(),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 9,
                                letterSpacing: .8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cart[i].product.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'EU ${cart[i].size}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              money(cart[i].product.priceCents),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar producto',
                        onPressed: () =>
                            ref.read(cartProvider.notifier).quantity(i, 0),
                        icon: const Icon(Icons.delete_outline, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cantidad',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reducir cantidad',
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .quantity(i, cart[i].quantity - 1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${cart[i].quantity}'),
                      IconButton(
                        tooltip: 'Aumentar cantidad',
                        onPressed: cart[i].quantity >= 100
                            ? null
                            : () => ref
                                  .read(cartProvider.notifier)
                                  .quantity(i, cart[i].quantity + 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (cart.isNotEmpty) ...[
            const SurfaceSection(
              tint: accentWash,
              child: Text(
                'Los precios y la disponibilidad se validarán al confirmar tu orden. El stock se reserva por 24 horas después de generar el pedido.',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
            SurfaceSection(
              title: 'Resumen del pedido',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AmountRow('Subtotal ($count pares)', total),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Envío estimado',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Tag('En checkout', color: muted),
                    ],
                  ),
                  const Divider(height: 32),
                  AmountRow('TOTAL ESTIMADO', total, bold: true),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push('/checkout'),
                    style: accentButton,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(child: Text('Continuar compra')),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          TextButton.icon(
            onPressed: () => context.go('/catalogo'),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('Seguir explorando el catálogo'),
          ),
        ]),
      ),
    );
  }
}

class ConnectedCheckoutScreen extends ConsumerStatefulWidget {
  const ConnectedCheckoutScreen({super.key});
  @override
  ConsumerState<ConnectedCheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<ConnectedCheckoutScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      reference = TextEditingController();
  late Future<(Json, List<Json>)> setup;
  String type = 'DELIVERY';
  String? zone;
  DeliveryLocation? location;
  List<Json> loadedZones = [];
  bool simulationEnabled = false;
  bool demoGatewayEnabled = false;
  Future<void> selectLocation() async {
    FocusScope.of(context).unfocus();
    final selectedZone = (updatedZones ?? loadedZones)
        .where((z) => z['id'] == zone)
        .firstOrNull;
    final selected = await Navigator.of(context).push<DeliveryLocation>(
      MaterialPageRoute(
        builder: (_) => DeliveryLocationScreen(
          initial: location,
          zoneId: zone,
          origin: selectedZone == null
              ? null
              : DeliveryLocation.originFrom(selectedZone),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => location = selected);
  }

  bool busy = false;
  bool loadingZones = false;
  String? zonesError;
  List<Json>? updatedZones;
  Future<void> reloadZones() async {
    setState(() {
      loadingZones = true;
      zonesError = null;
    });
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .all('/delivery-zones', public: true);
      if (!mounted) return;
      setState(() {
        updatedZones = result;
        if (!result.any((z) => z['id'] == zone)) zone = null;
      });
    } catch (e) {
      if (mounted) setState(() => zonesError = errorMessage(e));
    } finally {
      if (mounted) setState(() => loadingZones = false);
    }
  }

  Future<void> selectZone(
    List<Json> zones,
    FormFieldState<String> field,
  ) async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Selecciona tu zona de entrega',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: zones.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final z = zones[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      title: Text(z['name'] as String),
                      subtitle: Text('Envío: ${money(z['feeCents'] as int)}'),
                      trailing: Icon(
                        z['id'] == zone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      onTap: () => Navigator.pop(ctx, z['id'] as String),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => zone = selected);
      field.didChange(selected);
    }
  }

  @override
  void initState() {
    super.initState();
    name.text = ref.read(sessionProvider).profile?.name ?? '';
    setup = load();
  }

  Future<(Json, List<Json>)> load() async {
    final repo = ref.read(storeRepositoryProvider);
    final values = await Future.wait([
      repo.get('/store-settings', public: true),
      repo.all('/delivery-zones', public: true),
      repo.get('/checkout-options', public: true),
    ]);
    loadedZones = values[1] as List<Json>;
    simulationEnabled = (values[2] as Json)['simulationEnabled'] == true;
    demoGatewayEnabled = (values[2] as Json)['demoGatewayEnabled'] == true;
    return (values[0] as Json, values[1] as List<Json>);
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, reference]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final payload = <String, dynamic>{
      'items': cart.map((e) => e.item).toList(),
      'delivery': {
        'type': type,
        'recipientName': name.text.trim(),
        'phone': phone.text.trim(),
        if (type == 'DELIVERY') ...{
          'zoneId': zone,
          if (location != null) ...location!.json,
          if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
          if (reference.text.trim().isNotEmpty)
            'reference': reference.text.trim(),
        },
      },
    };
    final key = ref.read(cartProvider.notifier).checkoutKey(payload);
    setState(() => busy = true);
    try {
      final order = await ref
          .read(storeRepositoryProvider)
          .write('POST', '/orders', data: payload, key: key);
      if (!mounted) return;
      ref.invalidate(availabilityProvider);
      ref.read(cartProvider.notifier).clear();
      context.go('/pedido/${order['id']}');
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return KineticScaffold(
      appBar: const StoreAppBar(title: 'Entrega y confirmación', back: true),
      bottomNavigationBar: const StoreBottomBar(index: 2),
      body: FutureBuilder<(Json, List<Json>)>(
        future: setup,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return EmptyState(
              'No pudimos cargar la entrega',
              errorMessage(snapshot.error!),
              label: 'Reintentar',
              action: () => setState(() => setup = load()),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final (settings, initialZones) = snapshot.data!;
          final zones = updatedZones ?? initialZones;
          final pickup = Json.from(settings['pickup'] as Map);
          final methods = (settings['paymentMethods'] as List)
              .where((m) => m['enabled'] == true)
              .toList();
          final fee = type == 'DELIVERY'
              ? zones
                        .where((z) => z['id'] == zone)
                        .map((z) => z['feeCents'] as int)
                        .firstOrNull ??
                    0
              : 0;
          return Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: spaced([
                SectionHeading(
                  'Entrega de tu pedido',
                  eyebrow: settings['storeName'] as String,
                  subtitle: 'Elige cómo recibirlo y confirma dónde entregar tus pares.',
                ),
                const CheckoutSteps(1),
                if (simulationEnabled)
                  const SurfaceSection(
                    tint: accentWash,
                    title: 'Tu compra',
                    icon: Icons.payment_outlined,
                    child: Text(
                      'Después de crear el pedido puedes continuar sin pago o finalizar la compra para generar tu boleta.',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ),
                if (cart.isEmpty) const Text('El carrito está vacío.'),
                SurfaceSection(
                  title: '¿Cómo lo recibirás?',
                  icon: Icons.local_shipping_outlined,
                  child: DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de entrega',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'DELIVERY',
                        child: Text('Delivery'),
                      ),
                      if (pickup['enabled'] == true)
                        const DropdownMenuItem(
                          value: 'PICKUP',
                          child: Text('Recojo en tienda'),
                        ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => type = v!),
                  ),
                ),
                SurfaceSection(
                  title: 'Datos del destinatario',
                  icon: Icons.person_outline,
                  child: Column(
                    children: spaced([
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del destinatario',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 2
                            ? 'Ingresa al menos 2 caracteres'
                            : null,
                      ),
                      TextFormField(
                        controller: phone,
                        enabled: !busy,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Celular peruano',
                        ),
                        validator: (v) =>
                            RegExp(r'^9\d{8}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Ingresa un celular de 9 dígitos que empiece en 9',
                      ),
                    ]),
                  ),
                ),
                if (type == 'DELIVERY')
                  SurfaceSection(
                    title: 'Punto de recepción',
                    icon: Icons.location_on_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: spaced([
                        if (zones.isEmpty)
                          const InfoNote(
                            'No hay zonas de delivery disponibles. La tienda debe crear o activar sus zonas. Puedes actualizar la lista o elegir recojo si está habilitado.',
                          ),
                        if (zonesError != null)
                          Text(
                            zonesError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        FormField<String>(
                          key: ValueKey(zone),
                          initialValue: zone,
                          validator: (v) =>
                              v == null || !zones.any((z) => z['id'] == v)
                              ? 'Selecciona una zona disponible'
                              : null,
                          builder: (field) {
                            final selected = zones
                                .where((z) => z['id'] == zone)
                                .firstOrNull;
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: busy || loadingZones || zones.isEmpty
                                  ? null
                                  : () => selectZone(zones, field),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Zona de entrega',
                                  enabled:
                                      !busy &&
                                      !loadingZones &&
                                      zones.isNotEmpty,
                                  errorText: field.errorText,
                                  suffixIcon: const Icon(Icons.expand_more),
                                ),
                                child: Text(
                                  selected == null
                                      ? 'Selecciona tu zona'
                                      : '${selected['name']} · ${money(selected['feeCents'] as int)}',
                                ),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          onPressed: busy || loadingZones ? null : reloadZones,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            loadingZones
                                ? 'Actualizando zonas…'
                                : 'Actualizar zonas disponibles',
                          ),
                        ),
                        FormField<DeliveryLocation>(
                          key: ValueKey(location),
                          initialValue: location,
                          validator: (value) => value == null
                              ? 'Selecciona el punto de entrega en el mapa.'
                              : null,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: busy || zone == null
                                    ? null
                                    : selectLocation,
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  location == null
                                      ? 'Seleccionar ubicación en el mapa'
                                      : 'Cambiar punto de entrega',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                location == null
                                    ? 'Usa tu ubicación actual o toca el mapa para indicar dónde recibirás el pedido.'
                                    : 'Punto confirmado: ${location!.label}',
                              ),
                              if (field.errorText != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    field.errorText!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const InfoNote(
                          'El punto del mapa indica el destino. Selecciona también tu zona para calcular la tarifa de envío.',
                        ),
                        TextFormField(
                          controller: address,
                          enabled: !busy,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Dirección escrita (opcional)',
                            hintText:
                                'Puedes dejarla vacía si confirmaste el pin',
                          ),
                          validator: (v) =>
                              v != null &&
                                  v.trim().isNotEmpty &&
                                  v.trim().length < 5
                              ? 'Usa al menos 5 caracteres o deja el campo vacío'
                              : null,
                        ),
                        TextFormField(
                          controller: reference,
                          enabled: !busy,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText:
                                'Piso, departamento o referencia (opcional)',
                          ),
                        ),
                      ]),
                    ),
                  )
                else
                  SurfaceSection(
                    title: 'Recojo en tienda',
                    icon: Icons.storefront_outlined,
                    child: Text(
                      '${pickup['address']}\n${pickup['openingHours']}\n${pickup['instructions']}',
                      style: const TextStyle(height: 1.7),
                    ),
                  ),
                SurfaceSection(
                  title: 'Resumen de tu compra',
                  icon: Icons.receipt_long_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AmountRow(
                        'Subtotal estimado',
                        cart.fold<int>(
                          0,
                          (sum, e) => sum + e.product.priceCents * e.quantity,
                        ),
                      ),
                      AmountRow('Envío estimado', fee),
                      AmountRow(
                        'Total estimado',
                        cart.fold<int>(
                              0,
                              (sum, e) =>
                                  sum + e.product.priceCents * e.quantity,
                            ) +
                            fee,
                        bold: true,
                      ),
                    ],
                  ),
                ),
                InfoNote(
                  '${settings['publicNotes']}\nLa reserva dura 24 horas. Revisa el total definitivo del pedido antes de pagar.',
                ),
                if (methods.isEmpty &&
                    !simulationEnabled &&
                    !demoGatewayEnabled)
                  const InfoNote(
                    'La tienda todavía no tiene métodos de pago habilitados.',
                  ),
                FilledButton(
                  onPressed:
                      busy ||
                          loadingZones ||
                          cart.isEmpty ||
                          (methods.isEmpty &&
                              !simulationEnabled &&
                              !demoGatewayEnabled) ||
                          (type == 'DELIVERY' && zones.isEmpty)
                      ? null
                      : submit,
                  style: accentButton,
                  child: Text(
                    busy
                        ? 'Creando pedido…'
                        : 'Confirmar pedido y reservar stock',
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class ConnectedOrderScreen extends ConsumerStatefulWidget {
  const ConnectedOrderScreen({super.key, required this.id, this.admin = false});
  final String id;
  final bool admin;
  @override
  ConsumerState<ConnectedOrderScreen> createState() => _OrderState();
}

class _OrderState extends ConsumerState<ConnectedOrderScreen> {
  late Future<(Json, List<Json>)> data;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<(Json, List<Json>)> load() async {
    final repo = ref.read(storeRepositoryProvider);
    final order = await repo.get('/orders/${widget.id}');
    final payments = await repo.all('/orders/${widget.id}/payments');
    return (order, payments);
  }

  Future<void> action(String path, {String method = 'POST', Json? body}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(storeRepositoryProvider).write(method, path, data: body);
      ref.invalidate(availabilityProvider);
      ref.invalidate(storeDocumentProvider('/orders/${widget.id}'));
      ref.invalidate(storePageProvider);
      ref.invalidate(adminOverviewProvider);
      if (mounted) setState(() => data = load());
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approve(Json payment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar fondos recibidos'),
        content: Text(
          '¿Verificaste el ingreso de ${money(payment['amountCents'] as int)} con referencia ${payment['reference']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, aprobar pago'),
          ),
        ],
      ),
    );
    if (ok == true && mounted)
      await action('/admin/payments/${payment['id']}/approve');
  }

  Future<void> reject(Json payment) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de rechazo'),
        content: TextField(controller: controller, maxLength: 500),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3)
                Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && mounted)
      await action(
        '/admin/payments/${payment['id']}/reject',
        body: {'reason': reason},
      );
  }

  @override
  Widget build(BuildContext context) {
    final simulationEnabled =
        ref.watch(checkoutOptionsProvider).asData?.value['simulationEnabled'] ==
        true;
    return KineticScaffold(
      appBar: StoreAppBar(
        title: 'Detalle del pedido',
        admin: widget.admin,
        back: true,
        actions: [
          IconButton(
            onPressed: busy ? null : () => setState(() => data = load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: StoreBottomBar(index: 3, admin: widget.admin),
      body: FutureBuilder<(Json, List<Json>)>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return EmptyState(
              'No pudimos cargar el pedido',
              errorMessage(snapshot.error!),
              label: 'Reintentar',
              action: () => setState(() => data = load()),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final (order, payments) = snapshot.data!;
          final delivery = Json.from(order['delivery'] as Map);
          final destination = DeliveryLocation.fromDelivery(delivery);
          final expires = DateTime.tryParse(
            order['reservationExpiresAt'] as String? ?? '',
          );
          final open = order['reservationState'] == 'ACTIVE';
          final canPay =
              open &&
              ['PENDIENTE', 'RECHAZADO'].contains(order['paymentStatus']) &&
              expires != null &&
              expires.isAfter(DateTime.now());
          final simulated = order['isSimulation'] == true;
          final canSimulate =
              simulationEnabled &&
              ((canPay && order['currentPaymentId'] == null) ||
                  (simulated && order['paymentStatus'] == 'NO_REQUERIDO'));
          final next = order['fulfillmentStatus'] == 'PREPARANDO'
              ? (delivery['type'] == 'PICKUP' ? 'LISTO_RECOJO' : 'EN_REPARTO')
              : [
                  'LISTO_RECOJO',
                  'EN_REPARTO',
                ].contains(order['fulfillmentStatus'])
              ? 'ENTREGADO'
              : null;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: spaced([
              SectionHeading(
                shortOrder(order['id'] as String),
                eyebrow: widget.admin
                    ? 'Gestión de pedido'
                    : 'Detalle de tu compra',
                subtitle: widget.admin
                    ? 'Verifica el pago y gestiona la entrega.'
                    : 'Consulta el estado de tu pago y tus pares.',
              ),
              if (simulated)
                const SurfaceSection(
                  tint: accentWash,
                  child: Text(
                    'Pedido de prueba: no se ha cobrado dinero y no cuenta como venta real.',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              SurfaceSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTADO DEL PEDIDO',
                      style: TextStyle(
                        fontSize: 10,
                        color: muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(order['paymentStatus'] as String),
                        StatusPill(order['fulfillmentStatus'] as String),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      'Código completo: ${order['id']}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              if (expires != null && open)
                SurfaceSection(
                  tint: accentWash,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFFAB3500),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reserva hasta: ${expires.toLocal()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFAB3500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (open && expires != null && !expires.isAfter(DateTime.now()))
                const InfoNote(
                  'La reserva venció. Ya no se puede enviar ni aprobar el pago.',
                ),
              if (order['cancellationReason'] != null)
                Text('Cancelación: ${order['cancellationReason']}'),
              if (!['CANCELADO', 'VENCIDO'].contains(order['paymentStatus']))
                SurfaceSection(
                  title: 'Avance de tu pedido',
                  icon: Icons.local_shipping_outlined,
                  child: OrderTimeline(
                    payment: order['paymentStatus'] as String,
                    fulfillment: order['fulfillmentStatus'] as String,
                    pickup: delivery['type'] == 'PICKUP',
                  ),
                ),
              SurfaceSection(
                title: 'Artículos en la orden',
                icon: Icons.shopping_bag_outlined,
                child: Column(
                  children: [
                    for (final item in order['items'] as List)
                      OrderItemRow(Json.from(item as Map)),
                    const Divider(height: 28),
                    AmountRow('Subtotal', order['subtotalCents'] as int),
                    AmountRow('Envío', order['deliveryFeeCents'] as int),
                    AmountRow(
                      'Total definitivo',
                      order['totalCents'] as int,
                      bold: true,
                    ),
                    if (simulated)
                      const AmountRow('Importe realmente cobrado', 0),
                  ],
                ),
              ),
              SurfaceSection(
                title: delivery['type'] == 'DELIVERY'
                    ? 'Punto de recepción'
                    : 'Recojo en tienda',
                icon: Icons.location_on_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: spaced([
                    Text(
                      '${delivery['recipientName']} · ${delivery['phone']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (delivery['type'] == 'DELIVERY')
                      Text(
                        '${delivery['zoneName']}\n${delivery['address']}\n${delivery['reference'] ?? ''}',
                      )
                    else
                      Text(
                        '${delivery['pickupAddress']}\n${delivery['pickupOpeningHours']}\n${delivery['pickupInstructions']}',
                      ),
                    if (delivery['type'] == 'DELIVERY' && destination != null)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => DeliveryLocationScreen(
                                    initial: destination,
                                    readOnly: true,
                                    origin: DeliveryLocation.originFrom(
                                      delivery,
                                    ),
                                    orderId: widget.id,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Ver destino y ruta estimada'),
                      ),
                  ]),
                ),
              ),
              if (!widget.admin && canPay && order['currentPaymentId'] == null)
                DemoCheckoutButton(
                  orderId: widget.id,
                  onComplete: () {
                    if (mounted) setState(() => data = load());
                  },
                ),
              if (!widget.admin && canSimulate)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await context.push('/pedido/${widget.id}/pago');
                          if (mounted) setState(() => data = load());
                        },
                  icon: const Icon(Icons.payment_outlined, size: 18),
                  label: const Text('Finalizar compra'),
                ),
              if (order['paymentStatus'] == 'SIMULADO') ...[
                SurfaceSection(
                  title: 'Boleta',
                  icon: Icons.receipt_long_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        receiptStatusMessage(order['receiptStatus'] as String?),
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ReceiptScreen(
                              id: widget.id,
                              admin: widget.admin,
                            ),
                          ),
                        ),
                        child: const Text('Ver boleta y estado del correo'),
                      ),
                    ],
                  ),
                ),
              ],
              if (!widget.admin && canPay && !canSimulate && !simulated)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await context.push('/pedido/${widget.id}/pago');
                          if (mounted) setState(() => data = load());
                        },
                  style: accentButton,
                  child: const Text('Registrar pago →'),
                ),
              if (!widget.admin && open)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('¿Cancelar pedido?'),
                              content: const Text(
                                'Se liberarán las unidades reservadas.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Volver'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Cancelar pedido'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && mounted)
                            await action('/orders/${widget.id}/cancel');
                        },
                  child: const Text('Cancelar pedido'),
                ),
              if (widget.admin &&
                  (order['paymentStatus'] == 'APROBADO' ||
                      (simulated &&
                          [
                            'SIMULADO',
                            'NO_REQUERIDO',
                          ].contains(order['paymentStatus']))) &&
                  next != null)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(
                          '/admin/orders/${widget.id}/status',
                          method: 'PATCH',
                          body: {'status': next},
                        ),
                  child: Text('Marcar: ${statusLabel(next)}'),
                ),
              const SizedBox(height: 20),
              Text(
                'Historial de pagos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (payments.isEmpty)
                const Text('Todavía no se enviaron referencias de pago.'),
              for (final payment in payments)
                SheetCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: Color(0xFFAB3500),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${payment['method']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      StatusPill(payment['status'] as String),
                      const SizedBox(height: 12),
                      SelectableText(
                        'Referencia: ${payment['reference']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      AmountRow('Importe', payment['amountCents'] as int),
                      if (payment['rejectionReason'] != null)
                        Text('Motivo: ${payment['rejectionReason']}'),
                      if (widget.admin &&
                          payment['status'] == 'PENDIENTE_VERIFICACION' &&
                          open) ...[
                        FilledButton(
                          onPressed: busy ? null : () => approve(payment),
                          child: const Text('Verificar y aprobar'),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: busy ? null : () => reject(payment),
                          child: const Text('Rechazar con motivo'),
                        ),
                      ],
                    ],
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
            ]),
          );
        },
      ),
    );
  }
}

class ConnectedPaymentScreen extends ConsumerStatefulWidget {
  const ConnectedPaymentScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ConnectedPaymentScreen> createState() => _PaymentState();
}

class _PaymentState extends ConsumerState<ConnectedPaymentScreen> {
  final form = GlobalKey<FormState>();
  final reference = TextEditingController();
  String? method;
  bool busy = false;
  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await ref
          .read(storeRepositoryProvider)
          .write(
            'POST',
            '/orders/${widget.id}/payments',
            data: {
              'method': method,
              'reference': reference.text.trim().toUpperCase(),
            },
          );
      ref.invalidate(storeDocumentProvider('/orders/${widget.id}'));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeDocumentProvider('/store-settings'));
    final order = ref.watch(storeDocumentProvider('/orders/${widget.id}'));
    final value = order.asData?.value;
    final simulationEnabled =
        ref.watch(checkoutOptionsProvider).asData?.value['simulationEnabled'] ==
        true;
    if (value != null &&
        (value['isSimulation'] == true ||
            (simulationEnabled &&
                value['currentPaymentId'] == null &&
                ['PENDIENTE', 'RECHAZADO'].contains(value['paymentStatus'])))) {
      return SimulationPaymentScreen(id: widget.id);
    }
    return KineticScaffold(
      appBar: const StoreAppBar(title: 'Registro de pago', back: true),
      bottomNavigationBar: const StoreBottomBar(index: 3),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          'No se pudieron cargar los métodos',
          errorMessage(e),
          label: 'Reintentar',
          action: () =>
              ref.invalidate(storeDocumentProvider('/store-settings')),
        ),
        data: (s) {
          final methods = (s['paymentMethods'] as List)
              .where((m) => m['enabled'] == true)
              .map((m) => Json.from(m as Map))
              .toList();
          final selected = methods
              .where((m) => m['method'] == method)
              .firstOrNull;
          return Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: spaced([
                const SectionHeading(
                  'Registro de pago',
                  eyebrow: 'Confirma tu compra',
                  subtitle: 'Realiza la transferencia y envía la referencia para su verificación.',
                ),
                const CheckoutSteps(2),
                if (value != null &&
                    value['reservationState'] == 'ACTIVE' &&
                    value['currentPaymentId'] == null)
                  DemoCheckoutButton(orderId: widget.id),
                order.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(errorMessage(e)),
                  data: (o) => SurfaceSection(
                    title: 'Orden de compra ${shortOrder(widget.id)}',
                    child: Column(
                      children: [
                        for (final item in o['items'] as List)
                          OrderItemRow(Json.from(item as Map)),
                        const Divider(height: 26),
                        AmountRow(
                          'Total a transferir',
                          o['totalCents'] as int,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SurfaceSection(
                  tint: accentWash,
                  child: Text(
                    'Tu reserva dura 24 horas desde que se creó el pedido. El pago se confirma después de la revisión del administrador.',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
                SurfaceSection(
                  title: 'Elige tu método de pago',
                  icon: Icons.payments_outlined,
                  child: FormField<String>(
                    key: ValueKey(method),
                    initialValue: method,
                    validator: (v) =>
                        v == null || !methods.any((m) => m['method'] == v)
                        ? 'Selecciona un método de pago'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final m in methods)
                              ChoiceChip(
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(m['method'] as String),
                                ),
                                selected: method == m['method'],
                                labelStyle: TextStyle(
                                  color: method == m['method']
                                      ? Colors.white
                                      : ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                onSelected: busy
                                    ? null
                                    : (_) {
                                        setState(
                                          () => method = m['method'] as String,
                                        );
                                        field.didChange(method);
                                      },
                              ),
                          ],
                        ),
                        if (methods.isEmpty)
                          const Text(
                            'No hay métodos de pago habilitados.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        if (field.errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              field.errorText!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (selected != null)
                  SurfaceSection(
                    title: 'Instrucciones de ${selected['method']}',
                    icon: Icons.account_balance_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            [
                              'Titular: ${selected['holderName']}',
                              if (selected['phone'] != null)
                                'Celular: ${selected['phone']}',
                              if (selected['bankName'] != null)
                                'Banco: ${selected['bankName']}',
                              if (selected['accountNumber'] != null)
                                'Cuenta: ${selected['accountNumber']}',
                              if (selected['cci'] != null)
                                'CCI: ${selected['cci']}',
                            ].join('\n'),
                            style: const TextStyle(fontSize: 14, height: 1.9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final value = selected['method'] == 'TRANSFERENCIA'
                                ? selected['accountNumber']
                                : selected['phone'];
                            await Clipboard.setData(
                              ClipboardData(text: value as String? ?? ''),
                            );
                            if (context.mounted)
                              notice(context, 'Dato de pago copiado.');
                          },
                          icon: const Icon(Icons.copy_outlined, size: 17),
                          label: const Text('Copiar cuenta o celular'),
                        ),
                      ],
                    ),
                  ),
                SurfaceSection(
                  title: 'Ingresa los datos del pago',
                  icon: Icons.receipt_long_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Usa la referencia emitida por tu banco o aplicación de pago.',
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: reference,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Referencia o número de operación',
                        ),
                        validator: (v) =>
                            RegExp(r'^[A-Z0-9][A-Z0-9_-]{3,79}$')
                                .hasMatch(v?.trim().toUpperCase() ?? '')
                            ? null
                            : 'Usa de 4 a 80 letras, números, guiones o guiones bajos',
                      ),
                      InfoNote(s['publicNotes'] as String),
                      const InfoNote(
                        'La referencia se verifica manualmente. Enviarla no significa que el pago ya esté aprobado.',
                        icon: Icons.verified_user_outlined,
                      ),
                      FilledButton(
                        onPressed: busy || !order.hasValue || methods.isEmpty
                            ? null
                            : submit,
                        style: accentButton,
                        child: Text(
                          busy ? 'Enviando…' : 'Enviar referencia de pago →',
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
