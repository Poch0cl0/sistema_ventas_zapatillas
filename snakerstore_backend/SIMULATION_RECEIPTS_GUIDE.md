# Compra opcional, rutas por zona y boletas de simulación

## Flujo

Actualización: al elegir `PAY`, el pedido queda directamente con estado y
`fulfillmentStatus` `ENTREGADO`. No requiere preparación ni reparto. La interfaz
usa «Pago realizado»; el indicador interno `isSimulation` y el estado de pago
`SIMULADO` se conservan para evitar contabilizar cobros reales. No se modifican
automáticamente los pedidos históricos. La boleta conserva la aclaración de
que no tiene valor tributario y que el importe realmente cobrado es cero.

En inventario, crear permite seleccionar varias tallas EU (28 a 48) y una talla
personalizada; el stock inicial indicado se aplica a cada talla seleccionada.
Cada alta se guarda individualmente. Las altas completadas se retiran de la
selección si falla alguna de las siguientes. El motivo es opcional tanto al
crear como al ajustar existencias; el backend registra un texto por defecto.

`CHECKOUT_SIMULATION_ENABLED=true` habilita el modo de demostración. Está activado
en el `.env` local. El cliente puede crear el pedido aunque no haya métodos de
pago habilitados. Después elige:

- **Continuar sin pagar**: estado `NO_REQUERIDO`; continúa la preparación sin cobro.
- **Simular pago y generar boleta**: estado `SIMULADO`; genera el comprobante y
  trata de enviarlo al correo registrado en Firebase Authentication.

Las simulaciones no pasan a `APROBADO` y no se suman a las ventas con pagos reales
del dashboard. Sí siguen el inventario de demostración: al crear el pedido se
reserva stock, y al confirmar cualquiera de las dos opciones se consolida una
única vez. Se registran movimientos `VENTA_SIMULADA` o `PEDIDO_SIN_PAGO`. Un pedido
sin pago ya confirmado puede pasar a pago simulado sin descontar otra vez.
Los pedidos con una referencia bancaria previa requieren revisión administrativa
y no se convierten silenciosamente a simulación.

El administrador puede avanzar preparación, reparto/recojo y entrega en los
pedidos confirmados sin pago. Los pagos completados pasan directamente a entregado.
La boleta se emite al completar el pago; el cliente puede consultarla en el
pedido. Indica explícitamente **sin cobro real, importe cobrado S/ 0.00 y sin
valor tributario**. No integra facturación fiscal.

## Correo de Gmail

Ya se dejaron `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER` y `SMTP_FROM` en el `.env`
local usando la cuenta remitente indicada por el usuario. Falta completar:

```dotenv
SMTP_PASS=contraseña_de_aplicación_de_Google
```

Para crearla, activar la verificación en dos pasos de esa cuenta y abrir
https://myaccount.google.com/apppasswords. Crear una contraseña para SneakerStore
y guardarla solo en el `.env` del backend, sin espacios de separación. No usar
la contraseña habitual de Gmail ni compartir la clave en el chat. La opción
puede no estar disponible en cuentas con restricciones de Google.

Referencia oficial: https://support.google.com/accounts/answer/185833?hl=es

Reiniciar el backend tras cambiar `.env`. El envío usa TLS y adjunta la boleta
PDF generada en memoria. El destinatario se obtiene de Firebase, no de un campo
editable ni del número de celular del pedido.

Si falta SMTP, la boleta se conserva con `NOT_CONFIGURED`. Si falla el correo,
el pedido no se revierte y se muestra `FAILED`, con opción de reintentar desde
la boleta. Hay un bloqueo de dos minutos entre intentos por pedido; los reintentos
no repiten movimientos de inventario. `SENT` indica aceptación por el servidor
SMTP, no una garantía de llegada a bandeja principal. No hay bucle automático
de reenvíos ni se enviaron mensajes durante la implementación.

## Origen de cada zona

En administración → Zonas → Crear/Editar, seleccionar **Punto de salida de la
zona** en el mapa. Se guardan `originLat` y `originLon`. El cliente selecciona
esa zona y marca su propio destino. La ruta conecta ambos puntos usando ORS.
El punto de salida no es un polígono ni valida automáticamente la cobertura.
La tarifa continúa siendo la definida en la zona.

## Endpoints

- `GET /checkout-options`: opciones públicas, sin credenciales SMTP.
- `POST /orders/:id/simulation`, JSON `{ "action": "PAY" }` o `SKIP`:
  exige cliente propietario y simulación habilitada.
- `GET /orders/:id/receipt`: boleta y estado del envío, propietario o administrador.
- `GET /orders/:id/receipt/pdf`: PDF con la misma autorización.
- `POST /orders/:id/receipt/send`: envío/reintento al correo registrado del propietario.
- `POST /api/delivery/route`: admite `zoneId` para origen de checkout u `orderId`
  para coordenadas de un pedido propio (también autorizado para administrador).

No se ejecutaron pruebas, compilaciones, la app ni correos de comprobación.
Se instalaron dependencias y se aplicó formato al código. La revisión funcional
y la entrega real por Gmail quedan pendientes de configurar y probar en dispositivo.
