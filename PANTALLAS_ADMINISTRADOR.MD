/** Dashboard Administrativo*/

Diseña la pantalla de perfil de cliente de SneakerStore.

Incluye:
- Nombre y correo electrónico del usuario.
- Formulario para editar nombre completo y teléfono.
- Botón "Guardar cambios".
- Acceso rápido a Mis pedidos.
- Opción de cerrar sesión.
- Estados de edición, validación y confirmación de cambios.

Utiliza una estructura sencilla con tarjetas, iconos Lucide y navegación consistente con el resto de las pantallas.

Genera versiones responsive móvil y escritorio para Next.js.

/** Lista y Gestión de Productos*/

Diseña la pantalla administrativa de gestión de productos de SneakerStore.

Mantén el sidebar y los componentes del dashboard.

Incluye:
- Título "Productos".
- Botón "Nuevo producto".
- Buscador por nombre.
- Filtros por marca, categoría y estado.
- Tabla con imagen, nombre, marca, precio, estado y acciones.
- Acciones de Ver, Editar y Desactivar.
- Paginación.
- Modal para confirmar la desactivación de un producto.

Diseña estados de tabla vacía, carga y operación exitosa.

En móvil transforma las filas en tarjetas con menú de acciones. Mantén los estilos de Next.js y Tailwind CSS.

/** Crear y editar producto */

Diseña los formularios administrativos de creación y edición de zapatillas de SneakerStore.

Incluye:
- Nombre del producto.
- Marca.
- Categoría.
- Descripción.
- Precio en soles.
- Área para subir múltiples imágenes con vista previa.
- Estado activo o inactivo.
- Sección informativa de tallas disponibles.
- Botones "Guardar producto" y "Cancelar".

Las tallas y cantidades de stock se gestionarán desde el módulo Inventario.

Diseña estados de validación, errores, guardado exitoso y confirmación de salida con cambios sin guardar.

El formulario de edición debe cargar los datos existentes.

Usa el mismo sidebar administrativo, diseño responsive y componentes globales.

/** Crear y Editar Producto*/

Diseña los formularios administrativos de creación y edición de zapatillas de SneakerStore.

Incluye:
- Nombre del producto.
- Marca.
- Categoría.
- Descripción.
- Precio en soles.
- Área para subir múltiples imágenes con vista previa.
- Estado activo o inactivo.
- Sección informativa de tallas disponibles.
- Botones "Guardar producto" y "Cancelar".

Las tallas y cantidades de stock se gestionarán desde el módulo Inventario.

Diseña estados de validación, errores, guardado exitoso y confirmación de salida con cambios sin guardar.

El formulario de edición debe cargar los datos existentes.

Usa el mismo sidebar administrativo, diseño responsive y componentes globales.

/** Gestión de Inventario*/

Diseña la pantalla administrativa de inventario de SneakerStore.

Incluye:
- Buscador de productos.
- Tabla de inventario por producto y talla europea.
- Columnas: Producto, Talla EU, Disponible, Reservado y Existencia total.
- Alertas de stock bajo.
- Botón para agregar talla.
- Acción para ajustar existencias con un modal.
- Formulario de ajuste con cantidad, motivo y confirmación.
- Historial de movimientos del producto seleccionado.

Distingue visualmente el stock disponible del reservado por pedidos online.

Incluye mensajes que indiquen que el stock es compartido entre ventas físicas y online.

Diseña estados de inventario vacío, stock agotado y ajuste exitoso. Diseño responsive y consistente con el panel administrativo.

/** Gestión de Pedidos*/

Diseña la pantalla administrativa de pedidos online de SneakerStore.

Incluye:
- Tabla de pedidos con código, cliente, fecha, total, modalidad de entrega, estado de pago y estado del pedido.
- Buscador por número de pedido.
- Filtros por fecha, estado y tipo de entrega.
- Indicadores de pagos pendientes y reservas próximas a vencer.
- Botón "Ver detalle" por pedido.
- Badges diferenciados para pago pendiente, aprobado, rechazado y pedido cancelado.

Incluye estados vacíos y de carga.

La interfaz debe permitir identificar rápidamente qué pedidos requieren revisión administrativa.

Usa sidebar, diseño responsive y estilos del proyecto.