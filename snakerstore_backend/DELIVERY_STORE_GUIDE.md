# Delivery y configuración de tienda en Swagger

Este incremento incorpora zonas, tarifas, datos de recojo y métodos de pago
informativos. Los pedidos, reservas y pagos están implementados y documentados en
`ORDERS_PAYMENTS_GUIDE.md`. Este módulo no requiere variables adicionales.

## Empezar

Desde `snakerstore_backend`, ejecutar `pnpm start:dev` y abrir
http://localhost:3000/docs (sustituir el puerto si PORT es distinto).
Autorizar con el ID token del administrador para las rutas `/admin/...`.
Cada operación tiene Try it out y ejemplos de sus campos.

## Zonas de delivery

1. Ejecutar `POST /admin/delivery-zones` con:

   ```json
   {
     "name": "Zona centro",
     "feeCents": 800,
     "active": true
   }
   ```

   Respuesta esperada: 201 con el `id`. `800` equivale a S/ 8.00.
   Usar tarifas enteras, entre 0 y 1000000 céntimos.
2. `GET /delivery-zones` muestra solo las zonas activas, sin iniciar sesión.
3. `GET /admin/delivery-zones` muestra activas e inactivas al administrador.
4. Cambiar la tarifa con `PATCH /admin/delivery-zones/{id}`:

   ```json
   { "feeCents": 1000 }
   ```

5. `DELETE /admin/delivery-zones/{id}` desactiva la zona conservando el documento.
   Reactivarla con PATCH y `{ "active": true }`.

Los listados aceptan `limit` (1–100) y `after`, con respuesta
`{ "items": [], "nextCursor": null }`. El orden es por ID. El filtro de zona activa
usa el índice automático de `active` con `__name__` ascendente de Firestore.
No se han cambiado reglas ni índices remotos. No se calculan distancias ni GPS.

## Configuración de tienda

La configuración se guarda en `store_settings/main`. Si el documento aún no existe,
los GET responden 404; crearlo con `PUT /admin/store-settings`.

Este PUT requiere todos los campos editables: reemplaza la información completa
de recojo y la lista de métodos, no realiza una edición parcial. Para editar,
consultar primero `GET /admin/store-settings`, cambiar lo necesario y enviar el
cuerpo completo sin el campo de respuesta `currency`.

Ejemplo de estructura; sustituir la dirección y los datos de cobro antes de guardar:

```json
{
  "storeName": "SneakerStore",
  "pickup": {
    "enabled": true,
    "address": "Dirección real de tu tienda",
    "instructions": "Presentar el número del pedido al recoger.",
    "openingHours": "Lunes a sábado, 10:00 a 19:00"
  },
  "paymentMethods": [
    {
      "method": "YAPE",
      "enabled": true,
      "holderName": "Titular real de Yape",
      "phone": "900000000"
    },
    {
      "method": "PLIN",
      "enabled": true,
      "holderName": "Titular real de Plin",
      "phone": "900000000"
    },
    {
      "method": "TRANSFERENCIA",
      "enabled": true,
      "holderName": "Titular real de la cuenta",
      "bankName": "Nombre del banco",
      "accountNumber": "00000000000000",
      "cci": "00000000000000000000"
    }
  ],
  "publicNotes": "El pago se verifica manualmente. La reserva del pedido será de 24 horas."
}
```

Los teléfonos y cuentas anteriores son ejemplos, no datos válidos para recibir dinero.
Solo incluir datos de tienda destinados a mostrarse a clientes. No guardar claves
bancarias, PIN, credenciales de APIs, tokens ni contraseñas en estos campos.

Reglas:

- Moneda fija PEN; `currency` se devuelve pero no es editable.
- YAPE y PLIN habilitados requieren teléfono peruano de 9 dígitos iniciado en 9.
- TRANSFERENCIA habilitada requiere banco y número de cuenta (6–30 dígitos).
- CCI es opcional; si se incluye, debe tener 20 dígitos. Los números son strings
  para conservar ceros iniciales.
- No repetir métodos; máximo tres. `paymentMethods: []` deshabilita todos.
- `enabled: false` deshabilita un método. En ese caso se puede omitir su teléfono
  o banco/cuenta, pero si se envían, deben cumplir el formato.
- Los datos de recojo se conservan aunque `pickup.enabled` sea false. El horario
  es informativo y no programa automáticamente apertura o cierre.
- `GET /store-settings` es público y devuelve únicamente métodos habilitados.
  Los datos de recojo y notas también son públicos.
- `GET /admin/store-settings` incluye métodos habilitados y deshabilitados.
- Se guardan actor y fechas del servidor, sin exponerlos en respuestas públicas.
- Esta configuración no verifica fondos ni confirma pagos automáticamente.
- Los textos sobre reservas no implementan su vencimiento: esa lógica corresponde
  al módulo de pedidos y reservas, documentado en `ORDERS_PAYMENTS_GUIDE.md`.

## Respuestas esperadas para tu revisión manual

| Operación | Respuesta esperada |
|---|---|
| Crear zona con administrador | 201 |
| Editar/desactivar zona | 200 |
| Crear/actualizar configuración por PUT | 200 |
| Consultar zonas o configuración pública | 200 |
| Consultar configuración antes de crearla | 404 |
| Ruta administrativa sin token | 401 |
| Ruta administrativa con CLIENTE | 403 |
| Tarifa negativa, decimal, texto o campos desconocidos | 400 |
| PATCH de zona vacío o con null | 400 |
| Métodos duplicados, teléfono inválido o datos incompletos | 400 |
| Editar una zona inexistente | 404 |

## Estado de verificación y siguientes incrementos

Solo se ejecutó `pnpm build`, aprobado. No se ejecutaron pruebas automatizadas,
solicitudes HTTP ni escrituras remotas, por instrucción del usuario. El usuario
realizará la validación funcional desde Swagger y compartirá los resultados.

La integración de este módulo con checkout, reservas, pagos, expiración y logística
se verifica ahora con emuladores; consultar `ORDERS_PAYMENTS_GUIDE.md`.
El alcance actual es local y con vencimiento manual.
Quedan pendientes la privacidad de comprobantes,
actualización de perfil y resúmenes administrativos. La carga actual de Cloudinary
es exclusivamente para fotos públicas de productos.

Referencias: https://docs.nestjs.com/techniques/validation y
https://firebase.google.com/docs/firestore/manage-data/transactions
