# Modelos 3D opcionales

## Uso

1. Guardar el producto en administración.
2. En su editor, abrir **Modelo 3D (opcional)** y **Subir modelo 3D**.
3. Elegir un `.glb` versión 2.0, de hasta **10 MiB**, con geometría y texturas
   incluidas en el archivo y sin recursos externos.
4. El catálogo y la ficha lo muestran primero. La ficha permite girar y acercar;
   las fotografías siguen disponibles desde las miniaturas.
5. **Reemplazar** cambia el modelo; **Quitar** devuelve la prioridad a las fotos.

El modelo es opcional y no modifica precio, stock ni fotos. No convierte fotos
en 3D. Exportar desde una herramienta de modelado como glTF Binary con recursos
incluidos. Optimizar mallas y texturas para teléfonos; el tamaño permitido no
garantiza buen rendimiento para cualquier modelo o dispositivo.

## API y almacenamiento

- `POST /admin/products/:id/model`, multipart con campo archivo `file`.
- `DELETE /admin/products/:id/model`.
- Ambos requieren sesión de administrador.
- Se validan extensión, tamaño, firma, versión GLB, longitud y chunks JSON/BIN,
  mallas y buffer interno. Las texturas deben usar bufferViews, sin URI externas.
  Es una validación estructural, no una revisión gráfica completa.
- Se almacena como recurso `raw` en Cloudinary con nombre único terminado en
  `.glb`, utilizando las credenciales existentes únicamente en el backend.
- Firestore guarda `products.model3d`: URL, ID del recurso, formato y tamaño.
  La API pública devuelve URL HTTPS, formato y tamaño, sin el ID del recurso.
  Los productos anteriores devuelven `model3d: null`, sin migración.
- Se intenta limpiar el modelo anterior después de reemplazar o quitar. Si una
  escritura tiene un resultado incierto por un error de red, se conserva el
  recurso nuevo y se registra una advertencia para reconciliarlo manualmente.
- Verificar que la cuenta Cloudinary permita carga y entrega de recursos raw.
  Se aplican sus cuotas de almacenamiento y tráfico. No se generan renders ni
  transformaciones del archivo: el visor descarga el GLB.

## App Android

Se incorporaron `model_viewer_plus` y `file_picker`; se requiere Android API 24
o la mínima de Flutter si es mayor. Hay que volver a ejecutar/instalar la app:
hot reload no incorpora plugins nuevos. Mantener Android System WebView actualizado.
El visor usa WebGL en un WebView con servidor local interno. La configuración
permite HTTP solo para localhost/127.0.0.1, también usados por adb reverse;
los modelos remotos se descargan por HTTPS.

El catálogo muestra el modelo sin capturar los toques de la tarjeta. La ficha y
el editor permiten interacción. Carrito y miniaturas administrativas mantienen
fotos para evitar visores pequeños adicionales. Solo se monta el visor mientras
su área es visible, mediante `visibility_detector`, para no abrir todos los
modelos de una página simultáneamente. Si falla el modelo o tarda más
de 60 segundos, se muestra una foto alternativa o un icono; ficha y editor
permiten reintentar. Sin modelo se conserva el comportamiento fotográfico.

Esta integración se orienta al proyecto Android existente. No añade plataformas
web/iOS, colocación con la cámara ni prueba virtual sobre el pie: es un visor 3D.

## Referencias

- [Visor y requisitos](https://pub.dev/packages/model_viewer_plus).
- [Selector de archivos](https://pub.dev/packages/file_picker).
- [Cloudinary: cargas y tipos de recursos](https://cloudinary.com/documentation/upload_images).

Se instalaron dependencias y se aplicó formato. No se ejecutaron pruebas,
compilaciones, la app ni cargas a Cloudinary. La revisión funcional en el
dispositivo queda pendiente.
