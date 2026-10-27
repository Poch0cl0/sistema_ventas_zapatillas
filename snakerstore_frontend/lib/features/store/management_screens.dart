import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import '../catalog/catalog_repository.dart';
import '../catalog/product_model_view.dart';
import '../catalog/product_attributes.dart';
import '../admin/store_read_repository.dart';
import 'commerce_screens.dart';
import 'store_repository.dart';
import '../delivery/delivery_repository.dart';
import '../delivery/delivery_location_screen.dart';

enum ManagementKind { product, inventory, zone }

class ManagementEditor extends ConsumerStatefulWidget {
  const ManagementEditor({
    super.key,
    required this.kind,
    this.id,
    this.productId,
  });
  final ManagementKind kind;
  final String? id, productId;
  @override
  ConsumerState<ManagementEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<ManagementEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late Future<void> setup;
  List<Json> products = [];
  List<String> images = [];
  String? modelUrl;
  String? bundledModel;
  bool tryOnEnabled = false;
  String gender = 'SIN_ESPECIFICAR';
  final colors = <String>{};
  String? productId;
  bool active = true, busy = false;
  String? savedId;
  DeliveryLocation? origin;
  final selectedSizes = <String>{};
  Future<void> selectOrigin() async {
    FocusScope.of(context).unfocus();
    final value = await Navigator.of(context).push<DeliveryLocation>(
      MaterialPageRoute(
        builder: (_) =>
            DeliveryLocationScreen(initial: origin, selectingOrigin: true),
      ),
    );
    if (value != null && mounted) setState(() => origin = value);
  }

  TextEditingController field(String key) =>
      fields.putIfAbsent(key, TextEditingController.new);
  @override
  void initState() {
    super.initState();
    productId = widget.productId;
    savedId = widget.id;
    setup = load();
  }

  Future<void> load() async {
    final repo = ref.read(storeRepositoryProvider);
    if (widget.kind == ManagementKind.inventory) {
      products = await repo.all('/admin/products');
      if (widget.id != null) {
        final inventory = await repo.all('/admin/inventory');
        final current = inventory.firstWhere((e) => e['id'] == widget.id);
        productId = current['productId'] as String;
        field('size').text = current['size'] as String;
      }
      return;
    }
    if (widget.id == null) return;
    final Json current;
    if (widget.kind == ManagementKind.product) {
      current = await repo.get('/admin/products/${widget.id}');
      final product = CatalogProduct.fromJson(current);
      modelUrl = product.modelUrl;
      bundledModel = product.bundledModel;
      tryOnEnabled = product.tryOnEnabled;
      gender = product.gender;
      colors.addAll(product.colors);
      images = (current['images'] as List)
          .map((e) => e['secure_url'] as String)
          .toList();
    } else {
      current = (await repo.all('/admin/delivery-zones'))
          .firstWhere((e) => e['id'] == widget.id);
    }
    active = current['active'] as bool;
    if (widget.kind == ManagementKind.zone)
      origin = DeliveryLocation.originFrom(current);
    for (final key in ['name', 'description', 'brand', 'category']) {
      if (current[key] != null) field(key).text = current[key] as String;
    }
    final price =
        current[widget.kind == ManagementKind.product
                ? 'priceCents'
                : 'feeCents']
            as int;
    field('amount').text = (price / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    String key,
    String label, {
    int max = 120,
    bool numeric = false,
    String? Function(String?)? validator,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TextFormField(
      controller: field(key),
      enabled: enabled && !busy,
      maxLength: max,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(signed: true, decimal: true)
          : TextInputType.text,
      minLines: key == 'description' ? 3 : 1,
      maxLines: key == 'description' ? 5 : 1,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ??
          (v) => (v?.trim().isEmpty ?? true) ? 'Completa este campo' : null,
    ),
  );
  int cents() {
    final text = field('amount').text.trim().replaceAll(',', '.');
    final parts = text.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  String? amountValidator(String? v) {
    final value = v?.trim().replaceAll(',', '.') ?? '';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value))
      return 'Ingresa un importe positivo con hasta 2 decimales';
    final limit = widget.kind == ManagementKind.product ? 1000000 : 10000;
    return (double.tryParse(value) ?? double.infinity) > limit
        ? 'El importe excede el máximo permitido'
        : null;
  }

  void refresh() {
    ref.invalidate(catalogPageProvider);
    ref.invalidate(catalogProductProvider);
    ref.invalidate(storePageProvider);
    ref.invalidate(availabilityProvider);
    ref.invalidate(adminOverviewProvider);
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      if (widget.kind == ManagementKind.inventory && savedId == null) {
        final custom = field('size').text.trim();
        final pending = {...selectedSizes, if (custom.isNotEmpty) custom};
        for (final size in pending) {
          await repo.write(
            'POST',
            '/admin/inventory',
            data: {
              'productId': productId,
              'size': size,
              'quantity': int.parse(field('quantity').text.trim()),
              if (field('reason').text.trim().isNotEmpty)
                'reason': field('reason').text.trim(),
            },
          );
          selectedSizes.remove(size);
          if (size == custom) field('size').clear();
          refresh();
        }
        if (mounted) context.pop();
        return;
      }
      final Json payload;
      final String path;
      switch (widget.kind) {
        case ManagementKind.product:
          path = '/admin/products';
          payload = {
            'name': field('name').text.trim(),
            'description': field('description').text.trim(),
            'brand': field('brand').text.trim(),
            'category': field('category').text.trim(),
            'priceCents': cents(),
            'active': active,
            'tryOnEnabled': tryOnEnabled,
            'gender': gender,
            'colors': colors.toList(),
          };
        case ManagementKind.zone:
          path = '/admin/delivery-zones';
          payload = {
            'name': field('name').text.trim(),
            'feeCents': cents(),
            'active': active,
            if (origin != null) ...{
              'originLat': origin!.lat,
              'originLon': origin!.lon,
            },
          };
        case ManagementKind.inventory:
          path = '/admin/inventory';
          payload = savedId == null
              ? {
                  'productId': productId,
                  'size': field('size').text.trim(),
                  'quantity': int.parse(field('quantity').text.trim()),
                  if (field('reason').text.trim().isNotEmpty)
                    'reason': field('reason').text.trim(),
                }
              : {
                  'delta': int.parse(field('quantity').text.trim()),
                  if (field('reason').text.trim().isNotEmpty)
                    'reason': field('reason').text.trim(),
                };
      }
      final result = await repo.write(
        savedId == null ? 'POST' : 'PATCH',
        '$path${savedId == null ? '' : '/$savedId'}',
        data: payload,
      );
      if (!mounted) return;
      savedId = result['id'] as String;
      refresh();
      if (widget.kind == ManagementKind.product) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto guardado. Ya puedes adjuntar sus fotos.'),
          ),
        );
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    if (busy || savedId == null) return;
    setState(() => busy = true);
    try {
      final files = await ImagePicker().pickMultiImage();
      if (files.isEmpty) return;
      if (files.length > 5 || files.length + images.length > 10)
        throw const AppFailure(
          'Selecciona hasta 5 fotos por carga y 10 por producto.',
        );
      final uploads = <MultipartFile>[];
      for (final f in files) {
        final bytes = await f.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024)
          throw const AppFailure('Cada foto debe pesar como máximo 5 MiB.');
        uploads.add(MultipartFile.fromBytes(bytes, filename: f.name));
      }
      final result = await ref
          .read(storeRepositoryProvider)
          .write(
            'POST',
            '/admin/products/$savedId/images',
            data: FormData.fromMap({'files': uploads}),
          );
      if (!mounted) return;
      setState(
        () => images = (result['images'] as List)
            .map((e) => e['secure_url'] as String)
            .toList(),
      );
      refresh();
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uploadModel() async {
    if (busy || savedId == null) return;
    setState(() => busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['glb'],
      );
      if (file == null) return;
      const limit = 10 * 1024 * 1024;
      final length = await file.length();
      if (length == null || length <= 0 || length > limit)
        throw const AppFailure('Selecciona un modelo GLB de hasta 10 MiB.');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > limit)
        throw const AppFailure('El modelo debe pesar como máximo 10 MiB.');
      final result = await ref
          .read(storeRepositoryProvider)
          .write(
            'POST',
            '/admin/products/$savedId/model',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(bytes, filename: file.name),
            }),
          );
      if (!mounted) return;
      setState(() {
        modelUrl = CatalogProduct.fromJson(result).modelUrl;
        tryOnEnabled = false;
      });
      refresh();
      notice(context, 'Modelo 3D guardado como vista principal del producto.');
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeModel() async {
    if (busy || savedId == null) return;
    setState(() => busy = true);
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .write('DELETE', '/admin/products/$savedId/model');
      if (!mounted) return;
      setState(() {
        modelUrl = CatalogProduct.fromJson(result).modelUrl;
        tryOnEnabled = false;
      });
      refresh();
      notice(
        context,
        modelUrl == null
            ? 'Modelo quitado. Las fotos vuelven a ser la vista principal.'
            : 'Se recuperó el modelo 3D incluido. Revisa y activa nuevamente el probador.',
      );
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => KineticScaffold(
    appBar: StoreAppBar(
      admin: true,
      back: true,
      title: switch (widget.kind) {
        ManagementKind.product => 'Editar producto',
        ManagementKind.zone => 'Zona de delivery',
        ManagementKind.inventory =>
          savedId == null ? 'Nueva talla' : 'Ajustar existencias',
      },
    ),
    bottomNavigationBar: StoreBottomBar(
      index: widget.kind == ManagementKind.product
          ? 1
          : widget.kind == ManagementKind.inventory
          ? 2
          : 4,
      admin: true,
    ),
    body: FutureBuilder<void>(
      future: setup,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return EmptyState(
            'No se pudo abrir el formulario',
            errorMessage(snapshot.error!),
            label: 'Reintentar',
            action: () => setState(() => setup = load()),
          );
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        return Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: spaced([
              SectionHeading(
                switch (widget.kind) {
                  ManagementKind.product =>
                    savedId == null ? 'Nuevo producto' : 'Editar producto',
                  ManagementKind.inventory =>
                    savedId == null
                        ? 'Agregar talla y stock'
                        : 'Ajustar existencias',
                  ManagementKind.zone =>
                    savedId == null
                        ? 'Nueva zona de delivery'
                        : 'Editar zona de delivery',
                },
                eyebrow: 'Administración',
                subtitle: switch (widget.kind) {
                  ManagementKind.product =>
                    'Información, precio y visibilidad de tu catálogo.',
                  ManagementKind.inventory => 'Selecciona tallas y gestiona sus existencias. El motivo es opcional.',
                  ManagementKind.zone =>
                    'Define la cobertura y tarifa que verá el cliente.',
                },
              ),
              if (widget.kind != ManagementKind.inventory)
                SurfaceSection(
                  title: widget.kind == ManagementKind.product
                      ? 'Información del producto'
                      : 'Cobertura y tarifa',
                  icon: widget.kind == ManagementKind.product
                      ? Icons.inventory_2_outlined
                      : Icons.map_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced([
                      input(
                        'name',
                        'Nombre',
                        max: widget.kind == ManagementKind.zone ? 100 : 120,
                      ),
                      if (widget.kind == ManagementKind.product) ...[
                        input('brand', 'Marca', max: 80),
                        input('category', 'Categoría', max: 80),
                        input('description', 'Descripción', max: 2000),
                        DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(
                            labelText: 'Género',
                          ),
                          items: [
                            for (final item in productGenders.entries)
                              DropdownMenuItem(
                                value: item.key,
                                child: Text(item.value),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) => setState(() => gender = value!),
                        ),
                        const Text('Colores del producto'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in productColors.entries)
                              FilterChip(
                                label: Text(item.value.$1),
                                avatar: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: item.value.$2,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black26),
                                  ),
                                ),
                                selected: colors.contains(item.key),
                                onSelected: busy
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected) {
                                          colors.add(item.key);
                                        } else {
                                          colors.remove(item.key);
                                        }
                                      }),
                              ),
                          ],
                        ),
                      ],
                      input(
                        'amount',
                        widget.kind == ManagementKind.product
                            ? 'Precio en soles'
                            : 'Tarifa en soles',
                        numeric: true,
                        validator: amountValidator,
                      ),
                      SwitchListTile(
                        title: const Text('Activo'),
                        value: active,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => active = v),
                      ),
                    ]),
                  ),
                )
              else
                SurfaceSection(
                  title: 'Talla y movimiento',
                  icon: Icons.layers_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced([
                      DropdownButtonFormField<String>(
                        initialValue: productId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Producto',
                        ),
                        items: [
                          for (final p in products)
                            DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                p['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy || savedId != null
                            ? null
                            : (v) => setState(() => productId = v),
                        validator: (v) =>
                            v == null ? 'Selecciona un producto' : null,
                      ),
                      if (savedId == null) ...[
                        const Text('Selecciona una o varias tallas EU'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var size = 28; size <= 48; size++)
                              FilterChip(
                                label: Text('$size'),
                                selected: selectedSizes.contains('$size'),
                                onSelected: busy
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected) {
                                          selectedSizes.add('$size');
                                        } else {
                                          selectedSizes.remove('$size');
                                        }
                                      }),
                              ),
                          ],
                        ),
                      ],
                      input(
                        'size',
                        savedId == null
                            ? 'Otra talla EU (opcional)'
                            : 'Talla EU',
                        max: 2,
                        numeric: true,
                        enabled: savedId == null,
                        validator: (v) =>
                            ((v?.trim().isEmpty ?? true) &&
                                    selectedSizes.isNotEmpty) ||
                                RegExp(r'^[1-9][0-9]?$')
                                    .hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Usa una talla de 1 a 99',
                      ),
                      input(
                        'quantity',
                        savedId == null
                            ? 'Stock inicial para cada talla seleccionada'
                            : 'Unidades a sumar o restar (ejemplo: -2)',
                        numeric: true,
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          return n == null ||
                                  n.abs() > 1000000 ||
                                  (savedId == null ? n < 0 : n == 0)
                              ? 'Ingresa una cantidad válida'
                              : null;
                        },
                      ),
                      input(
                        'reason',
                        'Motivo del movimiento (opcional)',
                        max: 300,
                        validator: (_) => null,
                      ),
                      const InfoNote(
                        'El ajuste modifica las unidades disponibles. Las unidades reservadas se gestionan con los pedidos.',
                      ),
                    ]),
                  ),
                ),
              if (widget.kind == ManagementKind.zone)
                SurfaceSection(
                  title: 'Punto de salida de la zona',
                  icon: Icons.storefront_outlined,
                  child: FormField<DeliveryLocation>(
                    key: ValueKey(origin),
                    initialValue: origin,
                    validator: (value) => value == null
                        ? 'Marca el punto de salida en el mapa.'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Elige la tienda o almacén desde donde se trazarán las rutas hacia tus clientes.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: busy ? null : selectOrigin,
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            origin == null
                                ? 'Seleccionar origen en el mapa'
                                : 'Cambiar punto de salida',
                          ),
                        ),
                        if (origin != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Origen: ${origin!.label}',
                              style: const TextStyle(fontSize: 12),
                            ),
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
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Guardando…' : 'Guardar'),
              ),
              if (widget.kind == ManagementKind.product && savedId != null) ...[
                SurfaceSection(
                  title: 'Modelo 3D (opcional)',
                  icon: Icons.view_in_ar_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced([
                      const Text(
                        'Sube un archivo .glb con sus texturas incluidas (máximo 10 MiB). Se mostrará primero en el catálogo; las fotos se conservan.',
                      ),
                      if (bundledModel != null)
                        const Text(
                          'Este artículo incluye un modelo 3D de demostración dentro de la app. Puedes reemplazarlo por un GLB propio.',
                        ),
                      if (modelUrl != null) ...[
                        SizedBox(
                          height: 240,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ProductModelView(
                              key: ValueKey(modelUrl),
                              url: modelUrl!,
                              name: field('name').text,
                              poster: images.firstOrNull,
                              interactive: true,
                            ),
                          ),
                        ),
                        const Text(
                          'Arrastra para girar y usa dos dedos para acercar.',
                        ),
                      ],
                      OutlinedButton.icon(
                        onPressed: busy ? null : uploadModel,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          modelUrl == null
                              ? 'Subir modelo 3D'
                              : 'Reemplazar modelo 3D',
                        ),
                      ),
                      if (modelUrl != null && !modelUrl!.startsWith('assets/'))
                        TextButton.icon(
                          onPressed: busy ? null : removeModel,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Quitar modelo 3D'),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Disponible para probar con cámara'),
                        subtitle: const Text(
                          'Revisa que el GLB tenga la punta hacia +Z y la suela hacia -Y. El pie derecho se genera por simetría. Guarda después de activar.',
                        ),
                        value: tryOnEnabled,
                        onChanged: busy || modelUrl == null
                            ? null
                            : (value) => setState(() => tryOnEnabled = value),
                      ),
                      const Text(
                        'Flujo: guarda el artículo → sube el GLB → revisa el modelo → activa el probador → pulsa Guardar. Al reemplazar el modelo, el probador se desactiva para revisarlo otra vez.',
                      ),
                    ]),
                  ),
                ),
                SurfaceSection(
                  title: 'Galería de fotografías',
                  icon: Icons.add_photo_alternate_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced([
                      Text('${images.length}/10 fotos · JPEG, PNG o WebP'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final url in images)
                            Image.network(
                              url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : upload,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Adjuntar fotos'),
                      ),
                    ]),
                  ),
                ),
                SurfaceSection(
                  title: 'Gestión de tallas y stock',
                  icon: Icons.layers_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Agrega tallas y cantidades desde el inventario de este producto.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.push(
                                '/admin/inventario/nuevo?productId=$savedId',
                              ),
                        child: const Text('Agregar talla y stock'),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => context.go('/admin/productos'),
                  child: const Text('Volver a productos'),
                ),
              ],
            ]),
          ),
        );
      },
    ),
  );
}

class StoreSettingsEditor extends ConsumerStatefulWidget {
  const StoreSettingsEditor({super.key});
  @override
  ConsumerState<StoreSettingsEditor> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<StoreSettingsEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final enabled = <String, bool>{
    'YAPE': false,
    'PLIN': false,
    'TRANSFERENCIA': false,
  };
  bool pickup = false, busy = false;
  late Future<void> setup;
  TextEditingController field(String key) =>
      fields.putIfAbsent(key, TextEditingController.new);
  @override
  void initState() {
    super.initState();
    setup = load();
  }

  Future<void> load() async {
    Json s;
    try {
      s = await ref.read(storeRepositoryProvider).get('/admin/store-settings');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      rethrow;
    }
    for (final k in ['storeName', 'publicNotes']) {
      field(k).text = s[k] as String;
    }
    final p = Json.from(s['pickup'] as Map);
    pickup = p['enabled'] as bool;
    for (final k in ['address', 'instructions', 'openingHours']) {
      field(k).text = p[k] as String;
    }
    for (final m in s['paymentMethods'] as List) {
      final method = m['method'] as String;
      enabled[method] = m['enabled'] as bool;
      for (final k in [
        'holderName',
        'phone',
        'bankName',
        'accountNumber',
        'cci',
      ]) {
        field('$method.$k').text = m[k] as String? ?? '';
      }
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    String key,
    String label,
    int min,
    int max, {
    String? pattern,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TextFormField(
      controller: field(key),
      enabled: !busy,
      maxLength: max,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (optional && text.isEmpty) return null;
        return text.length < min ||
                (pattern != null && !RegExp(pattern).hasMatch(text))
            ? 'Revisa este campo'
            : null;
      },
    ),
  );
  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await ref
          .read(storeRepositoryProvider)
          .write(
            'PUT',
            '/admin/store-settings',
            data: {
              'storeName': field('storeName').text.trim(),
              'publicNotes': field('publicNotes').text.trim(),
              'pickup': {
                'enabled': pickup,
                for (final k in ['address', 'instructions', 'openingHours'])
                  k: field(k).text.trim(),
              },
              'paymentMethods': [
                for (final m in enabled.keys)
                  if (enabled[m] == true)
                    {
                      'method': m,
                      'enabled': true,
                      'holderName': field('$m.holderName').text.trim(),
                      if (m != 'TRANSFERENCIA')
                        'phone': field('$m.phone').text.trim(),
                      if (m == 'TRANSFERENCIA') ...{
                        'bankName': field('$m.bankName').text.trim(),
                        'accountNumber': field('$m.accountNumber').text.trim(),
                        if (field('$m.cci').text.trim().isNotEmpty)
                          'cci': field('$m.cci').text.trim(),
                      },
                    },
              ],
            },
          );
      ref.invalidate(storeDocumentProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) storeMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => KineticScaffold(
    appBar: const StoreAppBar(
      title: 'Configuración de tienda',
      admin: true,
      back: true,
    ),
    bottomNavigationBar: const StoreBottomBar(index: 0, admin: true),
    body: FutureBuilder<void>(
      future: setup,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return EmptyState(
            'No pudimos cargar la tienda',
            errorMessage(snapshot.error!),
            label: 'Reintentar',
            action: () => setState(() => setup = load()),
          );
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        return Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: spaced([
              const SectionHeading(
                'Tu tienda, a tu manera.',
                eyebrow: 'Administración / Configuración',
                subtitle: 'Actualiza los datos de recojo y los métodos de pago de tus clientes.',
              ),
              SurfaceSection(
                title: 'Información pública',
                icon: Icons.storefront_outlined,
                child: Column(
                  children: spaced([
                    input('storeName', 'Nombre de la tienda', 1, 120),
                    input(
                      'publicNotes',
                      'Instrucciones públicas de pago',
                      1,
                      2000,
                    ),
                  ]),
                ),
              ),
              SurfaceSection(
                title: 'Recojo en tienda',
                icon: Icons.location_on_outlined,
                child: Column(
                  children: spaced([
                    SwitchListTile(
                      title: const Text('Habilitar recojo en tienda'),
                      value: pickup,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => pickup = v),
                    ),
                    input('address', 'Dirección de la tienda', 5, 300),
                    input('openingHours', 'Horario de atención', 1, 300),
                    input('instructions', 'Instrucciones de recojo', 1, 1000),
                  ]),
                ),
              ),
              const SectionHeading(
                'Métodos de pago',
                subtitle:
                    'Habilita solo los métodos que vas a recibir y verificar.',
              ),
              for (final m in enabled.keys)
                SurfaceSection(
                  title: m,
                  icon: Icons.account_balance_wallet_outlined,
                  child: Column(
                    children: spaced([
                      SwitchListTile(
                        title: Text(m),
                        value: enabled[m]!,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => enabled[m] = v),
                      ),
                      if (enabled[m] == true) ...[
                        input('$m.holderName', 'Titular de $m', 1, 120),
                        if (m != 'TRANSFERENCIA')
                          input(
                            '$m.phone',
                            'Celular de $m',
                            9,
                            9,
                            pattern: r'^9\d{8}$',
                          )
                        else ...[
                          input('$m.bankName', 'Banco', 1, 120),
                          input(
                            '$m.accountNumber',
                            'Número de cuenta',
                            6,
                            30,
                            pattern: r'^\d{6,30}$',
                          ),
                          input(
                            '$m.cci',
                            'CCI (opcional)',
                            20,
                            20,
                            pattern: r'^\d{20}$',
                            optional: true,
                          ),
                        ],
                      ],
                    ]),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Guardando…' : 'Guardar configuración'),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
