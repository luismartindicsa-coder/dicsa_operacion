# Separación de pagos y eventos de vacaciones

Decisión del usuario: Pago de vacaciones registra el anticipo/pago en su periodo y genera recibo; Eventos registra disfrutes, reservas y ajustes RH. Disfrutar días ya pagados conserva la compensación del sueldo del periodo, sin repetir vacaciones ni prima.

## Cambios

- Detalle con pestañas locales Pago de vacaciones / Eventos. Se filtran los mismos eventos por su tipo existente; se conservan IDs, fechas y tabla, sin migrar ni duplicar historia.
- Pago: tipo fijo de pago, fecha de pago, días, domingos/festivos, estado, periodo real y acción Guardar y generar recibo. Reutiliza el generador PDF existente después de guardar. Busca CONTPAQ en el periodo del pago seleccionado, no en el periodo actualmente abierto en el grid. La emisión es por el pago elegido.
- Eventos: disfrutes, reservas y ajustes; excluye pago de las opciones. Sin domingos pagados, ISR ni acción de recibo. Se conservan asistencia y compensación de anticipo en Prenómina.
- Los días guardados y domingos/festivos se restauran como cantidades capturadas: al abrir ya no se sustituyen por sugerencias del rango. El cero explícito o campo borrado tampoco vuelve a una sugerencia.
- Los pagos no consumen días disfrutados. Un evento operativo con impacto en Prenómina no incrementa días pagados. Sólo los eventos de pago producen vacaciones/prima en cálculos y sugerencias de Prenómina.
- Los impactos de un pago se asignan íntegros al periodo de pago elegido, en vez de distribuir ese pago entre periodos de disfrute.
- Movimientos con sincronización de Prenómina aplicada conservan datos y estado; se muestran en sólo lectura, también para navegación por teclado. Guardar otro evento no renormaliza ni modifica sus impactos.

## Validación

46 pruebas RH aprobadas. Se probó editar un pago de 12 días + 2 domingos a 10 + 0, cambiar a Eventos, editar un disfrute de 3 a 2 días, guardar, rehidratar los registros y conservar las cantidades y el periodo del pago. Los totales resultan 10 pagados y 2 disfrutados, separados. Se verifica también la acción de recibo del periodo histórico y el bloqueo de movimientos ya aplicados. Revisión visual con datos ficticios y tipografía real.

El analizador no reporta errores; siguen dos advertencias previas sobre helpers de asistencia sin uso. No se modificaron datos productivos ni se emitieron recibos reales en estas pruebas. Requiere recargar/recompilar la aplicación.
