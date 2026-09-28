# Ingresos esperados

Acceso: **Dirección → Proyección → Ingresos**. Embarques conserva únicamente la planeación y el programa operativo.

La vista consolida los embarques guardados de la semana seleccionada, la cobranza abierta de Ventas Mayoreo y la disposición posible de El Palomar. El ingreso por venta se origina en una venta/embarque; producir pacas solo aumenta la disponibilidad para cumplirlo. El financiamiento se identifica por separado dentro del flujo total.

## Uso

1. Aceptar y ajustar embarques en la pestaña Embarques. El programa semanal distribuye la producción necesaria.
2. En **Pesos y precios**, revisar kg por paca y precio promedio por material.
3. En **Condiciones comerciales**, revisar cliente, tipo de pago, plazo, aliases, precio general y precios específicos por material. El material habitual es informativo.
4. Consultar esta semana, próxima y posterior. Cada semana abarca lunes a domingo para conservar pagos que vencen en fin de semana. Los plazos usan días calendario.
5. Vincular la venta real cuando la coincidencia no sea inequívoca. Al cambiar el peso, precio o cobro de Mayoreo, se actualiza la proyección automáticamente.
6. Guardar la configuración de El Palomar recalcula inmediatamente los cards. “Esta semana” incorpora una disposición posible al cierre de la semana consultada, distribuida entre Efectivo y Fiscal; muestra también cuánto corresponde a cobros por ventas y cuánto a financiamiento.

No se captura un segundo pago desde Dirección. Los cobros reales se leen de Mayoreo y de sus abonos vinculados en bancos.

## Fuentes y precedencias

- Embarques: `direction_shipment_plans`, pacas Nacional/Limpio/Americano. Incluye planeados y confirmados; cancelados no aportan dinero. Las sugerencias no guardadas no generan ingreso.
- Precio: importe/peso/precio aprobado real → precio configurado cliente-material (o precio comercial vigente de Mayoreo) → precio general del cliente → promedio del material. Precio desconocido permanece sin valuar; no se sustituye por un cero ficticio.
- Factibilidad: inventario conciliado + producción pendiente del Programa operativo vigente; referencia histórica cuando no existe un programa compatible con los embarques. La producción ya registrada se descuenta del pendiente. Noche está disponible al día siguiente. Se reservan existencias una sola vez, por fecha, con confirmados antes de tentativos del mismo día.
- Inventario estimado no permite afirmar “Listo para embarcar”. Déficits anteriores se conservan para no liberar material comprometido a otro cliente.
- Datos reales: coincidencia automática únicamente si cliente, material y fecha identifican una sola venta y un solo embarque. Un vínculo explícito persiste ante cambios de fecha. Cambios de cliente/material invalidan el vínculo y muestran una alerta.
- Los estados financieros se derivan; no sustituyen los estados operativos ni modifican contabilidad.

## Cobranza de Ventas Mayoreo

Se comparte con el dashboard de Mayoreo la regla de elegibilidad y saldo efectivo (`mayoreo_expected_collections.dart`): facturas abiertas, con fecha estimada, saldo pendiente mayor a cero, excluyendo pagadas, cheques canjeados y canceladas. Los abonos de banco `VENTA_FACTURA` asociados a la cuenta sustituyen el `paid_amount` capturado, nunca se suman ambos.

Incluye ventas de semanas anteriores y materiales de Mayoreo distintos del cartón. La fecha estimada determina la semana de ingreso, no la fecha de venta. Se clasifica como Fiscal. La cobranza vencida antes de la semana elegida permanece identificada como vencida, sin prometerse automáticamente para hoy.

Una cuenta ya representada por un embarque vinculado se excluye del bloque adicional. Si hay una posible coincidencia ambigua, prevalece la cuenta real y la estimación de los embarques coincidentes queda fuera del flujo hasta conciliarla. La cuenta de El Palomar conserva su tratamiento revolvente separado.

“Valor de los embarques” muestra solamente el valor de los embarques de la semana seleccionada. Los indicadores de flujo agregan además la cobranza de otras semanas y, en la semana consultada, la disposición posible de El Palomar. Cobrado no se vuelve a sumar a cobros pendientes.

## El Palomar

Regla confirmada por el usuario: **cheques/cargos aumentan el saldo por cubrir; remisiones/abonos lo reducen**. El saldo inicial se reconstruye de movimientos reales anteriores a la semana. Los cortes internos son resúmenes y no se suman otra vez. Una remisión con `source_report_id` ya aplicada no se proyecta por segunda vez.

Las compensaciones previstas (Pesado, Retorno, Mixto, Rebaba, Abono, Otro) son estimaciones separadas del libro real. Deben retirarse al registrarlas en la cuenta real. La vista permite retirarlas sin alterar Mayoreo.

La disposición exige límite y monto configurados y, por defecto, saldo cubierto. Un embarque sin valuar impide calcularla. Se limita al menor entre monto solicitado y crédito disponible; primero se asignan los dos topes configurables de efectivo y el resto a Fiscal. Se suma **una sola vez** al flujo de “Esta semana” como financiamiento posible, conservando el desglose frente a cobros por ventas. No vuelve a sumarse el valor de las remisiones de El Palomar como cobranza ordinaria.

La disponibilidad se calcula con el saldo al cierre de la semana consultada. Sin una fecha acordada, el calendario muestra “Al cierre · El Palomar” en lugar de inventar un día de pago. No se repite la disposición en “Próxima semana” ni en “Posterior”. Si falta cubrir la cuenta, definir un importe o valuar un embarque, el card explica por qué no agrega financiamiento. Cambiar o guardar nuevamente la configuración reemplaza el cálculo anterior; no acumula disposiciones ni registra préstamos/cobros reales.

## Persistencia y validación

### PDF de ingreso proyectado por embarque semanal

En **Dirección → Proyección → Ingresos → PDF de ingresos**, el usuario
elige dónde guardar `ingreso_proyectado_embarques_YYYY-MM-DD.pdf` para la semana
consultada. Usa una copia consistente de las fuentes cargadas y el mismo motor
de proyección de la pantalla. El botón espera a que termine la lectura y se
deshabilita si hubo un error al actualizar las fuentes.

El documento es un resumen ejecutivo de **una sola hoja A4 horizontal**, con:

- Cuatro cards: flujo de esta semana, valor de embarques, próxima semana y cobrado.
- Cantidad de embarques vigentes y pacas; cancelados excluidos.
- Origen del flujo semanal: cobros de embarques, cobranza adicional de Mayoreo
  (incluye ventas anteriores) y financiamiento de El Palomar.
- Resumen por material: pacas y valor de Nacional, Limpio y Americano.
- Efectivo, fiscal y mixto; totales posteriores, vencidos previos y sin fecha/tipo.
- Card de El Palomar con saldo al cierre, disposición posible y estado de la cuenta.
- Indicadores de seguimiento: sin confirmar, sin valuar, faltantes de producción,
  pendientes de conciliación y alertas de fuentes.

Los embarques cancelados no suman; los pendientes de confirmar y sin valuar se
identifican. Se mantienen los cobros parciales y la exclusión de estimaciones
pendientes de conciliar con Mayoreo. Las remisiones de El Palomar reducen el saldo
y no se suman como cobro ordinario. La disposición se incluye una sola vez.

No imprime filas por embarque, cliente o factura, ni observaciones extensas.
Todos los registros se agregan a los resúmenes; la cantidad de datos no aumenta
el número de páginas. El detalle permanece en la pantalla. Generar el PDF no modifica operaciones,
cuentas o proyecciones. Los errores de generación/guardado y la cancelación del
selector de archivo son visibles, con posibilidad de volver a exportar.

Validación: 9 pruebas del generador y guardado verifican una sola página, cifras
agregadas y cancelación/error del guardado. Revisión visual de semanas completas,
vacías, sin configuración y con 108 embarques; comprobación de cifras y márgenes
mediante extracción de texto. No requiere migración de base de datos.

### Base de datos y cálculo

Migración: `20260921190000_create_direction_expected_income.sql`. Crea únicamente parámetros, vínculos y previsiones; no modifica ni siembra movimientos financieros reales. Los pesos/precios y seis condiciones iniciales provienen de la especificación del usuario. Los límites de El Palomar quedan sin importe hasta configurarse.

RLS usa los mismos permisos de Dirección/administración/gerencia operativa que Programa operativo. El guardado de condiciones y precios por cliente es atómico. La venta vinculada es única entre embarques.

La recarga automática se difiere mientras un formulario conserva foco. Los errores de lectura mantienen la última lectura con advertencia; no muestran un cero inventado. Las pruebas cubren plazos, fines de semana, cobros parciales, vencidos, precedencia de precios, inventario, turnos, conciliación, disposiciones, foco de formularios y distintas ventanas.

Validación del 21 de septiembre de 2026:

- Migración aplicada a la base vinculada después de comprobar que era la única pendiente.
- 33 pruebas del módulo aprobadas; incluye guardar/reconfigurar El Palomar, actualización inmediata de cards y retiro automático de una disposición que deje de ser viable. Análisis estático de los archivos modificados sin incidencias.
- Revisión visual en escritorio y prueba de ventana de 780 px sin overflow en esta vista.
- Suite de Dirección: 170 pruebas aprobadas y dos fallos de tarjetas existentes a 320 px (`direction_logistics_card_test` y `direction_documental_card_test`), fuera de este módulo.
- El lint SQL no reportó problemas en la nueva función. El lint global señaló una referencia a la tabla temporal `tmp_prev_close` en la función existente `rpc_generate_inventory_monthly_cut`; esa función no fue modificada.
