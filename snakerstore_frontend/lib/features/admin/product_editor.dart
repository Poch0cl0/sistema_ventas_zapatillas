import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../client/product_image.dart';

class ProductEditor extends ConsumerStatefulWidget {
  const ProductEditor({super.key, this.id});
  final String? id;
  @override
  ConsumerState<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends ConsumerState<ProductEditor> {
  final form = GlobalKey<FormState>();
  late final Product? original;
  late final TextEditingController name, brand, description, price;
  String category = 'Urbano';
  bool active = true, dirty = false, saved = false;
  final List<Uint8List> images = [];
  @override
  void initState() {
    super.initState();
    original = ref
        .read(productsProvider)
        .where((p) => p.id == widget.id)
        .firstOrNull;
    name = TextEditingController(text: original?.name);
    brand = TextEditingController(text: original?.brand);
    description = TextEditingController(text: original?.description);
    price = TextEditingController(
      text: original == null
          ? ''
          : '${original!.priceCents ~/ 100}.${(original!.priceCents % 100).toString().padLeft(2, '0')}',
    );
    category = original?.category ?? 'Urbano';
    active = original?.active ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    brand.dispose();
    description.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    try {
      final files = await ImagePicker().pickMultiImage();
      final bytes = <Uint8List>[];
      for (final file in files.take(5 - images.length)) {
        if (await file.length() > 5 * 1024 * 1024) {
          if (mounted) {
            notice(context, 'Cada imagen debe pesar hasta 5 MB.');
          }
          continue;
        }
        bytes.add(await file.readAsBytes());
      }
      if (mounted) {
        setState(() {
          images.addAll(bytes);
          dirty = true;
        });
      }
    } catch (_) {
      if (mounted) {
        notice(context, 'No se pudo abrir la galería.');
      }
    }
  }

  Future<void> leave() async {
    if (!dirty || saved) {
      if (mounted) {
        context.pop();
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Hay cambios sin guardar en el formulario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => saved = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && original == null) {
      return const StorePage(
        title: 'Producto',
        admin: true,
        child: EmptyState(
          'Producto no encontrado',
          'Regresa al catálogo administrativo.',
        ),
      );
    }
    return PopScope(
      canPop: !dirty || saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          leave();
        }
      },
      child: StorePage(
        title: original == null ? 'Nuevo producto' : 'Editar producto',
        admin: true,
        child: Form(
          key: form,
          onChanged: () {
            if (!dirty) {
              setState(() => dirty = true);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Heading(
                original == null ? 'Un nuevo favorito.' : 'Cuida cada detalle.',
                subtitle: 'Información del producto',
              ),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                ),
                validator: requiredText,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: brand,
                decoration: const InputDecoration(labelText: 'Marca'),
                validator: requiredText,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final c in ['Urbano', 'Running'])
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() {
                  category = v!;
                  dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: requiredText,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                decoration: const InputDecoration(
                  labelText: 'Precio en soles',
                  prefixText: 'S/ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    v != null &&
                        RegExp(r'^\d{1,6}([.,]\d{1,2})?$').hasMatch(v) &&
                        int.parse(v.replaceAll(RegExp(r'[.,]'), '')) > 0
                    ? null
                    : 'Ingresa un precio mayor a cero, con máximo 2 decimales',
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Producto activo'),
                subtitle: const Text('Visible en el catálogo de ejemplo'),
                value: active,
                onChanged: (v) => setState(() {
                  active = v;
                  dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'Imágenes del producto',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (original != null) ProductImage(original!, height: 140),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < images.length; i++)
                    SizedBox(
                      width: 90,
                      height: 110,
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.memory(
                              images[i],
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar imagen',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              images.removeAt(i);
                              dirty = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: images.length >= 5 ? null : pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Seleccionar fotos · máximo 5'),
              ),
              const InfoNote(
                'Las fotos se previsualizan en este formulario. Su carga y almacenamiento mediante NestJS y Cloudinary quedan para la integración.',
              ),
              const InfoNote('Gestiona tallas y cantidades en Inventario.'),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) {
                    return;
                  }
                  final parts = price.text.replaceAll(',', '.').split('.');
                  final cents =
                      int.parse(parts[0]) * 100 +
                      int.parse(
                        (parts.length == 2 ? parts[1] : '').padRight(2, '0'),
                      );
                  final p = Product(
                    id:
                        original?.id ??
                        'demo-${DateTime.now().millisecondsSinceEpoch}',
                    name: name.text.trim(),
                    brand: brand.text.trim(),
                    description: description.text.trim(),
                    category: category,
                    priceCents: cents,
                    active: active,
                    image: original?.image ?? 'assets/images/sneaker_1.png',
                  );
                  ref.read(productsProvider.notifier).save(p);
                  setState(() => saved = true);
                  notice(
                    context,
                    'Producto de ejemplo guardado. Las fotos no se han subido.',
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      context.pop();
                    }
                  });
                },
                child: const Text('Guardar producto de ejemplo'),
              ),
              TextButton(onPressed: leave, child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }
}
