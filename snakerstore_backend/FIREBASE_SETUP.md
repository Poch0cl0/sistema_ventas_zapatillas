# Configuración local de Firebase

Ejecutar los comandos desde `snakerstore_backend` con Node.js 24 y pnpm.
Las dependencias `@nestjs/config` y `firebase-admin` ya están instaladas.

Conservar el `.env` existente. `.env.example` documenta los nombres sin secretos:

- `PORT`: entero entre 1 y 65535; predeterminado 3000.
- `FIREBASE_PROJECT_ID`: debe corresponder al proyecto SneakerStore.
- `FIREBASE_SERVICE_ACCOUNT`: ruta al JSON local existente. Las rutas relativas se resuelven desde el directorio de ejecución, no desde `dist`.

`ConfigModule` carga y valida las variables al arrancar. `FirebaseModule` exporta
los tokens `FIREBASE_APP`, `FIREBASE_AUTH` y `FIREBASE_FIRESTORE`. Los servicios
pueden inyectarlos con `@Inject(TOKEN)` y tipos importados mediante `import type`.
Se reutiliza la aplicación Admin predeterminada si pertenece al proyecto correcto.
No se crean usuarios, colecciones ni documentos durante el arranque.

Comandos:

```sh
pnpm build
pnpm lint
pnpm test
pnpm test:e2e
pnpm start:dev
```

Las pruebas automatizadas usan dobles de Firebase y no necesitan credenciales reales.
Inicializar el SDK valida la configuración local, pero no demuestra conectividad ni
permisos remotos. El backend expone `GET /auth/me` con autenticación y roles;
los módulos de negocio incluyen catálogo, inventario, delivery, pedidos y pagos.
El SDK Admin omite las reglas
Firestore: cada operación de negocio debe aplicar sus permisos en NestJS.

Nunca versionar `.env` ni cuentas de servicio. No regenerar las credenciales existentes.
La autenticación, los perfiles, los roles y `GET /auth/me` se documentan en
`AUTHENTICATION.md`. La validación global, Swagger, el catálogo y el inventario
están implementados: consultar `SWAGGER_GUIDE.md` para probarlos.
Cloudinary está integrado para agregar imágenes de productos; consultar
`CLOUDINARY_SETUP.md`. Las zonas de delivery y ajustes de tienda están documentados
en `DELIVERY_STORE_GUIDE.md`. Pedidos, reservas y pagos se documentan en
`ORDERS_PAYMENTS_GUIDE.md`, incluidas las pruebas con emuladores y el procesamiento manual de vencimientos.
