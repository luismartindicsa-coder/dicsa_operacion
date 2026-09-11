# Revisión antes de cerrar Prenómina

Al pulsar **Cerrar periodo**, los bloqueos se muestran en un diálogo **Pendientes para cerrar**, con nombre, ID, empresa y estado de cada colaborador. La revisión corresponde al periodo completo, independientemente de los filtros del grid. Los sobres conservan su exportación filtrada.

El diálogo reúne los préstamos desactualizados y las publicaciones pendientes en una sola lista. Los préstamos muestran los importes guardados frente a los actuales: cuotas y vencidos, cobro en Flujo, cobro fiscal ya incluido en CONTPAQ y pendiente de cobro, además de sus folios. Se mantiene la comparación de préstamos que ya impedía cerrar; incluye abonos que eliminan una cuota previamente guardada.

Para publicar, RH puede elegir **Publicado** desde el estado interactivo de la tabla y confirmar la publicación, después de validar los importes. Sigue disponible la ruta del detalle: **Notas → Estatus → Publicado → Guardar y publicar**. Cuando corresponde, también se señalan los días de asistencia en revisión o los permisos pendientes. Estas indicaciones orientan la revisión y no agregan descuentos ni nuevas reglas de publicación.

El selector de **Estado** incluye Borrador, Revisión RH, Listo y Publicado. Guarda con el mismo proceso del detalle, conserva sus conceptos y notas y actualiza los filtros. En periodos cerrados queda deshabilitado. Mientras guarda evita cambios simultáneos; cancelar la confirmación de publicación no guarda. Si hay asistencia pendiente, se conserva la regla que muestra Revisión RH aunque RH haya elegido Listo y se explica en el aviso de guardado. La primera publicación sigue liquidando los eventos de vacaciones y permisos del colaborador.

El buscador tiene foco al abrir. Los filtros del diálogo permiten ver sólo préstamos o publicaciones pendientes. **Revisar** abre Descuentos, Asistencia, Vacaciones y permisos o Notas según el pendiente, incluso cuando el colaborador está oculto por los filtros de la tabla. El filtro de la tabla se conserva. Después de guardar o cancelar el detalle, se vuelve a construir la lista; cuando ya no hay bloqueos, se muestra la confirmación de cierre existente.

El diálogo no guarda ni publica por sí solo. Ante un fallo al consultar préstamos, explica que hay que volver a abrir Prenómina y deshabilita las acciones de edición. Cerrar la revisión o presionar Escape deja el periodo abierto. El cierre final y su confirmación conservan el flujo de persistencia existente.

Validación con datos sintéticos: comparación de cuotas y abonos, borradores sin guardar, publicación, guías de asistencia y permisos, apertura de un colaborador oculto, conservación de filtros, búsqueda con foco, Escape, ventana compacta y confirmación final sin bloqueos. Las pruebas sustituyen únicamente la persistencia y las consultas externas; no cierran periodos reales.
