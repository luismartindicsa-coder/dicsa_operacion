# Gestión Documental: supervisión de viernes

El botón central de viernes de Gestión Documental genera un PDF con datos del área habilitada, en lugar del catálogo genérico. El dashboard documental enlaza al hub de Supervisión por Áreas, siguiendo el patrón de Finanzas y Logística. Conserva el historial y el diálogo de guardado existentes.

## Contenido

- Resumen ejecutivo y cobertura de las 11 categorías.
- Vencimientos, renovaciones y actividades programadas atrasadas, con responsable y siguiente acción capturada.
- Permisos y trámites abiertos: dependencia, prioridad, estatus y avance.
- Cursos y seguridad e higiene: persona, proveedor, estatus y vencimiento.
- Contratos: contraparte, firma, vencimiento y renovación.
- Seguros: aseguradora, sujeto asegurado y vigencias.
- Agenda completa de próximos 30 días.
- Manifiestos registrados en Medio Ambiente, con autorización e instalación.
- Pendientes de incorporación identificados sin representar fuentes inexistentes como valores cero.

## Reglas y fuentes

La primera consulta usa `documental_dashboard`, que valida permisos expresamente y proporciona la fecha de negocio de Ciudad de México. Después se leen todos los expedientes de `documental_records`, ordenados por ID y paginados de 500 en 500; no se usan los filtros, las primeras 50 filas ni las primeras 12 fechas visibles de la pantalla. Se comprueban el total y la unicidad de IDs contra el dashboard. Si faltan datos, cambió el total durante la consulta o falla el acceso, se detiene la exportación. No se requieren migraciones ni cambios de permisos.

El PDF representa el estado consultado al generarse. La semana de lunes a viernes es referencia para la junta, no una reconstrucción histórica ni una medición de altas/cierres semanales. Al generarse en sábado o domingo conserva la referencia del viernes de esa semana y declara la fecha actual del estado.

Solo `Pendiente` y `En proceso` cuentan como activos. Vencido significa fecha anterior al día de negocio; crítico incluye de hoy a 5 días; próximos vencimientos incluye de hoy a 15 días (contiene los críticos). Un expediente sin fecha no se clasifica como incumplimiento. Las diferencias se calculan entre fechas civiles, sin depender de horas o del huso del dispositivo.

La agenda deriva las mismas fechas que el calendario existente: vencimiento e inicio; renovación de contratos/seguros cuando no es `No aplica`; programación y realización de mantenimiento/auditorías. La agenda pendiente excluye realizaciones, incluye hoy hasta hoy +29 días y no genera recurrencias por periodicidad. Un expediente puede producir varias obligaciones distintas. La alerta de programación atrasada se excluye si ya existe realización; su vencimiento documental se sigue evaluando.

Las tablas incluyen todas las filas y repiten encabezados por bloque. Los textos muy extensos se abrevian con puntos suspensivos y se indica consultar el expediente completo. No se descargan adjuntos ni se inventan responsables o acciones.

## Estado del catálogo

- Listos: permisos, cursos/vencimientos, contratos.
- Parcial: manifiestos, con control de expedientes; falta cantidad/material/destino.
- Pendientes: apoyos/subsidios y diario de remisiones/Carta Porte.

## Validación

Pruebas de fronteras de fecha, exclusión por estatus, renovaciones, actividades realizadas, responsables faltantes, paginación de más de 500 registros, acceso denegado, consulta incompleta y despacho del generador central. PDF vacío y denso con las 11 categorías y textos largos para revisión visual; muestras de prueba, sin datos productivos.

Resultado: 80 pruebas aprobadas entre reportes, Gestión Documental y la tarjeta de Supervisión de Dirección (11 pruebas nuevas). Análisis estático sin incidencias. Se renderizaron e inspeccionaron las 13 páginas del PDF denso y las 3 del vacío, además del acceso en el dashboard. Validación local con fuentes simuladas; no se desplegó la aplicación ni se consultaron expedientes productivos en esta entrega.
