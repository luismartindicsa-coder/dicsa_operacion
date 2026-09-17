# Card de Recursos Humanos en Dirección

Reemplaza el acceso pequeño por un panel de ancho completo en Áreas de análisis,
con la misma apariencia de los cards de Dirección y acceso al dashboard de RH.

## Resumen

- Periodo: utiliza la selección compartida de RH. Se puede cambiar desde el card;
  la selección queda disponible al abrir RH. No selecciona una semana automáticamente.
- Total fiscal: mismo cálculo de Nómina, con desglose de depósito y cheque.
- Total flujo: mismo importe a entregar de Nómina; incluye la porción del fiscal
  asignada a cheque. El total a pagar es depósito más flujo, no fiscal más flujo.
- Estado del periodo y colaboradores con prenómina lista o publicada.
- Vacaciones próximas: inicios desde mañana hasta los siguientes 15 días,
  respecto a la fecha actual, con colaborador, empresa, fechas y estado pendiente.
- Permisos: eventos no cancelados que se traslapan con el periodo seleccionado,
  con tipo, colaborador y fechas. Incluye los tipos existentes de Permisos RH.
- Faltas: jornadas marcadas como `falto` en Asistencia operativa del periodo,
  agrupadas por colaborador con sus fechas. Excluye referencias `importado` y
  evita contar dos veces al mismo colaborador en una fecha.

Los eventos y faltas excluyen colaboradores dados de baja. Los importes guardados
del periodo conservan todos los registros de Nómina, incluidos los históricos;
los periodos cerrados y filas publicadas conservan su distribución de pago.

## Fuentes y comportamiento

Consulta de solo lectura a las tablas existentes de perfiles, periodos operativos,
prenómina, cierres, vacaciones, permisos y asistencia. Las consultas están paginadas;
el detalle de nómina y asistencia se limita al periodo y las vacaciones a 15 días.
`HrPayrollPeriodSummary` reutiliza el cálculo de Nómina sin duplicar sus fórmulas.

Actualización silenciosa cada 30 segundos y al volver de RH. Un error conserva el
último resultado con un aviso; la ausencia de datos no se presenta como nómina de
cero pesos. Los cambios de periodo descartan respuestas anteriores pendientes.
Las listas permiten desplazarse para revisar todos los eventos. No requiere migración.

## Validación

Pruebas de paridad con Nómina (fiscal, depósito, cheque y flujo), periodos cerrados,
selección explícita, límites de vacaciones, permisos entre semanas, faltas y bajas,
paginación y alcance de consultas, estados vacíos/errores, carreras de actualización,
navegación y distribución en anchos de 1360, 740 y 390 px.
