/** Inicio y Catálogo*/

Diseña la pantalla de inicio y catálogo público de SneakerStore, una tienda de zapatillas creada para Next.js y Tailwind CSS.

Mantén el sistema visual del proyecto: negro #111111, blanco, gris claro y acento naranja #FF6B35.

Incluye:
- Navbar con logo, Inicio, Catálogo, Iniciar sesión y carrito.
- Hero promocional con fotografía de zapatillas y botón "Explorar catálogo".
- Barra de búsqueda por nombre.
- Filtros por marca, categoría y talla EU.
- Grid responsive de tarjetas con imagen, nombre, marca, precio en soles y disponibilidad.
- Botón "Ver detalles" en cada tarjeta.
- Footer con información de contacto y políticas.

En móvil utiliza navegación inferior con Inicio, Carrito, Pedidos y Perfil.

Diseña también los estados de catálogo vacío, búsqueda sin resultados y carga de productos. El catálogo puede explorarse sin iniciar sesión.

Genera versiones móvil y escritorio, con estética deportiva premium.

/** Detalle de Zapatillas */

Diseña la pantalla de detalle de producto de SneakerStore, conservando exactamente la identidad visual, navbar y footer del proyecto.

Incluye:
- Galería de fotografías del producto con imagen principal y miniaturas.
- Nombre, marca, categoría y descripción.
- Precio destacado en soles.
- Selector de tallas europeas EU: 38, 39, 40, 41, 42, 43.
- Tallas agotadas visualmente deshabilitadas.
- Indicador de disponibilidad de la talla seleccionada.
- Selector de cantidad.
- Botón principal "Agregar al carrito".
- Productos relacionados.

Diseña los estados: talla sin seleccionar, producto agregado correctamente, stock insuficiente y producto agotado.

En móvil coloca un botón de compra visible en la parte inferior. Diseño responsive para Next.js y Tailwind CSS.

/** Carrito de Compras*/

Diseña la pantalla de carrito de SneakerStore para Next.js, siguiendo el diseño maestro.

Incluye:
- Lista de productos con fotografía, nombre, marca, talla EU, precio y cantidad.
- Controles para aumentar y disminuir unidades.
- Botón para eliminar productos.
- Subtotal calculado.
- Mensaje de que el precio y stock se validarán al confirmar.
- Botón "Continuar compra".
- Enlace "Seguir comprando".

Diseña un estado de carrito vacío con ilustración y botón para volver al catálogo.

En escritorio muestra productos a la izquierda y resumen a la derecha. En móvil utiliza tarjetas verticales y resumen inferior.

Si el usuario no ha iniciado sesión, muestra una invitación para autenticarse antes del checkout.

/** Carrito de Compras*/

Diseña la pantalla de carrito de SneakerStore para Next.js, siguiendo el diseño maestro.

Incluye:
- Lista de productos con fotografía, nombre, marca, talla EU, precio y cantidad.
- Controles para aumentar y disminuir unidades.
- Botón para eliminar productos.
- Subtotal calculado.
- Mensaje de que el precio y stock se validarán al confirmar.
- Botón "Continuar compra".
- Enlace "Seguir comprando".

Diseña un estado de carrito vacío con ilustración y botón para volver al catálogo.

En escritorio muestra productos a la izquierda y resumen a la derecha. En móvil utiliza tarjetas verticales y resumen inferior.

Si el usuario no ha iniciado sesión, muestra una invitación para autenticarse antes del checkout.

/** Pagos */

Diseña la pantalla de registro de pago de SneakerStore.

Incluye:
- Número de pedido y total en soles.
- Contador visual del tiempo restante de reserva de 24 horas.
- Pestañas para Yape, Plin y Transferencia bancaria.
- Espacio para QR o datos de la cuenta seleccionada.
- Campo obligatorio "Número o referencia de operación".
- Área opcional para subir imagen del comprobante, con vista previa.
- Botón "Enviar comprobante".
- Mensaje informativo: el administrador verificará manualmente el pago.

Diseña los estados: sin referencia, enviando información, comprobante enviado, pago pendiente de verificación, pago rechazado y reserva vencida.

No muestres un pago como aprobado inmediatamente después de enviar la referencia.

Mantén navbar, estilos y comportamiento responsive del proyecto Next.js.

/** Listado de pedidos*/

Diseña la pantalla "Mis pedidos" de SneakerStore.

Incluye:
- Encabezado con título e introducción.
- Filtros: Todos, Pendientes, Confirmados, En preparación, Entregados y Cancelados.
- Tarjetas de pedidos con número, fecha, productos, total y estado.
- Badges de estado diferenciados visualmente.
- Botón "Ver detalle".
- Acción "Completar pago" para pedidos pendientes cuando corresponda.
- Mensaje de reserva vencida para pedidos cancelados automáticamente.

Diseña el estado sin pedidos y la vista responsive móvil y escritorio.

Conserva la identidad visual, navbar y navegación del rol cliente.

/** Seguimiento del pedido*/

Diseña la pantalla de detalle y seguimiento de un pedido de SneakerStore.

Incluye:
- Número de pedido y fecha.
- Timeline de estados: Confirmado, Preparando, Listo para recojo o En reparto, Entregado.
- Estado de pago independiente del estado de entrega.
- Productos, tallas, cantidades y precios.
- Datos de entrega o recojo.
- Zona y tarifa de delivery si corresponde.
- Total pagado o pendiente.
- Referencia de pago registrada.
- Botón para volver a Mis pedidos.

Incluye estados especiales para pago rechazado, pedido cancelado y reserva vencida.

Utiliza una línea de progreso vertical en móvil y una disposición más amplia en escritorio. Diseño para Next.js y Tailwind CSS.

/** Inicio de Sesión y Registro*/

Diseña las pantallas de inicio de sesión y registro de SneakerStore, manteniendo la identidad visual del proyecto.

Inicio de sesión:
- Correo electrónico.
- Contraseña con opción de mostrar u ocultar.
- Botón "Iniciar sesión".
- Enlace "¿Olvidaste tu contraseña?".
- Enlace para crear una cuenta.

Registro:
- Nombre completo.
- Correo electrónico.
- Contraseña y confirmación.
- Botón "Crear cuenta".

Diseña también la pantalla de recuperación de contraseña por correo electrónico.

Incluye estados de carga, errores de validación, credenciales incorrectas y registro exitoso.

Utiliza Firebase Authentication como referencia funcional, sin implementar su integración.

Diseño responsive con formulario limpio, fotografía lateral de zapatillas en escritorio y diseño compacto en móvil.

/** Perfil*/

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