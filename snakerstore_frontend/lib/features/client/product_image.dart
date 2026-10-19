import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key, this.height = 150});
  final Product product;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      color: const Color(0xFFEEEEEF),
      height: height,
      width: double.infinity,
      child: Image.asset(
        product.image,
        fit: BoxFit.contain,
        semanticLabel: product.name,
        errorBuilder: (_, _, _) => const Icon(
          Icons.image_not_supported_outlined,
          size: 44,
          color: muted,
        ),
      ),
    ),
  );
}
