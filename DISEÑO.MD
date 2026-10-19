/** Prompt Maestro*/

# STITCH — SISTEMA DE DISEÑO GLOBAL

Diseña la interfaz de una aplicación móvil de comercio electrónico llamada provisionalmente "SneakerStore", especializada en la venta de zapatillas deportivas y urbanas.

## Contexto del proyecto

Es una plataforma de ventas físicas y online que tendrá dos roles:

- CLIENTE: explora zapatillas, selecciona tallas, administra su carrito, realiza pedidos, registra pagos y consulta entregas.
- ADMINISTRADOR: gestiona productos, inventario, ventas físicas, pedidos online, pagos y zonas de delivery.

El frontend se desarrollará en Next.js, TypeScript y Tailwind CSS. El backend será NestJS y utilizaremos Firebase Authentication, Cloud Firestore y Firebase Storage.

El objetivo es construir un MVP funcional, moderno, responsive y profesional.

## Identidad visual

Estilo: ecommerce moderno, minimalista, deportivo y premium.

Paleta:
- Negro principal: #111111
- Blanco: #FFFFFF
- Gris de fondo: #F7F7F8
- Gris secundario: #6B7280
- Color de acento: #FF6B35
- Verde de éxito: #16A34A
- Rojo de error: #DC2626

Tipografía: Inter o una fuente sans-serif similar.

Utiliza fotografías de zapatillas con fondos limpios, tarjetas con bordes suaves, iconografía Lucide y una jerarquía visual clara.

## Diseño responsive

- Mobile-first para clientes.
- Escritorio optimizado para el panel administrativo.
- Breakpoints compatibles con Tailwind CSS.
- Formularios accesibles y controles cómodos para dispositivos táctiles.
- Menú inferior en móvil para clientes.
- Sidebar en escritorio para administradores.
- Menú adaptable en móvil para administradores.

## Componentes reutilizables

Diseña un sistema consistente de:
- Botones primarios y secundarios.
- Campos de formulario.
- Tarjetas de productos.
- Selectores de talla EU.
- Badges de estado.
- Modales de confirmación.
- Tablas administrativas.
- Filtros y buscadores.
- Alertas y mensajes de error.
- Skeleton loaders y estados vacíos.
- Encabezados y navegación.

## Reglas funcionales

- El catálogo será público.
- Para comprar será necesario iniciar sesión.
- Los administradores tendrán una interfaz exclusiva.
- Las tallas serán europeas: 38, 39, 40, 41, 42, etc.
- Los pagos serán mediante Yape, Plin y transferencia.
- La referencia de operación será obligatoria y la imagen del comprobante opcional.
- Los pedidos tendrán una reserva de stock de 24 horas.
- Las reservas vencerán automáticamente si no se aprueba el pago.
- El delivery se calculará según la zona seleccionada.
- Las ventas presenciales requerirán nombre completo, teléfono y DNI.

## Instrucciones de diseño

Todas las pantallas deben pertenecer visualmente al mismo producto.

Mantén los mismos colores, tipografía, espaciados, encabezados, botones, tarjetas y navegación.

No inventes funcionalidades fuera del MVP.

Utiliza textos reales en español y precios expresados en soles peruanos (S/).

Diseña las interfaces para que posteriormente puedan implementarse con Next.js y Tailwind CSS.

Genera interfaces visuales y estados de interacción; no simules integraciones reales con Firebase ni NestJS.