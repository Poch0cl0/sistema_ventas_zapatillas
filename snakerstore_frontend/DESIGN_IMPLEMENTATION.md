# Rediseño móvil de SneakerStore

Referencias: `Login`, `Vistas para cliente` y `Vistas para administrador`, con el
sistema Kinetic Minimal. Las imágenes de referencia se conservaron.

## Pantallas conectadas

| Referencia | Implementación normal |
| --- | --- |
| Login, registro y recuperación | Cabeceras, formularios, tarjetas y acciones según el modo |
| Inicio y catálogo móvil | Banner con producto real, filtros y cuadrícula adaptable |
| Detalle de producto | Galería, miniaturas, tallas, cantidad y botón de añadir |
| Carrito | Tarjetas con imagen, talla, cantidad y resumen de compra |
| Checkout | Pasos de compra y secciones de entrega, destinatario, zona y mapa |
| Registro de pago | Resumen, selección de método, datos copiables y referencia |
| Mis pedidos | Tarjetas con artículos, reserva, pago y estado de entrega |
| Detalle del pedido | Línea de avance, recepción, mapa, artículos y pagos |
| Perfil | Iniciales, resumen real de pedidos, información personal y seguridad |
| Dashboard administrativo | Métricas reales, revisión de pagos y alertas de stock |
| Productos administrativos | Tarjetas móviles con foto, precio, estado y edición |
| Inventario | Tarjetas por talla con disponibles, reservados y total |
| Zonas de delivery | Tarjetas con tarifa, estado y edición |
| Formularios administrativos | Datos, fotografías, stock, cobertura y pagos por secciones |

La estructura compartida está en `lib/core/store_design.dart`: encabezado,
navegación inferior, superficies, estados, resúmenes y línea de avance. El tema
de `lib/core/ui.dart` usa negro, naranja, grises y la fuente Inter incluida en
`assets/fonts`, con su licencia OFL. No depende de descargar fuentes al abrir.

## Adaptación a móvil

- Cliente: Inicio, Catálogo, Carrito, Pedidos y Perfil en navegación inferior.
- Administrador: Resumen, Productos, Stock, Pedidos y Zonas, con configuración
  de tienda accesible desde el panel.
- Las tablas y la barra lateral de escritorio se sustituyeron por tarjetas y
  navegación táctil. Los formularios se dividen en secciones con espacio entre
  controles y acciones.
- El catálogo utiliza dos columnas en móviles habituales, una con ancho pequeño
  o texto ampliado, y hasta tres en pantallas mayores. El contenido se limita a
  un ancho cómodo en tabletas.

## Datos reales

Se mantuvieron Firebase, los repositorios NestJS, la selección de zona, el mapa,
las reservas y las operaciones administrativas. Las métricas se calculan con
los registros existentes. Los filtros de listas paginadas indican que operan
sobre la página visible. La imagen de cabecera del catálogo usa un producto real.

Los simuladores y las cifras de ejemplo de los diseños no se incluyen en el
modo conectado. Tampoco se añadieron controles sin operación disponible,
como Google Sign-In, cupones, QR no configurados, reseñas, favoritos, comprobantes
adjuntos, facturas o GPS del repartidor. La línea de avance se basa en los estados
del pedido, sin inventar horas de eventos o tiempos de llegada.

La talla se selecciona primero y solo se agrega al pulsar el botón; la cantidad
se valida junto con el stock al agregar. El carrito no muestra stock como
reservado antes de crear el pedido.

## Validación pendiente

Se revisaron las referencias visuales y se aplicó formato al código Dart.
No se ejecutaron pruebas, análisis de Flutter, compilaciones, instalación ni la
app. Falta comparar el resultado renderizado en el celular y comprobar la
navegación y los flujos después del rediseño.
