import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import '../auth/application/session.dart';
import '../store/store_repository.dart';

final _accountOrdersProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  final profile = ref.watch(sessionProvider).profile;
  if (profile == null || profile.isAdmin) return Future.value(<Json>[]);
  return ref.watch(storeRepositoryProvider).all('/orders');
});

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountState();
}

class _AccountState extends ConsumerState<AccountScreen> {
  bool leaving = false, resetting = false;
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final orders = ref.watch(_accountOrdersProvider);
    final name = profile.name?.isNotEmpty == true ? profile.name! : 'Tu cuenta';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
    return KineticScaffold(
      appBar: StoreAppBar(admin: profile.isAdmin),
      bottomNavigationBar: StoreBottomBar(
        index: profile.isAdmin ? 0 : 4,
        admin: profile.isAdmin,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: spaced([
          const SectionHeading('Mi perfil', eyebrow: 'Tu espacio SneakerStore'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: const Border(top: BorderSide(color: orange, width: 3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: ink,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tag(
                            profile.isAdmin
                                ? 'ADMINISTRADOR'
                                : 'SNEAKERSTORE MEMBER',
                            color: const Color(0xFFAB3500),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            profile.email ?? 'Sin correo registrado',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!profile.isAdmin) ...[
                  const SizedBox(height: 22),
                  orders.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => TextButton(
                      onPressed: () => ref.invalidate(_accountOrdersProvider),
                      child: const Text('Recargar resumen de pedidos'),
                    ),
                    data: (items) => Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          for (final metric in [
                            ('Pedidos', items.length),
                            (
                              'En reparto',
                              items
                                  .where(
                                    (o) =>
                                        o['fulfillmentStatus'] == 'EN_REPARTO',
                                  )
                                  .length,
                            ),
                            (
                              'Entregados',
                              items
                                  .where(
                                    (o) =>
                                        o['fulfillmentStatus'] == 'ENTREGADO',
                                  )
                                  .length,
                            ),
                          ])
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${metric.$2}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    metric.$1,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SurfaceSection(
            title: profile.isAdmin
                ? 'Administración de la tienda'
                : 'Mis pedidos y envíos',
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  profile.isAdmin
                      ? 'Gestiona tu catálogo, inventario y operaciones.'
                      : 'Revisa tus compras, pagos y el estado de cada entrega.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go(profile.isAdmin ? '/admin' : '/pedidos'),
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: Text(
                    profile.isAdmin
                        ? 'Abrir panel de control'
                        : 'Ver todos mis pedidos',
                  ),
                ),
              ],
            ),
          ),
          SurfaceSection(
            title: 'Información personal',
            icon: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nombre completo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _readOnly(
                  Icons.person_outline,
                  profile.name ?? 'Sin nombre registrado',
                ),
                const SizedBox(height: 22),
                const Text(
                  'Correo electrónico',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _readOnly(
                  Icons.mail_outline,
                  profile.email ?? 'Sin correo registrado',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Estos son los datos registrados en tu cuenta.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          SurfaceSection(
            title: 'Seguridad de la cuenta',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key_outlined),
                  title: const Text(
                    'Restablecer contraseña',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    resetting
                        ? 'Enviando enlace…'
                        : 'Recibe un enlace en tu correo',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: resetting || profile.email == null
                      ? null
                      : () async {
                          setState(() => resetting = true);
                          try {
                            await ref
                                .read(authGatewayProvider)
                                .resetPassword(profile.email!);
                            if (mounted)
                              notice(
                                context,
                                'Revisa tu correo para restablecer la contraseña.',
                              );
                          } catch (e) {
                            if (mounted) notice(context, errorMessage(e));
                          } finally {
                            if (mounted) setState(() => resetting = false);
                          }
                        },
                ),
                const Divider(height: 28),
                OutlinedButton.icon(
                  onPressed: leaving
                      ? null
                      : () async {
                          setState(() => leaving = true);
                          try {
                            await ref.read(sessionProvider.notifier).signOut();
                          } catch (e) {
                            if (mounted) notice(context, errorMessage(e));
                          } finally {
                            if (mounted) setState(() => leaving = false);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBA1A1A),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(leaving ? 'Cerrando sesión…' : 'Cerrar sesión'),
                ),
              ],
            ),
          ),
          const Text(
            'SNEAKERSTORE · TU PRÓXIMO PASO',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.3),
          ),
        ]),
      ),
    );
  }

  Widget _readOnly(IconData icon, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}
