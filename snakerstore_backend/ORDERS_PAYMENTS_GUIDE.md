# Pedidos, reservas, pagos y vencimientos

## Cómo funciona

Flutter inicia sesión en Firebase Auth y llama a NestJS con un ID token. NestJS
debe ejecutarse en un servidor; no forma parte del APK ni corre dentro del teléfono.
En desarrollo puede correr en tu PC. Para publicar la app hace falta una URL HTTPS
y un backend disponible; el alojamiento de producción sigue por decidir.

Este incremento implementa pedidos online, entrega/recojo, reserva de stock por
24 horas, referencias de pago, aprobación/rechazo manual y vencimiento. No incluye
ventas presenciales, pasarela de pago ni confirmación bancaria automática.

Reglas acordadas:

- DELIVERY exige nombre del destinatario, celular peruano, zona activa y dirección;
  referencia de dirección opcional. PICKUP exige nombre y celular y toma los datos
  de recojo configurados en tienda; no acepta zona/dirección de delivery.
- El cliente puede cancelar mientras no se haya aprobado el pago.
- Un pago rechazado puede reenviarse con otra referencia dentro de las 24 horas
  originales. Rechazar o reenviar no amplía el plazo.
- Cada pedido admite un intento en revisión. Se conserva el historial de intentos.
- Comprobantes de imagen no están habilitados: las referencias se envían como JSON.
  Su privacidad en Cloudinary debe definirse antes de permitir archivos de pago.

## Preparación en Swagger

Ejecutar `pnpm start:dev` desde el backend y abrir http://localhost:3000/docs.
Usar el puerto de `.env` si es diferente.

Con token ADMINISTRADOR:

1. Crear producto activo y stock de su talla (ver `SWAGGER_GUIDE.md`).
2. Crear zona activa y configuración de tienda con un método habilitado
   (ver `DELIVERY_STORE_GUIDE.md`). Para PICKUP, `pickup.enabled` debe ser true.

Para comprar, usar una cuenta CLIENTE de Firebase Auth. No convertir al administrador
en cliente ni cambiar su rol. Un perfil nuevo se crea como CLIENTE al acceder a la API.

## Crear pedido con CLIENTE

En `POST /orders`, completar el encabezado **Idempotency-Key**, por ejemplo
`checkout-prueba-0001`, y el cuerpo:

```json
{
  "items": [
    { "productId": "ID_PRODUCTO", "size": "40", "quantity": 1 }
  ],
  "delivery": {
    "type": "DELIVERY",
    "recipientName": "Nombre del destinatario",
    "phone": "900000000",
    "zoneId": "ID_ZONA",
    "address": "Dirección de entrega 123",
    "reference": "Frente al parque"
  }
}
```

Para recojo, sustituir delivery por:

```json
{
  "type": "PICKUP",
  "recipientName": "Nombre del cliente",
  "phone": "900000000"
}
```

Respuesta 201 con el ID del pedido y totales en céntimos PEN. No enviar precios,
totales, estado ni userId. El servidor usa productos, inventario, tarifa y datos
de tienda leídos dentro de la transacción. Guarda snapshots para que cambios
posteriores del catálogo no alteren el pedido.

La clave admite 8–128 letras, números, guiones o guiones bajos. Reutilizarla solo
para el mismo checkout: devuelve el mismo pedido sin reservar de nuevo. Cambiar
el contenido con la misma clave responde 409. Una nueva compra necesita otra clave.
Los productos/tallas repetidos se agrupan; máximo 30 líneas y 100 unidades por talla.

La creación descuenta `inventory.available` y suma `inventory.reserved` en la misma
transacción que crea el pedido y los movimientos. No se permite sobreventa.

## Consultar y cancelar

- `GET /orders`: solo los pedidos propios del CLIENTE.
- `GET /orders/{id}`: propietario o ADMINISTRADOR.
- `GET /admin/orders`: todos los pedidos, solo ADMINISTRADOR.
- `POST /orders/{id}/cancel`: propietario CLIENTE antes de aprobarse el pago.

Repetir cancelación no libera stock dos veces. Pedidos ajenos devuelven 404.
Los listados usan `limit`, `after` y `nextCursor`, ordenados por ID.

## Referencia de pago y revisión

Con CLIENTE, usar `POST /orders/{id}/payments`:

```json
{ "method": "YAPE", "reference": "OPERACION-123456" }
```

También se admite PLIN o TRANSFERENCIA si el método está habilitado en tienda.
La referencia debe tener 4–80 caracteres: letras, números, guiones o guiones bajos;
se normaliza a mayúsculas. El importe lo toma el servidor del total del pedido.
No incluir fotos, contraseñas, tokens ni datos administrativos.

Respuesta 201 con el ID del pago. Reenviar la misma referencia para el mismo pedido
devuelve el intento existente. El mismo método y referencia en otro pedido se
rechazan con 409 para revisión. Referencias de operaciones legítimamente repetidas
requieren resolución administrativa fuera del flujo automático.

El pedido pasa a PENDIENTE_VERIFICACION; **todavía no está pagado**.

Cambiar Authorize al token ADMINISTRADOR:

- `POST /admin/payments/{id}/approve`: usar solo tras verificar el ingreso de fondos.
  Responde 201 con el pedido; reduce reserved, sin volver a descontar available.
  Repetir aprobación devuelve el pedido sin duplicar movimientos.
- `POST /admin/payments/{id}/reject`, cuerpo
  `{ "reason": "No se encontró el ingreso de fondos" }`: responde 201 con el pago.
  Mantiene la reserva hasta cancelación, vencimiento o aprobación de un nuevo intento.
- `GET /orders/{id}/payments`: historial, accesible al propietario o administrador.

No se puede aprobar un intento antiguo rechazado ni un pedido cancelado/vencido.
Cambiar contraseña o recuperar sesión sigue siendo responsabilidad de Firebase Auth.

## Estados de preparación y entrega

Tras aprobar el pago, fulfillmentStatus es PREPARANDO. Con ADMINISTRADOR usar
`PATCH /admin/orders/{id}/status`, por ejemplo `{ "status": "EN_REPARTO" }`.

- DELIVERY: PREPARANDO → EN_REPARTO → ENTREGADO.
- PICKUP: PREPARANDO → LISTO_RECOJO → ENTREGADO.

No se permiten saltos, retrocesos ni avances antes de aprobar el pago. Repetir el
estado actual es seguro. `status`, `paymentStatus` y `fulfillmentStatus` son campos
separados; el seguimiento logístico no cambia la confirmación del pago.

## Vencimiento manual

No hay tareas programadas ni cancelaciones al consultar pedidos. Se conserva el
plazo de 24 horas para bloquear pagos tardios. El stock permanece reservado hasta
que el administrador ejecute POST /admin/orders/expire o el cliente cancele.

El endpoint manual procesa hasta 1000 pedidos ya vencidos por solicitud, devuelve
expiredCount y failedCount y puede repetirse sin liberar stock dos veces. Si quedan
mas pedidos, ejecutar otra vez. Un failedCount mayor que cero requiere revisar el
inventario. La cancelacion, aprobacion y expiracion conservan sus transacciones.

Se elimino el worker, su dependencia y RESERVATION_WORKER_ENABLED. Consultar pedidos
solo lee datos. No se requiere infraestructura de programacion de tareas.

Para una demostracion local, NestJS debe estar encendido en tu PC. Flutter usa la
IP local del PC como URL de API, no localhost del telefono. Ambos dispositivos
necesitan acceso entre si y a internet para Firebase y Cloudinary. NestJS no se
incluye dentro de la APK. No se exige desplegar para este alcance local.

## Pruebas de integración

Requisitos: Java 21, Node 24 y pnpm. En una terminal:

```powershell
pnpm emulators:start
```

En otra, desde el backend:

```powershell
pnpm test:integration
```

Los puertos locales son Auth 9098 y Firestore 8089, con proyecto **demo-sneakerstore**.
Las pruebas fijan los hosts locales y sustituyen los proveedores Firebase, por lo
que no utilizan la cuenta de servicio real. Crean datos descartables en el emulador;
Cloudinary se sustituye por un doble y no recibe archivos reales.

La suite recorre Auth → productos/fotos → inventario → zonas/configuración → checkout
→ referencias → rechazo/aprobación → logística y vencimiento. También cubre pedidos
ajenos, manipulación de totales, idempotencia simultánea, competencia por la última
unidad, cancelación frente a aprobación y liberación única al vencer. Las fechas se
adelantan solo en documentos del proyecto demo para comprobar el vencimiento sin
esperar 24 horas.

Verificaciones adicionales: `pnpm build`, `pnpm lint`, `pnpm test`, `pnpm test:e2e`.

Referencias oficiales:
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/emulator-suite/connect_firestore
