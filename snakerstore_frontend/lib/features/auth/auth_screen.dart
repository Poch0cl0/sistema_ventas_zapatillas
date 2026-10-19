import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/store_design.dart';
import '../../core/network/app_failure.dart';
import 'application/session.dart';

enum AuthMode { login, register, recover }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.mode = AuthMode.login,
    this.preview = false,
  });
  final AuthMode mode;
  final bool preview;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      email = TextEditingController(),
      name = TextEditingController();
  bool busy = false, hidden = true, confirmHidden = true;
  String? message;
  bool get register => widget.mode == AuthMode.register;
  bool get recover => widget.mode == AuthMode.recover;
  @override
  void dispose() {
    password.dispose();
    email.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (widget.preview) {
      setState(
        () =>
            message = 'Vista previa: no se envían datos ni se crea una cuenta.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      switch (widget.mode) {
        case AuthMode.login:
          await ref
              .read(sessionProvider.notifier)
              .signIn(email.text.trim(), password.text);
        case AuthMode.register:
          await ref
              .read(sessionProvider.notifier)
              .register(name.text.trim(), email.text.trim(), password.text);
        case AuthMode.recover:
          try {
            await ref
                .read(authGatewayProvider)
                .resetPassword(email.text.trim());
          } on FirebaseAuthException catch (e) {
            if (e.code != 'user-not-found') rethrow;
          }
          if (mounted)
            setState(
              () => message = 'Si el correo está registrado, recibirás instrucciones para recuperar tu contraseña.',
            );
      }
    } catch (e) {
      if (mounted) setState(() => message = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget label(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => KineticScaffold(
    appBar: StoreAppBar(preview: widget.preview),
    bottomNavigationBar: StoreBottomBar(index: 4, preview: widget.preview),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AutofillGroup(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recover) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.arrow_back, size: 17),
                        label: const Text('Volver al inicio de sesión'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: Color(0xFFE8E8E9),
                        child: Icon(Icons.lock_reset, color: ink, size: 36),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(child: Tag('SEGURIDAD SNEAKERS ID')),
                    const SizedBox(height: 16),
                    const Text(
                      '¿Olvidaste tu contraseña?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 29,
                        height: 1.15,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ingresa el correo asociado a tu cuenta y te enviaremos un enlace para restablecerla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                  ] else if (register)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Colors.black, Color(0xFF211109)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Tag('ACCESO SNEAKERSTORE'),
                          const SizedBox(height: 16),
                          const Text(
                            'Crea tu cuenta\nSneakerStore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Encuentra tu próximo par y gestiona tus compras en un solo lugar.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Tag('● SNEAKERSTORE MEMBER', color: ink),
                        Tag('Acceso cliente', color: muted),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Bienvenido de vuelta',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.12,
                        letterSpacing: -1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ingresa para acceder a tus pedidos y reservar tu próximo par por 24 horas.',
                      style: TextStyle(color: muted, fontSize: 15, height: 1.6),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Container(
                    padding: register || recover
                        ? const EdgeInsets.all(20)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: register || recover
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (register) ...[
                          label('Nombre y apellidos'),
                          TextFormField(
                            controller: name,
                            enabled: !busy,
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Tu nombre completo',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: requiredText,
                          ),
                          const SizedBox(height: 22),
                        ],
                        label(
                          recover
                              ? 'Correo electrónico registrado'
                              : 'Correo electrónico',
                        ),
                        TextFormField(
                          key: const Key('email'),
                          controller: email,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: recover
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: recover ? (_) => submit() : null,
                          decoration: const InputDecoration(
                            hintText: 'tu@correo.com',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: emailValidator,
                        ),
                        if (!recover) ...[
                          const SizedBox(height: 22),
                          label('Contraseña'),
                          TextFormField(
                            key: const Key('password'),
                            controller: password,
                            enabled: !busy,
                            obscureText: hidden,
                            autofillHints: [
                              register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onFieldSubmitted: register ? null : (_) => submit(),
                            decoration: InputDecoration(
                              hintText: 'Ingresa tu contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: hidden
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: () =>
                                    setState(() => hidden = !hidden),
                                icon: Icon(
                                  hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'Usa al menos 6 caracteres'
                                : null,
                          ),
                          if (register) ...[
                            const SizedBox(height: 22),
                            label('Confirmar contraseña'),
                            TextFormField(
                              obscureText: confirmHidden,
                              enabled: !busy,
                              decoration: InputDecoration(
                                hintText: 'Repite tu contraseña',
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  tooltip: 'Mostrar u ocultar confirmación',
                                  onPressed: () => setState(
                                    () => confirmHidden = !confirmHidden,
                                  ),
                                  icon: Icon(
                                    confirmHidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v == password.text
                                  ? null
                                  : 'Las contraseñas no coinciden',
                            ),
                          ] else
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.push('/recuperar'),
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(color: Color(0xFFAB3500)),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          key: const Key('auth-submit'),
                          style: register || recover ? accentButton : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (busy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: Text(
                                      register
                                          ? 'Crear cuenta'
                                          : recover
                                          ? 'Enviar enlace de recuperación'
                                          : 'Iniciar sesión',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                if (!busy)
                                  const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),
                        if (message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: InfoNote(message!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SurfaceSection(
                    tint: soft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentWash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            recover
                                ? Icons.shield_outlined
                                : Icons.workspace_premium_outlined,
                            color: const Color(0xFFAB3500),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recover
                                    ? 'Consejo de seguridad'
                                    : 'Tu próximo par te espera',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                recover
                                    ? 'Revisa también la carpeta de spam. No compartas el enlace de recuperación.'
                                    : 'Reserva de stock por 24 horas al generar tu pedido. Pagos con verificación manual.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        register || recover
                            ? '¿Ya tienes cuenta?'
                            : '¿No tienes cuenta?',
                        style: const TextStyle(color: muted),
                      ),
                      TextButton(
                        onPressed: () => context.go(
                          register || recover ? '/login' : '/registro',
                        ),
                        child: Text(
                          register || recover
                              ? 'Inicia sesión'
                              : 'Crear una cuenta',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/catalogo'),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('Explorar la tienda como invitado'),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'SNEAKERSTORE · TU PRÓXIMO PASO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.preview)
                    TextButton(
                      onPressed: () => context.push('/preview/admin'),
                      child: const Text('Vista previa de administrador'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
