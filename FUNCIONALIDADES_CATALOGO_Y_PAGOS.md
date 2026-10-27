# Catálogo, administración y checkout demo

## Género y colores

En Administración → Productos → Crear/Editar se puede elegir Hombre, Mujer,
Unisex o Sin especificar y varios colores. Guardar conserva los atributos.
La ficha del cliente muestra las etiquetas de color y el género.
El catálogo incorpora filtros de Hombre, Mujer y Unisex aplicados por la API
antes de paginar. Unisex tiene su propio filtro. Los productos antiguos sin
género permanecen en Todos hasta que el administrador los clasifique.
Los colores describen el producto; no son variantes de stock ni cambian las
texturas del GLB. El inventario sigue administrándose por artículo y talla.

API: `GET /products?gender=MUJER&limit=20`, también disponible para admin.
Los géneros aceptados son HOMBRE, MUJER, UNISEX y SIN_ESPECIFICAR.
Los colores aceptados están enumerados en Swagger. No se requieren nuevos
índices compuestos para los filtros implementados.

## Pedidos por fechas

Administración → Pedidos → Filtrar por fecha o rango. Para un solo día,
seleccionar el mismo día como inicio y final. Quitar filtro restaura todos.
El rango se conserva al pasar de página, se combina con búsqueda/estado de
la página y se aplica en el servidor antes de paginar. Cambiar rango reinicia
el cursor. Las fechas corresponden a la creación del pedido en America/Lima;
se incluye todo el día final. Los resultados del rango se ordenan de más
recientes a más antiguos, con desempate por ID.

API: `GET /admin/orders?from=2026-10-01&to=2026-10-27&limit=20`.
Se admite solo `from` o solo `to`. Fechas inexistentes y rangos invertidos
devuelven 400. La ruta exige sesión de administrador.

## Gráfico de ventas

El panel administrativo muestra barras diarias para 7, 30 y 90 días.
Mantener pulsada una barra muestra su importe. Suma los pagos APROBADO que
no sean simulaciones, usando la fecha de aprobación; para registros antiguos
sin esa fecha, utiliza la de creación. La agrupación usa los días de Perú y
rellena con cero los días sin ventas. Los datos incluyen todas las páginas
de pedidos recuperadas por el resumen administrativo.

## API de pago demo sin claves

Esta es una **pasarela local de pruebas**, no una integración comercial.
No requiere cuenta, API key ni SDK externo de pagos. Usa la autenticación
de cliente que ya tiene la app. No procesa dinero ni acepta datos de tarjetas.

Desde el pedido o la pantalla de pago, elegir Probar pasarela sin claves,
confirmar la conversión a pedido de prueba y elegir uno de los tres escenarios:

- Aprobar: consume las unidades ya reservadas una sola vez, deja el pedido
  en preparación y lo marca como SIMULADO. Nunca lo registra como venta real.
- Rechazar: permite reintentar, conservando la reserva hasta su vencimiento.
- Pendiente: conserva la reserva; permite simular una resolución posterior.

La pantalla muestra solo identificadores ficticios, sin formulario de tarjeta.
Salir del checkout no aprueba el pago. Los pedidos vencidos, cancelados,
ajenos o con referencias manuales no se pueden pagar por este flujo.
Las referencias manuales y la simulación anterior siguen disponibles.

Endpoints autenticados, rol CLIENTE:

1. `POST /orders/{id}/demo-checkout` sin cuerpo. Crea o recupera una sesión.
   El servidor toma el total del pedido y lo marca como simulación al entrar.
2. `GET /demo-checkouts/{id}` consulta estado e importe.
3. `POST /demo-checkouts/{id}/confirm` con
   `{"scenario":"APPROVED"}`, `REJECTED` o `PENDING`.
   El servidor rechaza importes y datos de tarjetas enviados en el cuerpo.

Repetir una aprobación devuelve la misma sesión sin descontar existencias de
nuevo. Los fallos de inventario abortan la transacción sin aprobar el checkout.
La opción demo está disponible por defecto en desarrollo; producción la
deshabilita por defecto. Configurar `DEMO_GATEWAY_ENABLED=true` la habilita
explícitamente y `false` la deshabilita. `/checkout-options` informa el estado.
No hay credenciales nuevas que completar. Reiniciar backend y app después
de incorporar estos cambios. El uso de una pasarela real requerirá sustituir
el adaptador demo e incorporar credenciales y notificaciones del proveedor.

## Verificación

El backend compila y sus pruebas unitarias pasan. Las pruebas nuevas cubren
atributos válidos e inválidos, paginación de géneros sin artículos inactivos,
fechas peruanas, cursores, permisos HTTP, importes controlados por servidor,
checkout ajeno/vencido, reintentos y consumo único de reservas. En Flutter
pasan las pruebas nuevas del gráfico, compatibilidad de productos antiguos y
checkout aprobado/rechazado/pendiente sin formulario de tarjeta.

La suite general mantiene los fallos ya observados antes de estos cambios:
una expectativa de validación de inventario por HTTP y tres pruebas Flutter
de login/menú/cierre de sesión. No se reporta una suite global verde. En este
equipo no está configurado el SDK Android; no se generó una nueva APK.
