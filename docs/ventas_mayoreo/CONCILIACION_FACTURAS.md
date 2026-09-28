# Conciliación de boletas para factura

En `Ventas Mayoreo → Cuentas`, el botón superior derecho `Conciliar para factura`
abre las pestañas Nueva conciliación, Historial y Boletas. Referencia comercial: captura e historial de
cortes de Menudeo; superficie auxiliar `ContractDialogShell`; foco e interacción
de Entradas y Salidas; tokens visuales de Mayoreo. El grid existente se conserva.

## Contrato visual de la ventana

Las tres pestañas usan `MayoreoDialogTheme` y los componentes de
`mayoreo_dialog_widgets.dart`, con `mayoreoAreaTokens`, `kMayoreoPanelGradient`
y `kMayoreoInk`. La superficie conserva `ContractDialogShell`; campos, paneles
y opciones de clientes usan `ContractGlassCard`, `contractGlassFieldDecoration`
y `ContractPopupSurface` del contrato compartido.

Referencias concretas: encabezado y métricas de `Detalle de cuenta` en
`mayoreo_accounts_page.dart`; botones y selectores del diálogo de cortes en
`menudeo_cash_cuts_page.dart`. Las tarjetas de historial y boletas, los filtros,
interruptores y estados de foco comparten esa misma familia. El selector de
clientes conserva autofocus, flechas, Enter y selección al primer click. Se
verificaron capturas de las tres pestañas, el desplegable y el tamaño estrecho.

## Flujo

1. Buscar y seleccionar cliente; capturar importe solicitado en pesos, con hasta
   dos decimales. Se admite `165643`, `165,643.00` o `$165,643.00`.
2. `Buscar boletas` consulta todas las boletas disponibles del cliente, sin
   limitarse a la página o los filtros activos del grid de Cuentas.
3. Revisar boletas completas, importe solicitado, total y faltante. El total
   nunca excede la solicitud. Se puede capturar una referencia de factura.
4. `Guardar conciliación` reserva las boletas y guarda el detalle inmutable.
5. En `Historial`, desplegar una conciliación y sus boletas para consultar
   fechas, referencias, remisiones, materiales e importes guardados.
6. En `Boletas`, consultar todas las boletas operativas con filtro buscable por
   cliente, número y estado (`Todas`, `Usadas`, `Sin usar`). El interruptor
   `Usada` guarda inmediatamente el uso, sin modificar la venta ni sus pagos.
   La lista se pagina de 40 en 40 y se actualiza automáticamente.

Marcar `Usada` excluye la boleta de futuras búsquedas. Desmarcarla libera su
reserva y permite volver a conciliarla. Si provenía de una conciliación, su
snapshot y total originales se conservan; el detalle del historial indica
`Liberada para volver a conciliar` con fecha. Se registra también quién hizo el
cambio. Una boleta cancelada o sin aprobación aparece en la lista con ese estado
y sigue sin ser conciliable, aunque se marque sin usar.

No emite ni timbra CFDI, ni cambia el estado financiero o los pagos de la cuenta.

## Selección y exclusividad

- Fuente operativa: `mayoreo_sales_reports`, la misma que utiliza Cuentas;
  estado cancelado de `mayoreo_accounts` excluye la boleta.
- Se requieren peso, precio e importe aprobados positivos. No se incluyen demos
  con ID `rep_`. Boletas con varias partidas se agrupan por cliente y número;
  se toman completas y cada importe de partida se redondea a centavos.
- Identidad del cliente: ID de catálogo; en registros sin ID, nombre normalizado.
- El motor usa suma de subconjuntos 0/1, centavos enteros, reducción por MCD y
  bitsets. Calcula la combinación óptima sin exceder dentro del rango exacto.
- Para búsquedas excepcionalmente grandes, se limita memoria/trabajo mediante
  redondeo conservador hacia arriba; la pantalla indica explícitamente que el
  resultado es aproximado y puede existir otro más cercano. Nunca se redondea
  el total presentado: se suman los importes reales de las boletas.
- El guardado atómico vuelve a comprobar disponibilidad y el detalle completo.
  Si otra persona usó una boleta o cambió la venta, pide volver a buscar.
- Restricción única entre reservas activas por cliente/boleta y por ID de cada partida. Las reservas
  sobreviven a cambios o eliminación de la venta original.
- Reintentos de red conservan el mismo UUID y contenido para no duplicar el
  historial. Las tablas permiten lectura autenticada; escritura solo por RPC.

## Boletas históricas

Las boletas utilizadas antes de esta función ya pueden marcarse manualmente
desde la pestaña `Boletas`. No requieren capturar una factura ficticia ni un
importe solicitado. El estado de pago no determina si una boleta ya se utilizó
para este proceso: se excluyen las conciliadas y las marcadas manualmente.

La RPC admite `p_origin = 'historical'` para cargar conciliaciones antiguas y
aplicar las mismas reservas. La carga deberá resolver cliente/boleta a sus
partidas y validar cantidades antes de escribir; no hay importación automática
ni formato de archivo impuesto mientras el usuario define el histórico.

## Persistencia y validación

Migración `20260928120000_create_mayoreo_invoice_reconciliations.sql`, aplicada a
Supabase el 28/09/2026. Crea encabezados, boletas con snapshot, reservas de
partidas, vista de disponibilidad, consulta de clientes y RPC de guardado.

La migración `20260928140000_manage_mayoreo_invoice_ticket_usage.sql` agrega
liberaciones sin borrar historial, marcas manuales, auditoría de cambios y el
catálogo de todas las boletas; aplicada a Supabase el 28/09/2026.
Guardar conciliaciones y editar uso comparten un
bloqueo transaccional. Cada edición valida el snapshot y los IDs de reservas que
el usuario vio; un estado desactualizado no puede liberar una reserva nueva.
Los reintentos conservan el UUID y el contenido de la solicitud.

Pruebas:

- `test/mayoreo/mayoreo_invoice_reconciliation_test.dart`: centavos, exactitud,
  límites, duplicados y comparación contra fuerza bruta en 250 escenarios.
- `test/mayoreo/mayoreo_invoice_reconciliation_dialog_test.dart`: selección,
  foco inicial, vista previa, faltante, invalidación al editar, guardado,
  historial, exclusión posterior, pantalla estrecha, filtros de boletas,
  edición de uso, liberación con historial y reintentos.
- `tool/test_mayoreo_invoice_reconciliation_sql.mjs`: PostgreSQL embebido con
  reservas, snapshots, permisos, atomicidad, histórico, idempotencia,
  migración con reservas existentes, liberación, nueva conciliación y
  protección contra ediciones desactualizadas.
- `test/mayoreo/mayoreo_accounts_pending_test.dart`: regresión del grid existente.
