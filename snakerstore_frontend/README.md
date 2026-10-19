# SneakerStore Android

Aplicación Flutter para `com.example.sneakerstore`, registrada en el proyecto
Firebase existente `snakerstore-e74cd`. Los HTML y PNG de `Login`, `Vistas para
cliente` y `Vistas para administrador` son referencias visuales y se conservan.

## Modelos 3D opcionales

El editor permite subir un `.glb` de hasta 10 MiB. Cuando existe, tiene prioridad
en catálogo y ficha; las fotos se conservan. Requiere actualizar la instalación
Android por los nuevos plugins. Ver [uso y configuración](../snakerstore_backend/PRODUCT_MODELS_GUIDE.md).

## Estado de la conexión

El modo conectado utiliza el diseño móvil Kinetic Minimal de las carpetas de
referencia: Inter local, catálogo en cuadrícula, tarjetas de compra, navegación
inferior y administración adaptada a móvil. Ver
[`DESIGN_IMPLEMENTATION.md`](DESIGN_IMPLEMENTATION.md) para el alcance y la
revisión visual pendiente. No se compiló ni ejecutó la app durante el rediseño.

La ejecución normal utiliza Firebase Authentication y la API NestJS. No carga
productos, usuarios o pedidos de ejemplo.

| Flujo | Implementación actual |
|---|---|
| Iniciar sesión | Email/Password de Firebase y perfil de `GET /auth/me` |
| Registro | Firebase, actualización del nombre, token renovado y perfil CLIENTE creado por NestJS |
| Recuperación | Correo estándar de Firebase; confirmación genérica |
| Sesión persistente | Restauración del SDK y nueva comprobación del rol en NestJS |
| Cierre de sesión | Se descarta el rol local y se cierra Firebase Auth |
| Perfil | Lectura del nombre, correo y rol verificados por el backend |
| Catálogo | Consulta pública paginada, búsqueda dentro de la página y detalle real |
| Mis pedidos | Consulta de los pedidos del cliente autenticado |
| Administración | Acceso exclusivo por rol, consultas paginadas de productos, inventario, pedidos y zonas |

El modo normal también conecta carrito, checkout con reserva de stock, envío de
referencias de pago, aprobación/rechazo administrativo, avance de entrega,
creación y edición de productos, carga de fotos, creación y ajuste de inventario,
creación/edición/desactivación de zonas y configuración de tienda, recojo y pagos.
Las interfaces anteriores permanecen disponibles en el modo de diseño.
No hay edición de perfil en el backend actual, por lo que el perfil conectado se
muestra de solo lectura.

### Preparación y revisión manual de los flujos conectados

El checkout de delivery ahora incluye un mapa OpenStreetMap para confirmar el
punto de entrega y calcular una ruta ORS por medio del backend. La dirección
escrita es opcional al confirmar el pin. Cliente y administrador pueden consultar
el destino desde el pedido. Ver configuración y límites en
[`DELIVERY_MAP_GUIDE.md`](../snakerstore_backend/DELIVERY_MAP_GUIDE.md).
La integración del mapa y sus permisos Android requieren reinstalar la app;
hot reload no incorpora los plugins nuevos. La validación en dispositivo sigue pendiente.

1. Como administrador, abrir **Configuración de tienda** y guardar nombre,
   dirección, horario, instrucciones y al menos un método de pago con sus datos
   reales. El backend exige dirección e instrucciones incluso con recojo deshabilitado.
2. Crear un producto, adjuntar fotos y agregar tallas con stock desde su editor.
   Para fotos, Cloudinary debe estar configurado en el backend.
3. Crear zonas activas con tarifas para ofrecer delivery. El interruptor Activo
   permite desactivar o reactivar productos y zonas conservando su historial.
4. Como cliente, elegir talla en el detalle, abrir el carrito, ajustar cantidades
   y confirmar la entrega. El servidor confirma precios y stock, y devuelve el
   total definitivo antes del pago. El carrito vive en memoria y se vacía al
   cerrar la app o cambiar de sesión. No reserva stock hasta crear el pedido.
5. Desde el pedido, consultar los datos de pago y registrar la referencia de una
   operación realizada externamente. No hay cobro automático ni carga de imagen
   de comprobante: el contrato actual del backend recibe método y referencia.
6. Como administrador, abrir el pedido, verificar el ingreso real y aprobar o
   rechazar con motivo. Un rechazo permite otra referencia mientras siga vigente
   la reserva. Tras aprobar, avanzar de preparación a recojo/reparto y entregado.
7. El cliente puede cancelar antes de la aprobación. En Pedidos online, el botón
   de reloj procesa las reservas vencidas y muestra cuántas se liberaron.

Los reintentos del mismo checkout conservan su clave de idempotencia mientras
la aplicación mantiene el carrito y no cambian los datos de la solicitud.
Si hay una desconexión, revisar Mis pedidos antes de iniciar otro checkout.
Los envíos de pago y ajustes de inventario no se reintentan automáticamente.

Esta integración se realizó sin ejecutar pruebas, análisis, compilaciones ni la
aplicación por indicación del usuario. La validación funcional en dispositivo
sigue pendiente.

## Ejecutar con Android y el backend local

En una terminal, desde `snakerstore_backend`:

```powershell
pnpm start:dev
```

Desde `snakerstore_frontend`, con un emulador Android:

```powershell
flutter pub get
flutter run
```

La API predeterminada es `http://10.0.2.2:3000`, dirección del PC vista desde el
emulador. Para un teléfono físico conectado a la misma red, usar la IPv4 LAN del
PC, que puedes consultar con `ipconfig`:

```powershell
flutter run --dart-define=API_BASE_URL=http://IP_LAN_DEL_PC:3000
```

El teléfono necesita internet para Firebase y acceso al puerto 3000 del PC para
NestJS. `localhost` en el teléfono apunta al propio teléfono. Cambiar
`API_BASE_URL` requiere reiniciar la ejecución; hot reload no cambia las
constantes de compilación.

HTTP local está habilitado en los manifiestos Android debug/profile. Una build
de distribución exige configurar una API HTTPS. No se ha publicado la app.

## Configuración Firebase

FlutterFire generó `lib/firebase_options.dart`, `android/app/google-services.json`
y `firebase.json`, y configuró el plugin de Google Services. Se mantuvo el
identificador Android que ya tenía el proyecto. Son configuraciones del SDK
cliente; nunca copiar una cuenta de servicio, un token o secretos de Cloudinary
al frontend.

Firebase Auth administra las contraseñas y la persistencia de sesión. Dio obtiene
el ID token del SDK para cada petición protegida. Ante 401 renueva el token y
reintenta una sola vez las lecturas; un segundo 401 descarta la sesión. Un fallo
de red no concede roles ni elimina automáticamente una sesión válida.

El rol se obtiene exclusivamente de `/auth/me`. No existe selector de roles ni
acceso administrativo público en el modo conectado. NestJS vuelve a validar
identidad y permisos en cada endpoint. Las consultas de negocio a Firestore
pasan por NestJS; Flutter no usa Firestore directamente ni Firebase Storage.

## Organización

- `lib/main.dart`: inicialización de Firebase y manejo de fallos de arranque.
- `lib/app`: rutas conectadas, redirección por sesión y app de diseño separada.
- `lib/core/config`, `lib/core/network`: URL, Dio, errores y paginación.
- `lib/features/auth`: adaptador Firebase, repositorio `/auth/me`, estado de sesión y formularios.
- `lib/features/catalog`, `account`: pantallas y repositorios conectados.
- `lib/features/admin/connected_admin_screen.dart`: navegación y consultas administrativas.
- `lib/preview`: datos en memoria usados exclusivamente por las pantallas de diseño.

Para revisar las interfaces locales todavía pendientes de integración:

```powershell
flutter run --dart-define=PREVIEW_MODE=true
```

El flag solo se habilita en debug. En este modo los formularios y las operaciones
son simulaciones locales y se identifican como vista previa.

## Verificación

```powershell
flutter analyze
flutter test
```

Las pruebas cubren validación, navegación móvil, sesión, roles, renovación de
token, cierre de sesión con respuestas tardías y estados de error. No crean
usuarios ni pedidos en Firebase real. La prueba de conexión contra NestJS es de
solo lectura y se activa explícitamente con el servidor encendido:

```powershell
flutter test --dart-define=RUN_BACKEND_SMOKE=true test/backend_smoke_test.dart
```

Para las pruebas del backend con Auth y Firestore emulados, usar dos terminales
en `snakerstore_backend`:

```powershell
firebase emulators:start --only auth,firestore --project demo-sneakerstore --config firebase.emulator.json --non-interactive
pnpm test:integration
```

Si el servidor LSP falla por los caracteres acentuados de la ruta de Windows,
puedes usar temporalmente una unidad libre:

```powershell
subst S: "C:\Users\Jefferson Peña\Desktop\sistema_ventas\snakerstore_frontend"
Set-Location S:\
flutter analyze --no-pub
flutter test --no-pub
```

Para retirar el alias, salir de S: y ejecutar `subst S: /D`.

La autenticación real en un teléfono, recepción del correo de recuperación y
compilación/instalación de APK deben comprobarse en Android antes de dar por
terminada la validación en dispositivo.

## Herramientas locales

Flutter y Dart: `D:\Flutter\Flutter\flutter`; paquetes y FlutterFire:
`D:\Flutter\pub-cache`; Android SDK: `D:\Android\sdk`; caché Gradle:
`D:\Android\gradle-cache`. Las versiones existentes se mantienen en
`pubspec.yaml` y `pubspec.lock`.

Referencias oficiales utilizadas:
- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/auth/flutter/password-auth
- https://firebase.google.com/docs/auth/flutter/start
- https://pub.dev/packages/dio
