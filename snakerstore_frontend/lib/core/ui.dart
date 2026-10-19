import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const orange = Color(0xFFFF6B35);
const ink = Color(0xFF111111);
const muted = Color(0xFF6B7280);
const canvas = Color(0xFFF7F7F8);

// Consistent space between form fields, section labels and actions.
List<Widget> spaced(List<Widget> children, {double gap = 18}) => [
  for (var index = 0; index < children.length; index++) ...[
    if (index > 0) SizedBox(height: gap),
    children[index],
  ],
];

final storeTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    secondary: orange,
    surface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF3F3F4),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ink, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: orange.withValues(alpha: .16),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFEEEEEF),
    selectedColor: ink,
    showCheckmark: false,
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

String money(int cents) =>
    'S/ ${(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class StorePage extends StatelessWidget {
  const StorePage({
    super.key,
    required this.title,
    required this.child,
    this.tab,
    this.admin = false,
    this.actions,
    this.bottom,
  });
  final String title;
  final Widget child;
  final int? tab;
  final bool admin;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final paths = admin
        ? [
            '/preview/admin',
            '/preview/admin/productos',
            '/preview/admin/inventario',
            '/preview/admin/pedidos',
            '/preview/admin/zonas',
          ]
        : ['/catalogo', '/carrito', '/pedidos', '/perfil'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions:
            actions ??
            (admin
                ? [
                    IconButton(
                      tooltip: 'Perfil administrador',
                      onPressed: () => context.push('/preview/admin/perfil'),
                      icon: const Icon(Icons.account_circle_outlined),
                    ),
                  ]
                : null),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFEDE5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  child: const Text(
                    'VISTA PREVIA · Datos de ejemplo, sin conexión al servidor',
                    style: TextStyle(fontSize: 11, color: Color(0xFF832600)),
                  ),
                ),
                Expanded(child: child),
                if (bottom != null)
                  Padding(padding: const EdgeInsets.all(16), child: bottom!),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: tab == null
          ? null
          : NavigationBar(
              selectedIndex: tab!,
              onDestinationSelected: (i) => context.go(paths[i]),
              destinations: admin
                  ? const [
                      NavigationDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        label: 'Resumen',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        label: 'Productos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.layers_outlined),
                        label: 'Stock',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        label: 'Pedidos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.location_on_outlined),
                        label: 'Zonas',
                      ),
                    ]
                  : const [
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        label: 'Catálogo',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.shopping_bag_outlined),
                        label: 'Carrito',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        label: 'Pedidos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: 'Perfil',
                      ),
                    ],
            ),
    );
  }
}

class SheetCard extends StatelessWidget {
  const SheetCard({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0F0F2)),
    ),
    child: child,
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: muted)),
        ],
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = orange});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color == orange ? const Color(0xFFA03512) : color,
      ),
    ),
  );
}

class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFFAB3500)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: muted)),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.action,
    this.label = 'Volver al catálogo',
    this.icon = Icons.shopping_bag_outlined,
  });
  final String title, message, label;
  final VoidCallback? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: muted),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: action, child: Text(label)),
          ],
        ],
      ),
    ),
  );
}

class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.amount, {super.key, this.bold = false});
  final String label;
  final int amount;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          money(amount),
          style: TextStyle(
            fontSize: bold ? 21 : 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este campo' : null;
String? emailValidator(String? value) =>
    value != null &&
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Ingresa un correo válido';
String? phoneValidator(String? value) =>
    value != null && RegExp(r'^\+?[0-9 ]{9,15}$').hasMatch(value.trim())
    ? null
    : 'Ingresa un celular válido';
