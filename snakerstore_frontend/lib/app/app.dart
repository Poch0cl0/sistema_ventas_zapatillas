import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui.dart';
import '../features/auth/application/session.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/session_screen.dart';
import '../features/account/account_screen.dart';
import '../features/catalog/connected_catalog_screen.dart';
import '../features/admin/connected_admin_screen.dart';
import 'preview_app.dart';
import 'session_redirect.dart';
import '../features/store/commerce_screens.dart';
import '../features/store/management_screens.dart';

class SneakerStoreApp extends StatelessWidget {
  const SneakerStoreApp({super.key, this.preview = false});
  final bool preview;
  @override
  Widget build(BuildContext context) =>
      preview ? const PreviewApp() : const _ConnectedApp();
}

class _ConnectedApp extends ConsumerStatefulWidget {
  const _ConnectedApp();
  @override
  ConsumerState<_ConnectedApp> createState() => _ConnectedAppState();
}

class _ConnectedAppState extends ConsumerState<_ConnectedApp> {
  late final GoRouter router = GoRouter(
    initialLocation: '/session',
    redirect: (_, state) =>
        sessionRedirect(ref.read(sessionProvider), state.uri.path),
    routes: [
      GoRoute(path: '/session', builder: (_, _) => const SessionScreen()),
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/registro',
        builder: (_, _) => const AuthScreen(mode: AuthMode.register),
      ),
      GoRoute(
        path: '/recuperar',
        builder: (_, _) => const AuthScreen(mode: AuthMode.recover),
      ),
      GoRoute(
        path: '/catalogo',
        builder: (_, _) => const ConnectedCatalogScreen(),
      ),
      GoRoute(path: '/inicio', redirect: (_, _) => '/catalogo'),
      GoRoute(
        path: '/producto/:id',
        builder: (_, s) => ConnectedProductScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/perfil', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/carrito', builder: (_, _) => const ConnectedCartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (_, _) => const ConnectedCheckoutScreen(),
      ),
      GoRoute(
        path: '/pedido/:id',
        builder: (_, s) => ConnectedOrderScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pedido/:id/pago',
        builder: (_, s) => ConnectedPaymentScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/admin', builder: (_, _) => const ConnectedAdminScreen()),
      GoRoute(
        path: '/admin/configuracion',
        builder: (_, _) => const StoreSettingsEditor(),
      ),
      GoRoute(
        path: '/admin/productos/nuevo',
        builder: (_, _) => const ManagementEditor(kind: ManagementKind.product),
      ),
      GoRoute(
        path: '/admin/producto/:id/editar',
        builder: (_, s) => ManagementEditor(
          kind: ManagementKind.product,
          id: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/admin/inventario/nuevo',
        builder: (_, s) => ManagementEditor(
          kind: ManagementKind.inventory,
          productId: s.uri.queryParameters['productId'],
        ),
      ),
      GoRoute(
        path: '/admin/inventario/:id/editar',
        builder: (_, s) => ManagementEditor(
          kind: ManagementKind.inventory,
          id: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/admin/zonas/nueva',
        builder: (_, _) => const ManagementEditor(kind: ManagementKind.zone),
      ),
      GoRoute(
        path: '/admin/zonas/:id/editar',
        builder: (_, s) => ManagementEditor(
          kind: ManagementKind.zone,
          id: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/admin/pedido/:id',
        builder: (_, s) =>
            ConnectedOrderScreen(id: s.pathParameters['id']!, admin: true),
      ),
      GoRoute(
        path: '/admin/productos',
        builder: (_, _) => const ConnectedCatalogScreen(admin: true),
      ),
      GoRoute(
        path: '/admin/producto/:id',
        builder: (_, s) =>
            ConnectedProductScreen(id: s.pathParameters['id']!, admin: true),
      ),
      GoRoute(
        path: '/admin/inventario',
        builder: (_, _) => const ConnectedRecordsScreen(
          path: '/admin/inventory',
          title: 'Inventario',
        ),
      ),
      GoRoute(
        path: '/admin/pedidos',
        builder: (_, _) => const ConnectedRecordsScreen(
          path: '/admin/orders',
          title: 'Pedidos online',
        ),
      ),
      GoRoute(
        path: '/admin/zonas',
        builder: (_, _) => const ConnectedRecordsScreen(
          path: '/admin/delivery-zones',
          title: 'Zonas de delivery',
        ),
      ),
      GoRoute(
        path: '/pedidos',
        builder: (_, _) => const ConnectedRecordsScreen(
          path: '/orders',
          title: 'Mis pedidos',
          client: true,
        ),
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('SneakerStore')),
      body: EmptyState(
        'Esta sección no está disponible',
        'Vuelve al inicio para continuar.',
        label: 'Volver al inicio',
        action: () => context.go('/session'),
      ),
    ),
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, _) => router.refresh());
    return MaterialApp.router(
      title: 'SneakerStore',
      debugShowCheckedModeBanner: false,
      theme: storeTheme,
      routerConfig: router,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
