import 'package:flutter/material.dart';

const productGenders = {
  'HOMBRE': 'Hombre',
  'MUJER': 'Mujer',
  'UNISEX': 'Unisex',
  'SIN_ESPECIFICAR': 'Sin especificar',
};
const productColors = {
  'NEGRO': ('Negro', Color(0xFF202124)),
  'BLANCO': ('Blanco', Color(0xFFFFFFFF)),
  'GRIS': ('Gris', Color(0xFF8B8D91)),
  'AZUL': ('Azul', Color(0xFF2865BD)),
  'ROJO': ('Rojo', Color(0xFFD63838)),
  'VERDE': ('Verde', Color(0xFF33834B)),
  'AMARILLO': ('Amarillo', Color(0xFFE8C534)),
  'NARANJA': ('Naranja', Color(0xFFEE7332)),
  'ROSA': ('Rosa', Color(0xFFE080A5)),
  'MORADO': ('Morado', Color(0xFF8757AE)),
  'BEIGE': ('Beige', Color(0xFFD4C3A3)),
  'MARRON': ('Marrón', Color(0xFF855C43)),
};

class ProductColorLabels extends StatelessWidget {
  const ProductColorLabels(this.colors, {super.key});
  final List<String> colors;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final key in colors)
        if (productColors[key] case final value?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: value.$2,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(width: 5),
              Text(value.$1, style: const TextStyle(fontSize: 12)),
            ],
          ),
    ],
  );
}
