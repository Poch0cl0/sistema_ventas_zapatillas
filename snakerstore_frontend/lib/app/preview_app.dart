import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/ui.dart';
import '../features/auth/auth_screen.dart';
import '../features/client/client_screens.dart';
import '../features/admin/admin_screens.dart';

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  late final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const AuthScreen(preview: true),
      ),
      GoRoute(
        path: '/registro',
        builder: (_, _) =>
            const AuthScreen(mode: AuthMode.register, preview: true),
      ),
      GoRoute(
        path: '/recuperar',
        builder: (_, _) =>
            const AuthScreen(mode: AuthMode.recover, preview: true),
      ),
      GoRoute(path: '/catalogo', builder: (_, _) => const CatalogScreen()),
      GoRoute(
        path: '/producto/:id',
        builder: (_, s) => ProductScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/carrito', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: '/pedidos', builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: '/pedido/:id',
        builder: (_, s) => OrderScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pago/:id',
        builder: (_, s) => PaymentScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/perfil', builder: (_, _) => const ProfileScreen()),
      // These routes preview designs; they never grant backend permissions.
      GoRoute(
        path: '/preview/admin',
        builder: (_, _) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/preview/admin/productos',
        builder: (_, _) => const AdminProducts(),
      ),
      GoRoute(
        path: '/preview/admin/producto/nuevo',
        builder: (_, _) => const ProductEditor(),
      ),
      GoRoute(
        path: '/preview/admin/producto/:id',
        builder: (_, s) => ProductEditor(id: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/preview/admin/inventario',
        builder: (_, _) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/preview/admin/pedidos',
        builder: (_, _) => const AdminOrders(),
      ),
      GoRoute(
        path: '/preview/admin/pedido/:id',
        builder: (_, s) => AdminOrderScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/preview/admin/zonas',
        builder: (_, _) => const ZonesScreen(),
      ),
      GoRoute(
        path: '/preview/admin/perfil',
        builder: (_, _) => const ProfileScreen(admin: true),
      ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'SneakerStore',
    debugShowCheckedModeBanner: false,
    theme: storeTheme,
    routerConfig: router,
    locale: const Locale('es', 'PE'),
    supportedLocales: const [Locale('es', 'PE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}
