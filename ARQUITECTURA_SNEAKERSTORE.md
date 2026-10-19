# SYSTEM_PROMPT.md — SneakerStore

> **Contrato de implementación para Codex, Cursor o GitHub Copilot.** Leer antes de modificar código. Este documento describe el estado confirmado del proyecto y las decisiones de arquitectura. No sustituye la inspección del repositorio real.

## 0. Contexto y reglas de trabajo

- **Producto:** SneakerStore, tienda de zapatillas con pedidos online, delivery por zona o recojo en tienda.
- **Frontend MVP:** **Flutter + Dart**, aplicación móvil Android con interfaces distintas para `CLIENTE` y `ADMINISTRADOR` dentro de la misma aplicación. **No implementar Next.js** en el alcance actual.
- **Backend:** **NestJS + TypeScript**, API REST. Gestor de paquetes **pnpm**.
- **Firebase:** proyecto `snakerstore-e74cd`, plan **Spark**; Firebase Authentication Email/Password; Cloud Firestore en `southamerica-east1`, modo producción. Existe `users/{uid}` con un usuario de prueba `ADMINISTRADOR` asignado manualmente.
- **Archivos:** imágenes de productos y comprobantes mediante **Cloudinary**, exclusivamente a través del backend. **No usar Firebase Storage**.
- **Estado existente:** backend creado en `snakerstore_backend`; paquetes `firebase-admin` y `@nestjs/config` instalados; credenciales locales `firebase-service-account.json` en la raíz, excluidas de Git, y variables en `.env`.
- **Herramientas:** VS Code y Codex. Mantener el código legible, modular, tipado y explicable para un desarrollador que aprende NestJS y Flutter.

### Protocolo obligatorio para la IA

1. **Inspeccionar el repositorio primero**: árbol de archivos, `package.json`, configuración TypeScript, dependencias, módulos existentes y `.gitignore`. No recrear ni sobrescribir lo que ya funciona.
2. Antes de cada cambio, explicar brevemente **objetivo, archivos afectados y motivo**. Trabajar **por fases y tareas pequeñas**; solicitar confirmación cuando la tarea implique decisiones no documentadas.
3. Ejecutar verificaciones pertinentes tras cada incremento (lint, build, tests, `flutter analyze`), reportar resultados reales y errores pendientes. **No afirmar que algo funciona sin probarlo**.
4. No introducir servicios de pago, pasarelas, POS, ventas presenciales, facturación electrónica, GPS ni funciones fuera del MVP.
5. **Nunca mostrar, copiar en respuestas, registrar en logs ni subir a Git** `.env`, claves de servicio, tokens, secretos de Cloudinary ni información sensible. No añadir valores secretos reales a ejemplos; usar `.env.example` con placeholders.
6. Preferir convenciones idiomáticas de NestJS y Flutter; separar lógica de negocio, transporte, persistencia y presentación. No escribir lógica compleja en controladores o widgets.
7. Usar documentación oficial vigente al decidir APIs de bibliotecas. Mantener consistencia con las versiones realmente instaladas.
8. Para cada tarea entregar: resumen, archivos modificados, comandos de verificación, resultados y siguiente paso propuesto.

## A. BACKEND — NestJS + TypeScript

### A1. Arquitectura y organización

Usar módulos de dominio y dependencias inyectadas. Estructura orientativa (adaptar al repositorio existente):

```text
snakerstore_backend/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── config/                 # validación de variables de entorno
│   ├── common/
│   │   ├── guards/             # FirebaseAuthGuard, RolesGuard
│   │   ├── decorators/         # CurrentUser, Roles
│   │   ├── filters/            # errores HTTP consistentes
│   │   └── dto/
│   ├── firebase/               # FirebaseModule global y providers Admin SDK
│   ├── auth/                   # identidad verificada y sesión
│   ├── users/                  # perfiles y roles
│   ├── products/               # catálogo y fotos
│   ├── inventory/              # stock y movimientos
│   ├── orders/                 # checkout, reservas, estados
│   ├── payments/               # referencia y verificación manual
│   ├── delivery-zones/         # zonas y tarifas
│   ├── store-settings/         # configuración de tienda
│   └── cloudinary/             # carga/borrado controlado de archivos
├── test/
├── .env.example
└── package.json
```

- Controladores: HTTP, DTOs y códigos de respuesta.
- Servicios: casos de uso y reglas de negocio.
- Repositorios/adaptadores: acceso a Firestore y Cloudinary; evitar consultas dispersas por controladores.
- DTOs: `class-validator` y `class-transformer`, con `ValidationPipe` global (`whitelist: true`, `forbidNonWhitelisted: true`, `transform: true`). Validar tipos, rangos, tallas, cantidades, teléfonos y referencias.
- Documentar API con Swagger (`@nestjs/swagger`), sin exponer secretos ni habilitar operaciones peligrosas sin autenticación.
- Configuración: `@nestjs/config` con validación al arranque; CORS restringido a orígenes requeridos; límites de tamaño y tipo de archivos; rate limiting en rutas sensibles.

### A2. Firebase Admin SDK

- Inicializar **una sola vez** el Admin SDK en un `FirebaseModule` global, usando `ConfigService` y providers inyectables para `Auth` y `Firestore`.
- En desarrollo local, leer la ruta a la cuenta de servicio desde una variable de entorno, por ejemplo `GOOGLE_APPLICATION_CREDENTIALS` o `FIREBASE_SERVICE_ACCOUNT_PATH`; **no codificar la ruta ni la clave en el repositorio**. Si se despliega en Google Cloud, preferir **Application Default Credentials** e identidad de servicio administrada.
- Validar que el `projectId` corresponde a `snakerstore-e74cd`. Nunca inicializar dos apps Admin por error.
- El Admin SDK **omite las reglas de seguridad de Firestore**: toda validación y autorización debe existir en NestJS.
- No solicitar ni regenerar credenciales si las existentes ya funcionan. Verificar `.gitignore` para `.env`, `firebase-service-account.json` y cualquier `*service-account*.json`.

### A3. Autenticación, autorización y roles

- Flutter inicia sesión con Firebase Authentication; NestJS **no almacena contraseñas**.
- `FirebaseAuthGuard`: leer `Authorization: Bearer <ID_TOKEN>`, llamar `firebaseAdminAuth.verifyIdToken(token, true)` cuando proceda validar revocación, responder `401` ante token ausente, inválido o revocado y adjuntar identidad confiable (`uid`, `email`) a la petición.
- `RolesGuard` + decorador `@Roles('ADMINISTRADOR')`: recuperar rol **desde una fuente confiable del servidor**, por ejemplo `users/{uid}` en Firestore. **Nunca confiar en un rol enviado por Flutter** ni en campos de la solicitud.
- Los usuarios nuevos reciben `CLIENTE` desde el backend en un flujo controlado. Nunca permitir que registro o actualización de perfil modifiquen `role`.
- Mantener el usuario administrador existente; asignaciones o cambios de rol solo mediante procedimiento administrativo seguro fuera del flujo público.
- Exponer un endpoint autenticado `GET /auth/me` que devuelva perfil y rol efectivo. **Flutter debe consultar este endpoint** para elegir su interfaz; no leer el rol directamente de Firestore como fuente de autorización.
- Catálogo público: `GET /products` y `GET /products/:id` solo devuelven productos activos y datos públicos. Pedidos, pagos, perfiles, inventario y administración requieren permisos específicos.
- Un `CLIENTE` solo puede consultar sus propios pedidos y pagos. El `uid` se obtiene del token, no del body. `ADMINISTRADOR` puede gestionar recursos según su rol.

### A4. Cloudinary y seguridad de archivos

- Crear `CloudinaryModule` y `CloudinaryService`; configurar `cloud_name`, `api_key`, `api_secret` mediante variables de entorno. **Nunca incluir `api_secret` en Flutter**.
- Flutter envía `multipart/form-data` a NestJS; backend autentica, autoriza, valida MIME real, extensión, tamaño y cantidad; sube mediante API segura de Cloudinary.
- Imágenes de catálogo: permitir visualización pública; guardar `secure_url` y `public_id` (para eventual reemplazo o eliminación).
- **Comprobantes de pago: privados/restringidos**; no basta con guardar una URL `https` si el recurso queda públicamente accesible. Definir estrategia compatible con el plan de Cloudinary para entrega autenticada o firmada, y verificarla antes de implementar. Si no se puede garantizar privacidad, no exponer comprobantes y reevaluar el proveedor/flujo.
- Solo el dueño del pedido y administradores autorizados podrán acceder a comprobantes, mediante autorización del backend. No incluir enlaces públicos en respuestas generales.
- Tratar subidas a Cloudinary y escrituras Firestore como sistemas separados: contemplar compensación/limpieza de archivos huérfanos ante fallos.

### A5. Colecciones Firestore y modelo

Colecciones definidas para el MVP:

| Colección | Propósito | Notas |
|---|---|---|
| `users` | Perfiles y roles | Documento `users/{uid}`; `role`: `CLIENTE` o `ADMINISTRADOR` |
| `products` | Catálogo | `name`, `description`, `priceCents`, `images[]`, `category`, `brand`, `active` |
| `inventory` | Existencias por talla | ID determinista por producto/talla, `available`, `reserved` |
| `orders` | Pedidos online | `userId`, `items[]`, totales, entrega, estados, vencimiento |
| `payments` | Intentos/referencias de pago | `orderId`, método, referencia, comprobante privado, estado |
| `delivery_zones` | Tarifas por zona | `name`, `feeCents`, `active` |
| `store_settings` | Configuración general | Métodos de pago, dirección de recojo, reglas visibles |
| `inventory_movements` | Auditoría de inventario | Tipo, cantidad, origen, fecha, actor |

**No crear colección `sales`, módulo POS ni pantallas de venta presencial.**

- Moneda: **PEN**, todos los importes persistidos como **enteros en céntimos** (`priceCents`, `totalCents`, `feeCents`). Validar enteros no negativos y límites razonables.
- Tallas: europeas numéricas, p. ej. `38`, `39`, `40`, `41`; adoptar **una representación consistente** (preferible string normalizada para IDs y visualización) y validarla.
- `orders.items[]`: guardar snapshot de nombre, talla, cantidad y precio unitario al crear el pedido. Calcular subtotal, delivery y total **en backend** a partir de datos confiables.
- Registrar timestamps de servidor, estados explícitos y campos de auditoría.
- Definir índices compuestos según consultas reales y documentarlos. Evitar lecturas de colecciones completas.
- `inventory.available` = unidades no reservadas; `inventory.reserved` = unidades apartadas; no permitir cantidades negativas.
- La selección de zona determina tarifa, tomada del documento activo en Firestore. Para `PICKUP`, tarifa de entrega = 0. Conservar snapshot de tarifa/zona en el pedido.

### A6. Checkout transaccional y reservas

**Caso de uso crítico: `POST /orders`**

1. Exigir `CLIENTE` autenticado. Validar productos, tallas, cantidades, entrega y zona.
2. Leer **dentro de una transacción Firestore** los documentos necesarios de productos, inventario y tarifa, antes de escribir. No confiar en precios ni totales enviados por Flutter.
3. Verificar que cada producto esté activo, que las cantidades sean positivas y que `available >= quantity`.
4. Crear documento de pedido con ID generado, `status = PENDIENTE_PAGO`, `paymentStatus = PENDIENTE`, `reservationExpiresAt = createdAt + 24 h`, snapshots y totales calculados.
5. En la misma transacción, para cada talla: `available -= quantity`, `reserved += quantity`; crear registros de `inventory_movements` correspondientes.
6. Si falla cualquier validación o hay conflicto, abortar/reintentar la transacción sin sobreventa. No realizar llamadas externas ni efectos secundarios no idempotentes dentro del callback transaccional.
7. Diseñar **idempotencia** del checkout mediante una clave de solicitud para evitar pedidos duplicados por reintentos de red.

**Ciclo de vida de reserva:**

- `PENDIENTE_PAGO` → `PENDIENTE_VERIFICACION` al enviar referencia; el envío **no equivale a pago aprobado**.
- `PENDIENTE_VERIFICACION` → `PAGO_APROBADO` únicamente por administrador tras verificar fondos recibidos; dentro de una transacción, disminuir `reserved` y dejar el inventario vendido de manera definitiva (sin volver a reducir `available`).
- `PAGO_RECHAZADO`: se permite reenviar otra referencia dentro de las 24 horas originales; mantener la reserva hasta aprobación, cancelación o vencimiento. El reenvío no amplía el plazo.
- A las **24 horas sin aprobacion**, bloquear nuevos pagos. El administrador procesa manualmente el vencimiento con POST /admin/orders/expire para cancelar y liberar stock. No hay cancelacion automatica al consultar pedidos.
- La aprobación, cancelación y expiración deben competir de forma segura en **transacciones condicionales** y ser **idempotentes**: un pedido no puede aprobarse después de cancelarse ni liberar stock dos veces.
- Decision posterior del usuario: sin scheduler ni vencimiento automatico. Mantener transacciones e idempotencia para el procesamiento manual. Alcance: demostracion local con NestJS en el PC y Flutter conectado por la red local; sin despliegue obligatorio.
- Separar estado de pago y estado logístico (preparando, listo para recojo/en reparto, entregado). No permitir transiciones arbitrarias.

### A7. Pagos y entregas

- Métodos admitidos: `YAPE`, `PLIN`, `TRANSFERENCIA`. Sin pasarela ni confirmación automática.
- Referencia de operación **obligatoria**, imagen de comprobante **opcional**. Validar formato, longitud y duplicados sospechosos; no asumir que una referencia prueba el ingreso de dinero.
- El administrador revisa el pago y registra actor, fecha y motivo de rechazo. Mantener trazabilidad de intentos; no permitir que el cliente altere estados administrativos.
- Entrega: `DELIVERY` requiere zona activa y dirección; `PICKUP` requiere información de recojo, sin tarifa de delivery.
- El administrador puede actualizar preparación y entrega solo mediante transiciones permitidas.

### A8. Endpoints orientativos

```text
GET    /products                     público
GET    /products/:id                 público
GET    /auth/me                      autenticado
PATCH  /users/me                     cliente autenticado
POST   /admin/products               ADMINISTRADOR
PATCH  /admin/products/:id           ADMINISTRADOR
POST   /admin/products/:id/images    ADMINISTRADOR, multipart
GET    /admin/inventory              ADMINISTRADOR
PATCH  /admin/inventory/:id          ADMINISTRADOR
GET    /delivery-zones               público: zonas activas
POST   /admin/delivery-zones         ADMINISTRADOR
POST   /orders                       CLIENTE
GET    /orders                       CLIENTE, solo propios
GET    /orders/:id                   propietario o ADMINISTRADOR
POST   /orders/:id/payments          propietario, multipart opcional
GET    /admin/orders                 ADMINISTRADOR
POST   /admin/payments/:id/approve   ADMINISTRADOR
POST   /admin/payments/:id/reject    ADMINISTRADOR
PATCH  /admin/orders/:id/status      ADMINISTRADOR
```

Son contratos **propuestos**, no existentes. Definir DTOs, códigos HTTP, errores, paginación, filtros, Swagger y pruebas antes de declararlos terminados.

### A9. Pruebas mínimas del backend

- `401` sin token; `403` para cliente en rutas admin; denegar acceso a pedidos ajenos.
- Registro de usuario siempre con rol `CLIENTE` y sin escalamiento de privilegios.
- Precios, totales y delivery calculados en servidor; datos manipulados por cliente ignorados/rechazados.
- Checkout concurrente sobre última unidad: **solo un pedido exitoso**.
- Aprobación simultánea con vencimiento: un único resultado válido.
- Expiración repetida no duplica liberación de stock.
- Comprobantes inaccesibles sin autorización.
- Validaciones de imágenes, tamaños, MIME, DTOs y variables de entorno.
- Pruebas unitarias de casos de uso y de integración con Firebase Emulator Suite cuando sea viable; no usar datos reales para pruebas destructivas.

## B. FRONTEND — Flutter + Dart

### B1. Arquitectura y estructura

Flutter es el **frontend móvil**, no el backend. Usar **Riverpod** para gestión de estado y dependencias (opción elegida para mantener una sola convención), `go_router` para rutas y `dio` para HTTP. Estructura orientativa:

```text
sneakerstore_mobile/
└── lib/
    ├── main.dart
    ├── app/
    │   ├── app.dart
    │   └── router.dart
    ├── core/
    │   ├── config/
    │   ├── network/             # Dio, interceptores y errores
    │   ├── theme/
    │   └── widgets/
    └── features/
        ├── auth/
        ├── catalog/
        ├── product_detail/
        ├── cart/
        ├── checkout/
        ├── payments/
        ├── orders/
        ├── profile/
        └── admin/
            ├── dashboard/
            ├── products/
            ├── inventory/
            ├── orders/
            ├── payments/
            └── delivery_zones/
```

En cada feature, separar cuando aporte claridad: `data` (DTOs, datasource, repositorios), `domain` (modelos/casos de uso) y `presentation` (providers, pantallas, widgets). Evitar arquitectura ceremoniosa innecesaria.

### B2. Autenticación y rol

- Configurar `firebase_core` y `firebase_auth` mediante FlutterFire; **no incluir credenciales de Firebase Admin en Flutter**.
- Registrar e iniciar sesión con Email/Password. Para solicitudes autenticadas, obtener `FirebaseAuth.instance.currentUser?.getIdToken()` y adjuntarlo mediante interceptor Dio como `Authorization: Bearer <token>`.
- No persistir manualmente tokens en texto plano ni loguearlos. Manejar renovación automática, logout y errores `401`.
- Tras iniciar sesión, consultar `GET /auth/me` en NestJS para conocer el **rol confiable**. No permitir que la navegación se base en un campo editable localmente o en lecturas directas de Firestore.
- `CLIENTE` → navegación de catálogo, carrito, pedidos y perfil. `ADMINISTRADOR` → interfaz administrativa exclusiva.
- Las barreras de navegación son experiencia de usuario; **NestJS aplica la autorización real**.
- Catálogo público sin login; pedir autenticación antes de checkout.

### B3. Consumo de API y estado

- Centralizar `Dio` con `baseUrl` configurable por entorno (emulador Android, dispositivo físico y producción). Nunca usar `localhost` para referirse al PC desde un teléfono físico.
- Definir repositorios tipados (`ProductsRepository`, `OrdersRepository`, `PaymentsRepository`, etc.) y modelos de respuesta. Manejar errores de red, validación, expiración y permisos con mensajes claros.
- Riverpod gestiona sesión, catálogo, carrito, checkout, pedidos y administración; no duplicar estados innecesariamente.
- El carrito puede ser local durante el MVP; **no es reserva**. Mostrar precios tentativos y permitir que el servidor recalcule todo al confirmar.
- No acceder directamente a Firestore para operaciones de negocio; todas pasan por NestJS. Firebase Auth es la excepción prevista.

### B4. Pantallas CLIENTE

1. Splash/estado de sesión.
2. Inicio de sesión, registro y recuperación de contraseña.
3. Catálogo público con búsqueda y filtros.
4. Detalle de zapatilla, imágenes y selector de talla EU.
5. Carrito (cantidad, eliminación, subtotal).
6. Checkout: `DELIVERY` con zona/dirección o `PICKUP` en tienda.
7. Pago: Yape/Plin/transferencia, referencia obligatoria, imagen opcional, contador de reserva.
8. Mis pedidos e historial.
9. Detalle del pedido, estado de pago y seguimiento de entrega.
10. Perfil.

**Estados obligatorios:** cargando, vacío, sin conexión, error de validación, sin stock, pago en revisión, rechazado, pedido cancelado por vencimiento y operación exitosa. El contador es informativo: la decisión final de expiración pertenece al backend.

### B5. Pantallas ADMINISTRADOR

1. Dashboard básico (pedidos, pagos por verificar, productos y stock bajo).
2. Lista y gestión de productos.
3. Crear/editar producto y subir imágenes.
4. Inventario por producto/talla y ajustes.
5. Lista de pedidos online.
6. Detalle de pedido y aprobación/rechazo de pago.
7. Configuración de zonas y tarifas de delivery.
8. Perfil/cierre de sesión.

**Prohibido implementar:** registrar venta presencial, historial de ventas físicas, POS o colección `sales`. La opción **recojo en tienda** es una modalidad de entrega de un pedido online, **no** una venta física.

### B6. Imágenes con Cloudinary a través de NestJS

- Usar `image_picker` (y dependencias compatibles) para seleccionar imágenes.
- Enviar archivo como `MultipartFile` mediante `FormData` de Dio al endpoint NestJS autorizado.
- Mostrar progreso, límites de tamaño, errores y vista previa.
- Imágenes de productos solo desde acciones admin. Comprobantes de pago solo para pedidos del cliente autenticado, imagen opcional.
- **No llamar directamente a la API administrativa de Cloudinary desde Flutter ni almacenar secretos en la app**.

### B7. Calidad del frontend

- Usar tema consistente, componentes reutilizables, diseño responsive dentro de Flutter, accesibilidad básica y textos en español.
- Mostrar importes PEN formateados desde céntimos enteros; no usar `double` para lógica monetaria.
- Validar formularios localmente para UX, pero asumir que el backend revalida todos los datos.
- Crear pruebas de widgets y providers para login, navegación por roles, carrito, checkout y estados de error.
- Ejecutar `flutter analyze`, `flutter test` y probar en dispositivo Android antes de declarar una funcionalidad terminada.
- Si el usuario aporta diseños de Stitch o archivos Markdown de UI, tratarlos como **referencia visual**; adaptarlos a widgets Flutter, sin generar Next.js salvo petición explícita posterior.

## C. Orden de implementación y puntos de control

1. **Auditoría del estado actual**: comprobar NestJS, Firebase Admin SDK, `.env`, `.gitignore`, colecciones y usuario administrador **sin exponer credenciales**.
2. **Fundación backend**: configuración validada, FirebaseModule, `FirebaseAuthGuard`, `RolesGuard`, `/auth/me`, Swagger y pruebas.
3. **Catálogo e inventario**: CRUD admin, consultas públicas, stock por talla y movimientos.
4. **Cloudinary**: carga segura de imágenes de productos; revisar mecanismo privado para comprobantes.
5. **Delivery y configuración**: zonas activas, tarifas, recojo y ajustes de tienda.
6. **Checkout transaccional**: pedidos, reserva 24 h, idempotencia y pruebas de concurrencia.
7. **Pagos y vencimientos**: referencias, verificación admin, liberación de stock, procesamiento manual y pruebas de carrera.
8. **Fundación Flutter**: app, tema, navegación, Firebase Auth, Dio y Riverpod.
9. **Flujo CLIENTE**: catálogo → detalle → carrito → checkout → pago → pedidos → perfil.
10. **Flujo ADMINISTRADOR**: dashboard → productos → inventario → pedidos/pagos → zonas.
11. **Integración y entrega**: pruebas extremo a extremo, seguridad, manejo de errores, APK Android y documentación de despliegue.

**Criterio de cierre por tarea:** código compilable, pruebas aplicables aprobadas, permisos verificados, sin secretos filtrados y explicación de cómo ejecutar/verificar.

## D. Decisiones abiertas que la IA debe confirmar antes de codificar esa parte

- Configuración real y límites de **Cloudinary**, especialmente privacidad de comprobantes y cuota gratuita.
- Vencimiento manual confirmado por el usuario; sin scheduler. Demostracion local, sin despliegue.
- Decisiones confirmadas por el usuario: delivery requiere destinatario, celular, zona activa y dirección, con referencia opcional; el cliente puede cancelar antes de aprobarse el pago; un pago rechazado puede reenviarse con otra referencia dentro del plazo original de 24 horas.
- Identificador Android y configuración FlutterFire, cuando comience el frontend.
- Nombres y campos reales de los documentos ya creados en `users` (por ejemplo `name` frente a `fullName`): **inspeccionar y adaptar sin borrar datos**.

**Instrucción final a Codex:** comienza inspeccionando el proyecto existente y proponiendo **solo el primer incremento verificable**. No generes todo el sistema en una sola respuesta ni cambies decisiones de negocio sin consultarlo.
