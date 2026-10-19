import 'package:flutter/material.dart';

import '../../core/ui.dart';
import 'catalog_repository.dart';
import 'product_model_view.dart';

class RemoteProductImage extends StatelessWidget {
  const RemoteProductImage(
    this.product, {
    super.key,
    this.height = 250,
    this.showModel = true,
  });
  final CatalogProduct product;
  final double height;
  final bool showModel;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFF3F3F4),
      child: showModel && product.modelUrl != null
          ? ProductModelView(
              url: product.modelUrl!,
              name: product.name,
              poster: product.images.firstOrNull,
            )
          : product.images.isEmpty
          ? const Center(
              child: Icon(Icons.image_outlined, color: muted, size: 36),
            )
          : Image.network(
              product.images.first,
              fit: BoxFit.contain,
              semanticLabel: product.name,
              loadingBuilder: (_, image, progress) => progress == null
                  ? image
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: muted,
                  size: 36,
                ),
              ),
            ),
    ),
  );
}
