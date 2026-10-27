# Probador visual con cámara

## Dos artículos incluidos

Al iniciar NestJS se crean, mediante una transacción, `demo-urban-sand` y
`demo-sport-night` si todavía no existen. No se sobrescriben cambios del
administrador y no se crean existencias ficticias. Los precios son de
demostración. Agregar tallas y stock real desde Inventario antes de venderlos.

Los dos GLB originales están incluidos en `assets/try_on/models/`; no necesitan
Cloudinary ni archivos de un proveedor. Se generan con
`python snakerstore_frontend/tool/generate_try_on_models.py`.
Son diseños de demostración, no reproducciones de zapatillas de una marca.

## Cliente

Catálogo → Urban Sand o Sport Night → Probar con cámara → Activar cámara.
Al abrir la cámara aparecen ambas zapatillas en modo manual. Arrastrar cada
una sobre el pie usando el selector Izquierda/Derecha. Los controles X/Y,
tamaño, giro e inclinación afectan únicamente a la zapatilla seleccionada.
El arrastre conserva el punto de agarre. «Congelar cámara» pausa la imagen
local para facilitar el ajuste; «Reanudar cámara» recupera la imagen en vivo.
«Recentrar ambas» recupera los modelos si quedan fuera de la zona visible.
«Voltear modelo» gira 180° únicamente la zapatilla seleccionada cuando el GLB
está orientado al revés y muestra la suela. La inclinación admite una vuelta
completa. Posición e inclinación están en un panel desplegable para mantener
tamaño y giro accesibles. La iluminación usa mapeo tonal ACES y menor luz
ambiental para conservar el relieve de superficies blancas; esto no agrega
texturas que falten en el archivo original.
El botón «Activar tracking automático (experimental)» permite intentar la detección:
usar la cámara trasera y encuadrar los pies, tobillos y parte de las piernas.
MediaPipe Pose estima tobillo, talón y punta; no es un detector especializado
de pies en primer plano. La superposición de ambos modelos es experimental,
sin oclusión ni reconstrucción de profundidad. Al perder confianza se conserva
la última posición visible. Desactivar el tracking mantiene esa posición para
continuar el ajuste manual. La escala es una aproximación visual, no una
medición ni recomendación de talla.

Si no hay detección durante seis segundos (incluida la carga del detector),
se vuelve automáticamente al modo manual con ambos modelos visibles.
También se puede seleccionar Ajustar manualmente en cualquier momento.
Los controles permiten ajustar cada zapatilla por separado. Este modo es manual,
no seguimiento automático. Volver al producto para elegir talla y comprar.

## Agregar más modelos

1. Crear o editar un producto y guardarlo.
2. Subir un GLB 2.0 autocontenido, máximo 10 MiB, desde Modelo 3D.
3. Revisar el visor. El modelo debe contener **una zapatilla**, punta hacia +Z,
   parte superior hacia +Y y longitud predominante en Z. Evitar nodos, cámaras
   o geometría ajenos al calzado. El probador centra y normaliza su longitud.
4. Activar Disponible para probar con cámara y pulsar Guardar.
5. Revisar el resultado en un Android real como cliente.

El otro pie usa una copia reflejada: letras y detalles asimétricos también se
reflejan. Un producto que necesite izquierda/derecha distintas requiere ampliar
el contrato de modelos. Reemplazar o quitar el GLB desactiva el probador hasta
volver a revisarlo. En los artículos incluidos, quitar un GLB subido recupera
el recurso de fábrica, sin habilitar automáticamente el probador.

## Implementación y privacidad

Flutter abre una WebView con un servidor de recursos en 127.0.0.1 y puerto
aleatorio. La ruta contiene una capacidad aleatoria y únicamente sirve una
lista cerrada de archivos de la app. Three.js 0.170.0 y MediaPipe Tasks Vision
0.10.22-rc.20250304, WebAssembly y Pose Landmarker Lite están empaquetados.
No se envían imágenes al backend ni se graba video. Los modelos subidos se
descargan de su URL HTTPS; los dos incluidos funcionan sin descargas adicionales
después de cargar el catálogo. No se solicitan permisos de micrófono.

La cámara se activa por acción del usuario; se detiene al salir o pasar a
segundo plano. Al regresar debe reanudarse. Android es la plataforma inicial.
No se añade un requisito de ARCore porque esta versión realiza superposición
3D con seguimiento de pose, no anclaje espacial de ARCore.

Licencias de Three.js (MIT) y MediaPipe (Apache 2.0) incluidas en vendor.
Modelo: https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task
Referencias: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js

## Verificación

- `node --test snakerstore_frontend/tool/tracking.test.mjs`
- En frontend: `flutter analyze` y `flutter test`.
- En backend: `pnpm build` y `pnpm test`.
- En Android físico: permitir/denegar cámara, ambos pies, un pie, pérdida de
  detección, fondo oscuro, retorno de segundo plano, salir y volver a entrar,
  ajuste manual y nuevo GLB. La calidad y FPS requieren esta prueba física.

### Estado de verificación en este equipo

Los dos GLB cargan con GLTFLoader, las pruebas de seguimiento y recursos del
probador pasan, y el backend compila. No hay SDK Android configurado en este
equipo; la compilación de APK y validación del permiso nativo y seguimiento
con cámara física quedan pendientes. No considerar esta versión como una
experiencia de prueba virtual de producción hasta completar esa validación.

Resultado de suites: 42/42 pruebas unitarias del backend; 56/57 pruebas HTTP
(falla la expectativa de rechazo de un dato de inventario); 26 pruebas Flutter
aprobadas, 3 fallidas en login/menú y 1 omitida. Las tres pruebas nuevas del
probador y las tres pruebas JavaScript de seguimiento pasan. Los fallos de
las suites generales siguen pendientes; no se reporta una suite global verde.
