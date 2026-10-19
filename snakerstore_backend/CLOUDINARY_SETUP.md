# Imágenes de productos

El backend usa el SDK Cloudinary ya instalado y las variables existentes
`CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` y `CLOUDINARY_API_SECRET`.
Las tres deben estar presentes sin espacios, o deben omitirse todas para arrancar
sin cargas de imágenes. No se cambiaron `.env`, credenciales ni configuración Firebase.

## Cargar desde Swagger

1. Ejecutar `pnpm start:dev` desde `snakerstore_backend`.
2. Abrir http://localhost:3000/docs (usar PORT si es distinto).
3. En Authorize pegar un ID token Firebase de un ADMINISTRADOR.
4. Crear un producto con `POST /admin/products` o copiar el ID de uno existente
   desde `GET /admin/products`.
5. Abrir `POST /admin/products/{id}/images` y pulsar Try it out.
6. Completar `id` y seleccionar las fotos en el campo multipart **files**.
7. Pulsar Execute. La respuesta esperada es 201 con el producto y sus imágenes.
8. Consultar `GET /products/{id}` para ver las URLs públicas si el producto está activo.

Se admiten 1–5 imágenes por solicitud y 10 por producto; cada archivo puede pesar
hasta 5 MiB. Formatos: JPEG (.jpg o .jpeg), PNG y WebP. La extensión, el MIME
declarado y la firma del contenido deben coincidir. Cloudinary además debe poder
decodificar el archivo. No se admiten SVG, GIF, documentos o videos.

Las fotos se agregan a las existentes. No enviar JSON, URLs, claves ni `public_id`.
La carga usa multipart/form-data; Swagger construye este cuerpo automáticamente.
Los archivos se procesan en memoria con límites antes de subirse, sin escribirlos en disco.

## Persistencia y fallos

Cloudinary guarda el archivo público en `sneakerstore/products/{productId}/...`.
Firestore guarda `secure_url` y `public_id` en `products.images`, con actualización
de actor y timestamp. Las respuestas de catálogo exponen solo `secure_url`.
Los límites se revisan nuevamente dentro de la transacción para cargas concurrentes.

Si falla una carga múltiple, se intenta eliminar las imágenes anteriores de esa
solicitud. Si Firestore rechaza por validación, se intenta compensar las subidas.
Si falla una limpieza, se registra una advertencia sin credenciales.
Ante un error de red de Firestore con resultado incierto, se conservan las fotos:
revisar las referencias del producto y los recursos de Cloudinary antes de reintentar.
Una subida interrumpida también puede requerir revisión manual de recursos huérfanos.
No existe todavía un proceso automático de reconciliación.

Esta entrega agrega fotos; no implementa reemplazo o eliminación manual de fotos.
Los comprobantes privados de pago están fuera de esta integración de catálogo.

## Estado de verificación

Se verificó compilación con `pnpm build`. Por solicitud del usuario no se ejecutaron
pruebas automatizadas, llamadas al endpoint ni operaciones contra Cloudinary/Firebase.
La validación real de credenciales y carga queda a cargo del usuario desde Swagger.

Documentación oficial: https://cloudinary.com/documentation/node_image_and_video_upload
