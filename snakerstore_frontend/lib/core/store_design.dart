import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session.dart';
import '../features/store/store_repository.dart';
import '../features/catalog/catalog_repository.dart';
import 'ui.dart';

const line = Color(0xFFE5E7EB);
const soft = Color(0xFFF3F3F4);
const accentWash = Color(0xFFFFEDE5);
const success = Color(0xFF16834B);

ButtonStyle get accentButton => FilledButton.styleFrom(
  backgroundColor: orange,
  foregroundColor: Colors.white,
  elevation: 2,
  shadowColor: orange.withValues(alpha: .25),
);

class StoreAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const StoreAppBar({
    super.key,
    this.title,
    this.admin = false,
    this.back = false,
    this.preview = false,
    this.actions = const [],
  });
  final String? title;
  final bool admin, back, preview;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(66);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = preview ? null : ref.watch(sessionProvider).profile;
    final count = preview
        ? 0
        : ref.watch(cartProvider).fold<int>(0, (sum, e) => sum + e.quantity);
    return AppBar(
      toolbarHeight: 66,
      automaticallyImplyLeading: false,
      titleSpacing: back ? 0 : 18,
      leading: back
          ? IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back, size: 21),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(admin ? '/admin' : '/catalogo');
                }
              },
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!back) ...[
                const Icon(Icons.bolt, color: orange, size: 20),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  title ?? 'SNEAKERSTORE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: title == null ? 18 : 16,
                    letterSpacing: -.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (admin)
            const Text(
              'ADMIN PANEL',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
        ],
      ),
      actions: [
        ...actions,
        if (!admin)
          IconButton(
            tooltip: 'Carrito',
            onPressed: () => context.go('/carrito'),
            icon: Badge(
              isLabelVisible: count > 0,
              backgroundColor: orange,
              label: Text('$count'),
              child: const Icon(Icons.shopping_bag_outlined, size: 23),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 2),
          child: IconButton.filled(
            tooltip: 'Mi cuenta',
            style: IconButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.go(profile == null ? '/login' : '/perfil'),
            icon: const Icon(Icons.person_outline, size: 20),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}

class StoreBottomBar extends ConsumerWidget {
  const StoreBottomBar({
    super.key,
    required this.index,
    this.admin = false,
    this.preview = false,
  });
  final int index;
  final bool admin, preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = preview
        ? 0
        : ref.watch(cartProvider).fold<int>(0, (sum, e) => sum + e.quantity);
    final items = admin
        ? const [
            (Icons.space_dashboard_outlined, 'Resumen', '/admin'),
            (Icons.inventory_2_outlined, 'Productos', '/admin/productos'),
            (Icons.layers_outlined, 'Stock', '/admin/inventario'),
            (Icons.local_shipping_outlined, 'Pedidos', '/admin/pedidos'),
            (Icons.map_outlined, 'Zonas', '/admin/zonas'),
          ]
        : const [
            (Icons.explore_outlined, 'Catálogo', '/catalogo'),
            (Icons.shopping_bag_outlined, 'Carrito', '/carrito'),
            (Icons.receipt_long_outlined, 'Pedidos', '/pedidos'),
            (Icons.person_outline, 'Perfil', '/perfil'),
          ];
    final selectedIndex = admin ? index : (index <= 1 ? 0 : index - 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: line)),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selectedIndex,
                    button: true,
                    label: items[i].$2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go(
                        preview && i == 0 ? '/catalogo' : items[i].$3,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: !admin && i == 1 && count > 0,
                              backgroundColor: orange,
                              label: Text('$count'),
                              child: Icon(
                                items[i].$1,
                                size: 22,
                                color: i == selectedIndex ? ink : muted,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              items[i].$2,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                color: i == selectedIndex ? ink : muted,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 4,
                              width: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == selectedIndex
                                    ? orange
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class KineticScaffold extends StatelessWidget {
  const KineticScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar, floatingActionButton;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    backgroundColor: backgroundColor,
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: body,
        ),
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? eyebrow, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.15,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
          ),
        ],
      ],
    ),
  );
}

class SurfaceSection extends StatelessWidget {
  const SurfaceSection({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.tint = Colors.white,
  });
  final Widget child;
  final String? title;
  final IconData? icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0F0F2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: const Color(0xFFAB3500)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        child,
      ],
    ),
  );
}

String statusLabel(String value) =>
    const {
      'PENDIENTE': 'Pendiente de pago',
      'PENDIENTE_PAGO': 'Pendiente de pago',
      'PENDIENTE_VERIFICACION': 'Pago en revisión',
      'RECHAZADO': 'Pago rechazado',
      'PAGO_RECHAZADO': 'Pago rechazado',
      'APROBADO': 'Pago verificado',
      'PAGO_APROBADO': 'Pago verificado',
      'SIMULADO': 'Pago realizado',
      'PAGO_SIMULADO': 'Pago realizado',
      'NO_REQUERIDO': 'Pago no requerido',
      'CONFIRMADO_SIN_PAGO': 'Confirmado sin pago',
      'VENCIDO': 'Reserva vencida',
      'CANCELADO': 'Cancelado',
      'SIN_INICIAR': 'Por confirmar',
      'PREPARANDO': 'En preparación',
      'LISTO_RECOJO': 'Listo para recoger',
      'EN_REPARTO': 'En reparto',
      'ENTREGADO': 'Entregado',
    }[value] ??
    value.replaceAll('_', ' ');

class StatusPill extends StatelessWidget {
  const StatusPill(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final ok = [
      'APROBADO',
      'PAGO_APROBADO',
      'ENTREGADO',
      'Activo',
      'Activa',
    ].contains(value);
    final bad = [
      'CANCELADO',
      'VENCIDO',
      'RECHAZADO',
      'PAGO_RECHAZADO',
    ].contains(value);
    final color = ok
        ? success
        : bad
        ? const Color(0xFFBA1A1A)
        : const Color(0xFFAB3500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusLabel(value),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutSteps extends StatelessWidget {
  const CheckoutSteps(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i <= step ? orange : line,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: i <= step ? ink : line,
                child: i < step
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: i == step ? Colors.white : muted,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                ['Carrito', 'Entrega', 'Pago'][i],
                style: TextStyle(
                  fontSize: 10,
                  color: i == step ? ink : muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class MiniMetric extends StatelessWidget {
  const MiniMetric(
    this.label,
    this.value,
    this.icon, {
    super.key,
    this.highlight = false,
  });
  final String label, value;
  final IconData icon;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line.withValues(alpha: .45)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(icon, size: 19, color: highlight ? orange : muted),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
            color: highlight ? const Color(0xFFAB3500) : ink,
          ),
        ),
      ],
    ),
  );
}

String shortOrder(String id) =>
    '#${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';

class OrderItemRow extends ConsumerWidget {
  const OrderItemRow(this.item, {super.key});
  final Json item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productId = item['productId'] as String?;
    final product = productId == null
        ? null
        : ref
              .watch(catalogProductProvider((admin: false, id: productId)))
              .asData
              ?.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 56,
              color: soft,
              child: product?.images.isNotEmpty == true
                  ? Image.network(
                      product!.images.first,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: muted,
                        size: 20,
                      ),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                      color: muted,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'EU ${item['size']} · Cant. ${item['quantity']}',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            money((item['unitPriceCents'] as int) * (item['quantity'] as int)),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({
    super.key,
    required this.payment,
    required this.fulfillment,
    required this.pickup,
  });
  final String payment, fulfillment;
  final bool pickup;
  @override
  Widget build(BuildContext context) {
    final direct = payment == 'SIMULADO';
    final index = direct
        ? (fulfillment == 'ENTREGADO' ? 2 : 1)
        : fulfillment == 'ENTREGADO'
        ? 4
        : ['LISTO_RECOJO', 'EN_REPARTO'].contains(fulfillment)
        ? 3
        : fulfillment == 'PREPARANDO'
        ? 2
        : ['APROBADO', 'SIMULADO', 'NO_REQUERIDO'].contains(payment)
        ? 1
        : 0;
    final cancelled = ['CANCELADO', 'VENCIDO'].contains(payment);
    final labels = [
      'Pedido confirmado',
      payment == 'SIMULADO'
          ? 'Pago realizado'
          : payment == 'NO_REQUERIDO'
          ? 'Pago no requerido'
          : 'Pago verificado',
      if (!direct) 'En preparación',
      if (!direct) pickup ? 'Listo para recoger' : 'En reparto',
      'Entregado',
    ];
    return Column(
      children: [
        for (var i = 0; i < labels.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: cancelled && i > 0
                            ? line
                            : i < index
                            ? ink
                            : i == index
                            ? orange
                            : soft,
                        child: Icon(
                          i < index
                              ? Icons.check
                              : i == 4
                              ? Icons.inventory_2_outlined
                              : Icons.circle_outlined,
                          size: 14,
                          color: i <= index ? Colors.white : muted,
                        ),
                      ),
                      if (i < labels.length - 1)
                        Expanded(child: Container(width: 1, color: line)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 3,
                      bottom: i == labels.length - 1 ? 0 : 24,
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: i <= index ? ink : muted,
                        fontWeight: i == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
