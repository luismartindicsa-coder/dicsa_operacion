# Cheque dentro del Flujo a entregar

Prenómina y Nómina muestran tres importes operativos: **Depósito fiscal**, **Flujo a entregar** y **Total**. El fiscal pagado por cheque se entrega en efectivo e integra el Flujo a entregar. El detalle conserva su origen fiscal y muestra el cheque como una parte incluida en el flujo.

La tarjeta del periodo conserva el desglose **Total fiscal = Depósito fiscal + Cheque**. La suma de los importes de entrega es **Total = Depósito fiscal + Flujo a entregar**. El cheque se cuenta una sola vez.

La tarjeta **Flujo a entregar** muestra debajo sus dos componentes: **Flujo** (importe operativo después de descuentos y ajustes) y **Cheque** (pago de origen fiscal). Ambos suman el importe principal. Prenómina y Nómina comparten el mismo diseño de desglose que la tarjeta fiscal.

## Ejemplos

| Configuración | Fiscal después de ajustes RH | Complemento | Depósito fiscal | Flujo a entregar | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cheque, CONTPAQ neto $1,800 | $1,800 | $0 | $0 | $1,800 | $1,800 |
| Cheque con complemento | $1,800 | $300 | $0 | $2,100 | $2,100 |
| Cheque con descuento fiscal manual de $200 | $1,600 | $300 | $0 | $1,900 | $1,900 |
| Depósito con complemento | $1,800 | $300 | $1,800 | $300 | $2,100 |

Aunque el salario base del expediente sea $2,205.28, el primer caso entrega sólo el neto de $1,800. La clasificación como cheque no compensa las deducciones de CONTPAQ.

## Persistencia y conceptos

`flowDeliveryAmount` es un importe derivado para presentación. `cash_salary_amount` conserva el complemento salarial y `check_amount` conserva la parte fiscal entregada en efectivo. Guardar o publicar no traslada el cheque al complemento. Se respetan las distribuciones manuales y las congeladas al publicar o cerrar.

El cheque tampoco cambia la clasificación de los préstamos: los cobros fiscales ya incluidos en CONTPAQ siguen siendo informativos; la capacidad de retener del complemento sigue usando los conceptos de flujo. Los descuentos fiscales manuales explícitos continúan reduciendo el fiscal y su importe por entregar.

Los sobres toman el mismo `Flujo a entregar`, incluidos cheque, complemento, Pago por fuera y ajustes, con los descuentos ya aplicados y redondeo a centavos. La exportación respeta todos los filtros activos y abarca todas las páginas de esos resultados. Por ejemplo, al filtrar KS sólo se exportan sobres de KS. Sin filtros se incluyen todos los pagos positivos del periodo; no se generan sobres de cero o de saldos negativos. El Excel conserva sus tres columnas `NO.`, `NOMBRE`, `TOTAL`.

Se corrigió una diferencia en el exportador: el cálculo anterior omitía `paymentOutsideAmount`. La exportación ahora usa `flowDeliveryAmount` y conserva la lista filtrada. Las tarjetas mantienen los totales del periodo completo; el Excel suma sólo los pagos correspondientes a los filtros activos. No necesita migración de base de datos ni cambia registros históricos. La presentación se aplica también al consultar nóminas publicadas.

## Validación

- Pruebas con depósito, cheque total y cheque parcial; complemento cero o positivo; neto fiscal cero o reducido; descuento fiscal manual.
- Guardado, reapertura y publicación conservan el origen fiscal, el complemento y la distribución.
- Los editores muestran el mismo importe por entregar que las tablas.
- Regresión de filtros, selección, paginación y ventanas compactas en Prenómina y Nómina.
- Revisión visual de ambas pantallas con datos sintéticos: fiscal $25,700 = depósito $1,500 + cheque $24,200; flujo a entregar $27,500; total $29,000.
- Prueba del botón real de exportación con 45 colaboradores: se decodifica el Excel generado y se compara cada caso y el total con el Flujo a entregar de las filas filtradas. Incluye cheque, distribución parcial, descuento fiscal manual, préstamo, Pago por fuera, ajuste RH, cero, paginación, filtro KS y búsqueda combinados, y ningún resultado.
