# Publicar sistema_ventas

El repositorio Git se prepara desde la raíz `sistema_ventas`, con backend y
frontend como carpetas normales, sin submódulos. Se recomienda un repositorio
privado mientras se desarrolla.

1. Crear un repositorio vacío en GitHub, GitLab o el proveedor elegido. No añadir
   README, licencia ni `.gitignore` desde su formulario para evitar historias
   iniciales distintas.
2. En una terminal, entrar en la raíz de `sistema_ventas`.
3. Revisar lo que se va a publicar y crear el primer commit:

```powershell
git status
git diff --cached --stat
git commit -m "Preparar sistema de ventas SneakerStore"
```

Si Git solicita identidad, configurarla para este repositorio con tus datos:

```powershell
git config user.name "Tu nombre"
git config user.email "Tu correo de Git o dirección privada del proveedor"
```

Volver a ejecutar el commit si la identidad no estaba configurada. Después,
sustituir la URL siguiente por la del repositorio creado:

```powershell
git remote add origin https://github.com/TU_USUARIO/sistema_ventas.git
git push -u origin main
```

Si modificaste archivos después de la preparación, ejecutar `git add .` y revisar
`git diff --cached --stat` antes del commit. La autenticación la gestiona Git o el
proveedor; no guardar tokens dentro de la URL ni del código.

## Archivos excluidos

- `.env` y variantes locales; se incluye `.env.example` sin credenciales.
- Cuenta de servicio de Firebase y claves privadas o de firma Android.
- `node_modules`, `dist`, `build`, cachés y registros Firebase/Flutter.
- Configuración local del SDK Android, editor e instaladores APK/AAB.

Estos archivos permanecen en la computadora. Tras clonar en otro equipo hay que
restaurar las credenciales por un canal privado y reinstalar dependencias.
La configuración pública cliente de Firebase se conserva para la app actual.
No se incluye una licencia de distribución del código: definirla antes de
autorizar su reutilización por terceros; los recursos mantienen sus licencias.

Subir código a Git no aloja el backend: el despliegue en un servidor es un paso
posterior, con sus secretos configurados fuera del repositorio.
