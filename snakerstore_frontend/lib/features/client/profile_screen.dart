import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../preview/preview_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.admin = false});
  final bool admin;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    name = TextEditingController(
      text: widget.admin ? 'Administrador de ejemplo' : p.name,
    );
    phone = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StorePage(
    title: 'Mi perfil',
    tab: widget.admin ? null : 3,
    admin: widget.admin,
    child: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: ink,
              child: Icon(Icons.person_outline, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          Heading(
            widget.admin ? 'Tu espacio de gestión.' : 'Tu espacio, tu estilo.',
            subtitle: 'Perfil de ejemplo · sin sesión iniciada',
          ),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            validator: requiredText,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.admin
                ? 'admin@example.com'
                : 'cliente@example.com',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico de ejemplo',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Celular'),
            validator: phoneValidator,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                if (!widget.admin) {
                  ref
                      .read(profileProvider.notifier)
                      .save(name.text.trim(), phone.text.trim());
                }
                notice(context, 'Cambios guardados solo en esta vista previa');
              }
            },
            child: const Text('Guardar cambios de ejemplo'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go(
              widget.admin ? '/preview/admin/pedidos' : '/pedidos',
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Ver pedidos'),
          ),
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.logout),
            label: const Text('Salir de la vista previa'),
          ),
        ],
      ),
    ),
  );
}
