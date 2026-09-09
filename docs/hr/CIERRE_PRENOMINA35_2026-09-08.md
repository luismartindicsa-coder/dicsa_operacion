# Cierre confirmado del periodo 35

El periodo **21–27 de agosto de 2026** quedó cerrado en Supabase con **78 colaboradores publicados**. El usuario confirmó aplicar los cinco ajustes RH pendientes. Se conservaron los importes fiscales oficiales, los salarios vigentes de Personal y los datos de otros periodos. No se emitieron recibos ni se enviaron pagos.

## Totales definitivos

| Concepto | Importe |
| --- | ---: |
| Fiscal en depósito | $122,888.40 |
| Fiscal en cheque | $25,837.40 |
| Fiscal total | $148,725.80 |
| Flujo | $53,067.24 |
| Efectivo completo: cheque más flujo | $78,904.64 |
| Total a pagar: depósito más efectivo | **$201,793.04** |

Fiscal más flujo y depósito más efectivo coinciden con el total. El cheque forma parte del fiscal y del efectivo entregado: no se vuelve a sumar al total de la nómina.

## Ajustes RH aplicados sólo a esta semana

| ID | Colaborador | Ajuste |
| --- | --- | ---: |
| 132 | José Jesús Cienega Hernández | +$945.12 |
| 217 | Luis Ángel Centeno González | +$249.48 |
| 298 | Fernando Axel Soto Tamayo | −$315.04 |
| 153 | Maritsa López Moreno | −$24.20 |
| 157 | José Ángel López Pérez | +$24.20 |
| | Efecto neto | **+$879.56** |

Cada importe quedó en `manual_adjustment_amount`, acompañado de notas y de su confirmación en `source_snapshot.period35_excel_rh_adjustment`. No se convirtió en un cambio permanente de salario ni en compensación automática del neto fiscal. Rebeca conserva total cero y Javier conserva $4,900.

## Diferencia documentada contra el Excel

El TOTAL de efectivo original del Excel era $59,208.48. Las 14 filas con TOTAL vacío pero conceptos efectivamente pagados, confirmadas por el usuario, agregan $19,532.96. La referencia completa es **$78,741.44**.

El efectivo final de la app es **$163.20 mayor** que esa referencia: $163 de horas extra de Gabriel calculadas desde asistencia manual y $0.20 netos de diferencias de centavos ya identificadas. No se agregó una compensación para ocultar esa diferencia. El archivo NOMINA35.xlsx original no se modificó.

## Verificación y respaldo

- Antes de escribir se volvió a consultar el periodo y se comprobó que las fuentes y los borradores no habían cambiado desde la revisión.
- Se publicaron 37 borradores existentes y se crearon 40 registros publicados. El registro ya publicado de Rebeca se conservó íntegro.
- Las actualizaciones usaron ID, periodo, estado y fecha de modificación para detectar cambios concurrentes. Se registró el antes y después de cada operación.
- Se consultaron los 78 registros persistidos y se ejecutaron los cálculos reales de Prenómina, Nómina y recibos: coincidieron los importes por colaborador, los totales y la distribución depósito/cheque.
- Después de guardar el cierre se volvió a consultar el estado cerrado y se verificó que ninguno de los 78 registros hubiera cambiado.
- Las 83 pruebas existentes de RH habían pasado durante la preparación; la prueba adicional de los importes efectivamente guardados también pasó. Esto valida los comportamientos cubiertos, sin afirmar que se haya probado una corrida futura.
- El cierre conserva los totales y las diferencias documentadas en `summary_snapshot`.
- Respaldo limitado y registro de operaciones: `backups/hr_prenomina35_closure_2026-09-08/`.

No se modificó ni preparó la nómina del periodo 37 durante este cierre.
