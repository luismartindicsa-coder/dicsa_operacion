# Conciliación del periodo 35 · Estado actual

**Actualización:** los cinco ajustes fueron confirmados y aplicados. El periodo 35 ya está cerrado con 78 colaboradores publicados y total $201,793.04. El resultado definitivo está en [CIERRE_PRENOMINA35_2026-09-08.md](CIERRE_PRENOMINA35_2026-09-08.md). El contenido siguiente conserva la revisión previa al cierre.

Se aplicaron las confirmaciones del usuario exclusivamente a la prenómina del **21–27 de agosto de 2026**. Los salarios vigentes de Personal y el neto oficial de CONTPAQ permanecen intactos. El periodo sigue abierto y no se publicaron nuevos borradores ni emitieron recibos.

## Confirmaciones resueltas

- Los conceptos de las 14 filas con TOTAL vacío del Excel sí se pagaron. Se reconstruyeron sus totales para la comparación: $19,532.96. La referencia de efectivo pasa de $59,208.48 a **$78,741.44**. El archivo original no se modificó.
- Se confirmaron las identidades de Miriam, Jonathan y Miguel (NO 1, NO 2 y NO 3). Se guardaron $300, $2,205.28 y $2,205.28 íntegros en efectivo, sólo en el periodo 35.
- Dania recibió $2,260 íntegros en efectivo: fiscal oficial $2,177.60 como cheque y flujo manual del periodo $82.40.
- Maricruz tenía salario total de $3,000 en esa semana: base $2,205.28 y flujo $794.72. José Pilar tenía $2,500: base $2,205.20 y flujo $294.80. Personal conserva sus salarios vigentes.
- Ramón sólo llevaba fiscal $5,040.60 y vacaciones en efectivo $1,687.08. Su flujo ordinario de la semana quedó en cero manual, estable al reabrir.
- Los $276.36 de INFONAVIT operativo de Luis Ángel sí fueron un cobro adicional y se conservan.
- Los préstamos de Miguel Ángel ($600) y Cruz Ángel ($100) ya se cobraron por separado en efectivo. Se documentaron en Notas y en el origen del borrador como cobros realizados. La deducción de préstamo dentro de la nómina quedó en cero: no se condonaron los préstamos ni se simula un nuevo cobro. Desapareció el desfase de $700 entre total a pagar y depósito más sobres.
- Javier conserva el ajuste RH de $315.08 y total $4,900. Rebeca conserva total cero.

## Resultado verificado en los registros guardados

| Concepto | App |
| --- | ---: |
| Fiscal en depósito | $122,888.40 |
| Fiscal en cheque | $25,837.40 |
| Fiscal total | $148,725.80 |
| Sobres: cheque más flujo | $78,025.08 |
| Total a pagar: depósito más sobres | $200,913.48 |
| Referencia reconstruida de efectivo del Excel | $78,741.44 |
| App menos referencia, sólo efectivo | **−$716.36** |

Los valores se verificaron volviendo a consultar los registros persistidos y ejecutando el cálculo de producción, incluyendo reapertura. Los colaboradores ajenos a cada captura y los campos no autorizados permanecieron iguales. Las actualizaciones de registros existentes usaron su ID y fecha de modificación para evitar sobrescribir cambios concurrentes.

La referencia fiscal original de Excel incluye el pago erróneo de Rebeca y omite el fiscal de Dania. Al retirar $2,205.20 de Rebeca del depósito y reconocer $2,177.60 de Dania como cheque, la referencia fiscal conciliada es $148,725.84: quedan cuatro centavos de diferencia con CONTPAQ, asociados a Jesús Alejandro. Esto no altera el efectivo de Dania, que ya estaba incluido en su TOTAL del Excel.

## Confirmaciones finales pendientes

Se consultaron al usuario dos grupos de ajustes escritos fuera de las cinco columnas originales de captura:

1. José Jesús Cienega: $945.12 más de flujo en Excel que en la app; Luis Ángel Centeno: $249.48 más. Debe confirmarse si fueron ajustes manuales de RH realmente pagados, sin convertirlos en un complemento automático del salario.
2. Fernando Axel: −$315.04; Maritsa: −$24.20; José Ángel López: +$24.20. Están incorporados dentro de las fórmulas de sueldo del Excel y requieren confirmar si se aplicaron adicionalmente a CONTPAQ.

Gabriel tiene $163 de horas extra procedentes de asistencia manual: 60, 63 y 40 minutos en tres días, todos superiores a 15 minutos, a $60/hora. Se conservan conforme a la regla operativa; su columna del Excel está vacía. Las diferencias restantes de centavos obedecen a bases, netos oficiales y al ajuste exacto de Javier, y no se han compensado automáticamente.

## Preparación del cierre, sin aplicarlo todavía

La última consulta del periodo 35 encontró 78 colaboradores calculados, 38 registros guardados (Rebeca publicada y 37 borradores) y ningún cierre. El único impacto operativo del 35 ya está liquidado; no hay otros eventos del 35 pendientes de liquidación. El usuario aclaró que primero se termina el 35 y después se trabajará en el 37. Esta preparación no modifica el 37.

Se ejecutaron dos pruebas locales con los datos consultados: importes actuales y escenario con los cinco ajustes RH pendientes. En ambos casos se simularon los 78 registros publicados, su reapertura en Prenómina, su lectura en Nómina cerrada y los importes del recibo. Todos los importes coincidieron por colaborador; depósito más sobre equivale al total, Rebeca permanece en cero y Javier en $4,900. Son simulaciones locales: todavía no se publicaron esos registros ni se cerró el periodo.

También pasaron las 83 pruebas existentes de RH. Esto verifica los cálculos e interacciones cubiertos por esas pruebas; no sustituye la confirmación de qué importes efectivamente se pagaron.

Si el usuario confirma los cinco ajustes como pagos/descuentos reales, su efecto neto sería +$879.56, exclusivamente en el periodo 35:

| Concepto | Actual | Con los cinco ajustes, pendiente de confirmar |
| --- | ---: | ---: |
| Fiscal total | $148,725.80 | $148,725.80 |
| Fiscal depósito | $122,888.40 | $122,888.40 |
| Fiscal cheque | $25,837.40 | $25,837.40 |
| Flujo | $52,187.68 | $53,067.24 |
| Efectivo completo: cheque más flujo | $78,025.08 | $78,904.64 |
| Total a pagar | $200,913.48 | $201,793.04 |

El segundo escenario quedaría $163.20 por encima de los $78,741.44 reconstruidos del Excel: $163 de horas extra manuales de Gabriel y $0.20 netos de centavos ya identificados. No se deben inventar compensaciones para eliminar esa diferencia. Los cinco ajustes aún requieren respuesta del usuario antes de capturarlos y congelar el cierre.

## Evidencia

- `backups/hr_prenomina35_excel_2026-09-08/`: captura original de los cinco conceptos y Javier.
- `backups/hr_prenomina35_cash_confirmed_2026-09-08/`: tres pagos en efectivo confirmados.
- `backups/hr_prenomina35_final_confirmed_2026-09-08/`: antes/después de las seis correcciones posteriores y diferencias restantes por colaborador.
- `ORIGEN_DIFERENCIAS_PRENOMINA35_2026-09-08.md`: trazabilidad de la comparación original contra el TOTAL incompleto del Excel.
