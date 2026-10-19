# Probar productos e inventario en Swagger

## Arranque

Desde `snakerstore_backend`:

```powershell
pnpm install --frozen-lockfile
pnpm start:dev
```

Abrir http://localhost:3000/docs (si PORT es diferente, sustituir 3000).
El contrato OpenAPI está en `/docs-json`.
La documentación no requiere sesión; las operaciones administrativas sí.
Swagger no conserva la autorización al recargar.

Las escrituras desde Swagger usan tu Firebase configurado y guardan datos reales.
Las pruebas automatizadas, en cambio, usan dobles de Firebase y no modifican esos datos.

## Obtener un ID token de Firebase

Swagger autoriza solicitudes pero no inicia sesión por sí mismo. Usar una cuenta
ya existente en Firebase Authentication y, para administrar, su documento
`users/{uid}` con `role: ADMINISTRADOR`. No modificar el administrador existente.

Mientras no haya frontend Flutter, se puede obtener un ID token desde Postman:

1. En la configuración del proyecto Firebase, localizar la clave API web del proyecto.
   Esta clave cliente es distinta de la clave privada de la cuenta de servicio.
2. Crear una solicitud POST a
   `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=TU_CLAVE_API_WEB`.
3. En Body seleccionar raw / JSON y escribir localmente los datos de tu cuenta:

   ```json
   {
     "email": "TU_CORREO",
     "password": "TU_CONTRASEÑA",
     "returnSecureToken": true
   }
   ```

4. Copiar localmente el campo `idToken` de la respuesta. No usar `refreshToken`,
   `localId`, ni un token personalizado Admin. No compartir el token ni guardarlo en Git.
5. En Swagger pulsar **Authorize**, pegar solamente el ID token, sin `Bearer `,
   pulsar Authorize y cerrar la ventana.
6. Ejecutar `GET /auth/me`: debe responder 200 y mostrar el rol esperado.

No compartir credenciales por chat ni guardar la solicitud con contraseñas en
colecciones compartidas de Postman. Al expirar o revocarse el token, iniciar sesión
de nuevo y actualizar Authorize. No usar contraseñas en comandos del terminal.

Referencia oficial del inicio de sesión REST:
https://firebase.google.com/docs/reference/rest/auth#section-sign-in-email-password

## Secuencia de prueba

Expandir cada operación y pulsar **Try it out**, completar los campos y **Execute**.

1. `GET /products`: funciona sin autenticación y devuelve solo productos activos.
   Respuesta paginada: `{ "items": [], "nextCursor": null }`. `limit` admite 1–100.
   Para otra página, usar `nextCursor` como `after`. El orden es por ID, no por fecha.
2. `POST /admin/products` con este cuerpo; respuesta esperada: 201. Guardar su `id`:

   ```json
   {
     "name": "Zapatilla urbana de prueba",
     "description": "Producto de prueba creado desde Swagger",
     "priceCents": 25990,
     "category": "Urbano",
     "brand": "SneakerStore",
     "active": true
   }
   ```

   `25990` representa S/ 259.90. Las imágenes empiezan vacías; adjuntarlas con
   `POST /admin/products/{id}/images`, campo multipart `files`.
   Consultar `CLOUDINARY_SETUP.md`. No enviar URLs ni campos `images` en este JSON.
3. `GET /products/{id}`: devuelve el producto activo (200).
4. `PATCH /admin/products/{id}` con `{ "priceCents": 24990 }`: actualiza el precio (200).
5. `POST /admin/inventory` con el ID real del producto (201):

   ```json
   {
     "productId": "ID_DEL_PRODUCTO",
     "size": "40",
     "quantity": 10,
     "reason": "Ingreso inicial de almacén"
   }
   ```

   Guardar el `id` del inventario devuelto, de forma `ID_DEL_PRODUCTO_40`.
   Repetir la creación de la misma talla devuelve 409; para cambiar stock usar PATCH.
6. `PATCH /admin/inventory/{id}` con
   `{ "delta": 5, "reason": "Reposición de almacén" }`: deja available en 15.
   `delta: -3` resta tres unidades. `reserved` no puede modificarse desde este endpoint.
   Cada ajuste es una operación nueva: no repetir una solicitud exitosa por error.
7. `GET /admin/inventory?productId=ID_DEL_PRODUCTO`: consulta tallas y cantidades.
8. `GET /admin/inventory/movements?inventoryId=ID_DEL_INVENTARIO`: consulta auditoría
   con motivo, actor, cantidades antes/después y fecha. El orden es por ID, no por fecha.
9. `DELETE /admin/products/{id}`: desactiva, conservando inventario e historial.
   El detalle público pasa a 404. El producto sigue visible en `/admin/products`.
   Se puede reactivar con PATCH y `{ "active": true }`.

## Errores que conviene comprobar

| Prueba | Resultado |
|---|---|
| Ruta administrativa sin token | 401 |
| Ruta administrativa con cuenta CLIENTE | 403 |
| Precio negativo, decimal o string | 400 |
| Campo desconocido, `reserved` o actor enviado en body | 400 |
| PATCH de producto vacío o campo obligatorio null | 400 |
| Ajuste delta cero o decimal | 400 |
| Restar más unidades que available | 409 y sin movimiento |
| Producto inexistente o inactivo en catálogo público | 404 |

## Consultas e índices

Las consultas actuales usan paginación por `FieldPath.documentId()` y, como máximo,
un filtro de igualdad: `products.active`, `inventory.productId` o
`inventory_movements.inventoryId`. Usan los índices automáticos de campo único
con `__name__` ascendente de Firestore. No requieren índices compuestos adicionales
con la configuración estándar. No se han cambiado índices ni reglas de Firebase.
No hay búsqueda de texto, orden cronológico ni filtros combinados en esta fase.

## Verificaciones y alcance

```powershell
pnpm build
pnpm lint
pnpm test
pnpm test:e2e
```

Las pruebas cubren validación HTTP real, autorización, contratos Swagger,
visibilidad de productos, paginación y operaciones transaccionales con Firestore
simulado. No validan concurrencia contra el emulador ni realizan escrituras en el
proyecto real. Las pruebas adicionales con Emulator Suite están disponibles en
`pnpm test:integration`, explicadas en `ORDERS_PAYMENTS_GUIDE.md`.
Los ajustes leen stock y registran el movimiento dentro de la misma transacción
Firestore; los reintentos internos no realizan llamadas externas.

Cloudinary para imágenes de catálogo está integrado (ver `CLOUDINARY_SETUP.md`).
Las zonas de delivery y la configuración de tienda también están implementadas
(ver `DELIVERY_STORE_GUIDE.md`). Pedidos con reservas y pagos están implementados
y documentados en `ORDERS_PAYMENTS_GUIDE.md`.
La recuperación de contraseña permanece en el flujo
Firebase Auth del futuro frontend Flutter, documentado en `AUTHENTICATION.md`.
