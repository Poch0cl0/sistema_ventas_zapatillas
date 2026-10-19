import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/network/app_failure.dart';
import 'application/session.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: session.status == SessionStatus.unavailable
            ? Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmptyState(
                        'No pudimos verificar tu cuenta',
                        session.message ?? 'Inténtalo nuevamente.',
                        icon: Icons.cloud_off,
                        action: () =>
                            ref.read(sessionProvider.notifier).retry(),
                        label: 'Reintentar',
                      ),
                      TextButton(
                        onPressed: () => context.go('/catalogo'),
                        child: const Text('Explorar catálogo público'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(sessionProvider.notifier).signOut();
                          } catch (error) {
                            if (context.mounted) {
                              notice(context, errorMessage(error));
                            }
                          }
                        },
                        child: const Text('Volver a iniciar sesión'),
                      ),
                    ],
                  ),
                ),
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: orange, size: 48),
                    SizedBox(height: 16),
                    Text('Verificando tu sesión…'),
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
      ),
    );
  }
}
