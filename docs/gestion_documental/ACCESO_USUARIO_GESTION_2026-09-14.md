# Acceso del usuario de Gestión Documental

La cuenta existente `gestion@dicsamx.com` tiene correo confirmado en Supabase y ahora cuenta con perfil activo de rol `gestion_documental`. Su UUID existente se conserva; no se crea otro usuario ni se modifica contraseña, confirmación del correo o sesión.

Al iniciar sesión, `AuthAccess.routeKeyForProfile` devuelve `gestion_documental_dashboard` y `RoleRouter` abre `GestionDocumentalDashboardPage`. La asignación depende del rol activo leído de `profiles`, no de un acceso concedido únicamente por el correo. El menú documental no muestra el retorno a Dirección para este rol. Los destinos existentes de Dirección, administración, Operación y Logística se conservan.

La migración `20260914220000_enable_gestion_documental_role.sql` está aplicada y registrada en el proyecto enlazado. Amplía el catálogo de roles preservando sus ocho valores anteriores, agrega `gestion_documental` a `documental_can_manage()` y asigna ese rol únicamente a la cuenta indicada. Las RPC y políticas de los expedientes y del bucket privado ya utilizan esta función; el usuario puede trabajar en las dos categorías habilitadas y aparece entre los responsables existentes.

Verificación realizada:

- 16 pruebas Flutter aprobadas, incluidas tres de acceso por rol y una que resuelve una sesión simulada hasta el dashboard y revisa el menú sin Dirección.
- PostgreSQL aislado: asignación del perfil, consulta y edición de Legal y Trámites, auditoría del nuevo actor, acceso a archivos, limpieza de cargas propias y denegación al desactivar el perfil. Continúan pasando las pruebas documentales previas.
- Supabase remoto: contenido de migración idéntico al local y perfil confirmado. Bajo el rol SQL `authenticated` y el UUID del usuario se verificaron lectura del propio perfil, contexto, responsable, guardado/consulta/detalle en ambas categorías y políticas de inserción/lectura de Storage dentro de una transacción con rollback. No quedaron registros ni objetos de prueba. El borrado de objetos reales debe continuar usando la API de Storage.
- Análisis Dart sin incidencias y compilación macOS aprobada. Se envió la recarga a la sesión local de Flutter.

No se realizó un inicio de sesión real con la contraseña de esta cuenta; se verificó el enrutamiento con una sesión simulada y la autorización efectiva directamente en Supabase. Las políticas generales preexistentes de otras áreas y de `profiles` no se modificaron en esta entrega.
