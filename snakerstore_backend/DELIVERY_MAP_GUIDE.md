# Mapa y rutas de entrega

Implementación conectada a Flutter para Android. La clave ORS se usa exclusivamente
en NestJS. La instalación de dependencias se realizó sin ejecutar pruebas,
análisis, compilaciones, la app ni solicitudes reales al proveedor de rutas.

## Configuración del backend

Mantener en `.env` (no versionado):

```dotenv
ORS_API_KEY=tu_clave_real
ORS_BASE_URL=https://api.heigit.org
ORS_STORE_LAT=latitud_real_de_la_tienda
ORS_STORE_LON=longitud_real_de_la_tienda
```

Las cuatro variables existentes no fueron sobrescritas. Los ejemplos de Madrid
en `.env.example` deben sustituirse por la ubicación real. Latitud: -90 a 90;
longitud: -180 a 180. El servicio rechaza un host ORS diferente al oficial para
evitar enviar la clave a otro destino. Reiniciar NestJS tras modificar `.env`.

## Contrato

Ambos endpoints exigen la sesión Firebase habitual:

- `GET /api/delivery/config`: devuelve `store: {lat, lon}`, `profile`,
  `routingEnabled`, `tileUrl` y `tileAttribution`. No devuelve claves.
- `POST /api/delivery/route`: recibe `{clientLat: number, clientLon: number}`.
  Responde `{geometry: {type: "LineString", coordinates: [[lon, lat], ...]},
  distance: number, duration: number}`. Distancia en metros y duración en segundos.

NestJS envía `Authorization: <ORS_API_KEY>` sin Bearer a
`https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson`.
El cuerpo usa `[[storeLon, storeLat], [clientLon, clientLat]]`.
Nunca acepta claves, origen ni URL del proveedor desde Flutter.

El proxy maneja límites (429), autorización del proveedor (401/403), puntos sin
ruta y fallos de red. Timeout: 15 segundos; máximo 8 consultas concurrentes y
12 solicitudes por usuario por minuto, por proceso NestJS. Caché temporal en
memoria de hasta 100 rutas durante 5 minutos. Un despliegue con múltiples
instancias requerirá límites compartidos. No se registran errores Axios que
puedan contener headers con credenciales.

## Flujo de compra

En checkout, elegir zona y pulsar **Seleccionar ubicación en el mapa**. El mapa
intenta obtener el GPS, permitiendo tocar el mapa si no hay permiso, servicio
de ubicación o señal. Se puede recalcular y confirmar el punto sin depender de
que ORS esté disponible. La ruta se consulta solo al pulsar **Calcular ruta**.

La dirección escrita es opcional cuando existe el pin; piso, departamento y
referencia siguen disponibles. El pedido conserva `delivery.clientLat` y
`delivery.clientLon`. El backend admite también pedidos anteriores con dirección
escrita sin coordenadas; exige coordenadas numéricas válidas y completas cuando
se envía una de ellas. PICKUP no admite coordenadas de cliente.

Cliente y administrador pueden abrir el destino guardado y calcular su ruta.
Los pedidos antiguos sin coordenadas muestran su dirección habitual. Las rutas
usan el punto de salida de la zona seleccionada por el administrador. Los
pedidos nuevos guardan `originLat/originLon` y `clientLat/clientLon`; al consultar
una ruta con `orderId`, NestJS comprueba la propiedad y usa ese snapshot. Las
zonas y pedidos antiguos sin origen usan las coordenadas globales de la tienda.
No se guarda la geometría histórica en Firestore.

El perfil `driving-car` es una aproximación de automóvil, no un perfil específico
de moto. La duración no incluye preparación ni garantiza el plazo de entrega.
La tarifa sigue siendo la de la zona elegida, no se calcula por kilómetros.
La selección del pin no verifica automáticamente la cobertura geográfica de
la zona. No hay seguimiento del repartidor ni búsqueda de direcciones.

## Mapa base

OpenStreetMap con `flutter_map`, atribución visible e identificación de la app,
sin descargas de mapas offline ni precarga de áreas. Se usa la caché integrada
de flutter_map 8.3.2, que respeta headers HTTP. El proveedor se puede cambiar
desde el backend sin recompilar el cliente mediante:

```dotenv
MAP_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
MAP_TILE_ATTRIBUTION=© OpenStreetMap contributors · openstreetmap.org/copyright
```

El servicio público de OSM tiene capacidad limitada y no garantiza disponibilidad.
Para crecimiento comercial, elegir un proveedor apropiado y actualizar ambas
variables. No colocar claves secretas en el URL del mapa enviado a Flutter.

Se agregaron permisos Android de ubicación aproximada y precisa, solo para
obtener una posición mientras se usa la pantalla. El repositorio no tiene
proyecto iOS; no se creó un Info.plist suelto ni un proyecto iOS incompleto.

## Revisión pendiente en dispositivo

Reiniciar backend e instalar de nuevo la app para incluir el nuevo plugin y los
permisos. Comprobar GPS permitido/denegado, selección manual, ruta, confirmación,
pedido y visualización administrativa; también el comportamiento con ORS sin
acceso o sin conexión. Estas comprobaciones no se ejecutaron.

Referencias:
- https://ask.openrouteservice.org/t/deprecating-api-openrouteservice-org-in-favour-of-api-heigit-org/7912
- https://operations.osmfoundation.org/policies/tiles/
- https://pub.dev/packages/flutter_map
- https://pub.dev/packages/geolocator
