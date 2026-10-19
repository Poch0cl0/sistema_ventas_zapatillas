# Autenticación y roles

Firebase Authentication es responsable del registro, inicio de sesión, contraseñas
y recuperación. NestJS recibe únicamente ID tokens del SDK cliente; no recibe ni
almacena contraseñas, ni emite tokens propios.

## Contrato del backend

`GET /auth/me` exige `Authorization: Bearer <FIREBASE_ID_TOKEN>` y devuelve:

```json
{"uid":"firebase-uid","email":"cliente@example.invalid","name":"Cliente","role":"CLIENTE"}
```

El rol se consulta en `users/{uid}`. No se confía en roles del token, body o query.
Si falta el perfil, una transacción lo crea con rol CLIENTE y timestamp de servidor.
Los perfiles existentes, incluido el administrador, no se modifican. Un rol ausente
o desconocido bloquea el acceso; no se corrige automáticamente.

Todas las rutas nuevas requieren autenticación por defecto. `@Public()` permite
exponer explícitamente catálogos públicos. `@Roles('ADMINISTRADOR')` restringe
operaciones administrativas. `@CurrentUser()` obtiene el perfil verificado.
La ruta `/` de la plantilla sigue siendo pública. No hay rutas de cambio de rol.

Respuestas: 401 para tokens ausentes, malformados, vencidos, revocados o usuarios
deshabilitados; 403 para permisos insuficientes o roles inválidos; 503 para fallos
de consulta del perfil o errores de disponibilidad de Firebase identificados.
`verifyIdToken(token, true)` comprueba revocación en cada solicitud protegida.

## Flujo Flutter pendiente

1. Registrar con `FirebaseAuth.instance.createUserWithEmailAndPassword` o iniciar
   sesión con `signInWithEmailAndPassword`.
2. Obtener `currentUser.getIdToken()` y enviarlo a `GET /auth/me` mediante Dio.
3. Elegir la interfaz según el rol devuelto por NestJS.
4. En 401, renovar el token una sola vez; si falla, solicitar inicio de sesión.

### Olvidé mi contraseña

Desde el inicio de sesión, el usuario podrá abrir el formulario de recuperación.
El futuro frontend Flutter ejecutará:

```dart
await FirebaseAuth.instance.setLanguageCode('es');
await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
```

Firebase enviará el correo con su enlace de restablecimiento estándar. Mostrar un
mensaje genérico: «Si el correo está registrado, recibirás instrucciones». Manejar
correo inválido, falta de conexión y demasiados intentos sin registrar información
sensible. Tras restablecer la contraseña, regresar al inicio de sesión.

No hace falta un endpoint NestJS ni un proveedor SMTP para este flujo. No generar
enlaces Admin para devolverlos al solicitante. No configurar enlaces personalizados
ni cambiar Firebase sin necesidad. El formulario y la prueba real de recepción del
correo se implementarán al comenzar Flutter; todavía no existen en este backend.

## Verificación

`pnpm build`, `pnpm lint`, `pnpm test`, `pnpm test:e2e`.
Las pruebas usan Firebase simulado. No envían correos ni alteran usuarios reales.
Las pruebas de tokens reales y recuperación completa requieren el SDK cliente o
Firebase Emulator Suite y se realizarán durante la integración.

Referencias oficiales:
- https://firebase.google.com/docs/auth/admin/verify-id-tokens
- https://firebase.google.com/docs/auth/admin/manage-sessions
- https://firebase.google.com/docs/auth/flutter/manage-users
