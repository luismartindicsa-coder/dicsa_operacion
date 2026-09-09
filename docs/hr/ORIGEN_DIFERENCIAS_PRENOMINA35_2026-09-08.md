# Origen exacto de la diferencia de efectivo · Periodo 35

**Estado posterior a las seis correcciones confirmadas:** sobres de la app **$78,025.08** frente a referencia reconstruida **$78,741.44**, diferencia **−$716.36**. Se aplicaron la distribución de Dania, los salarios de Maricruz y José Pilar, flujo cero de Ramón y la separación de los préstamos ya cobrados. El estado completo y vigente está en `REVISION_PENDIENTE_PRENOMINA35_2026-09-08.md`; los importes de los apartados siguientes conservan la trazabilidad histórica.

**Avance más reciente:** el usuario confirmó las identidades y los pagos de las filas 80–82. Se guardaron y verificaron $4,710.56 para NO 1, NO 2 y NO 3, sólo en el periodo 35. El efectivo de la app pasó a **$76,759.80**; contra la referencia corregida de $78,741.44 queda una diferencia de **$1,981.64**. También confirmó que el INFONAVIT operativo de Luis Ángel sí es un cobro adicional y se conserva.

**Aclaración posterior del usuario:** los conceptos de las 14 filas con TOTAL vacío sí se pagaron; faltó completar sus totales. Al reconstruirlos con los importes del Excel suman **$19,532.96**. Por tanto, la referencia corregida de efectivo es **$78,741.44**, frente a **$72,049.24** en la app: quedan **$6,692.20 menos de efectivo en la app**. Esto es una reconstrucción para conciliar; el archivo original permanece intacto. La diferencia de ocho centavos respecto a los $19,533.04 de la tabla siguiente corresponde al flujo de José Luis Cruz ($294.80 en la app frente a $294.72 en el Excel).

El desglose siguiente conserva la comparación original contra AE84 incompleto para que pueda rastrearse la cifra de $12,840.76 informada inicialmente.

Comparación de la captura verificada: app $72,049.24 en sobres frente a $59,208.48 en `NOMINA35.xlsx`, `Hoja1!AE84`. Diferencia app menos Excel: **+$12,840.76**. El cheque está incluido una sola vez dentro de los sobres. Esta cifra no es una diferencia fiscal.

| Grupo | App menos Excel |
| --- | ---: |
| 14 filas con TOTAL vacío en el Excel e importe positivo en la app | +$19,533.04 |
| 3 filas finales del Excel sin efectivo en la app | −$4,710.56 |
| Diferencias en otras filas con TOTAL numérico | −$1,981.72 |
| Diferencia total de sobres | **+$12,840.76** |

## Filas con TOTAL vacío

El archivo tiene 21 celdas TOTAL vacías. Sólo 14 generan diferencia de efectivo. No se afirmó que todas fueran fórmulas olvidadas ni se reemplazaron por cero en la fuente. Excel SUM las omite; la app suma los conceptos y salarios vigentes. En estas 14 filas hay $13,520 de bonos/extra, $500 de transporte y $550 de préstamos, además de sueldo y cheque.

| Fila de Hoja1 | Colaborador | Efectivo en app omitido por TOTAL vacío |
| --- | --- | ---: |
| 11 | JOSE LUIS CRUZ CRUZ | $1,794.80 |
| 14 | JULIAN CONTRERAS RODRIGUEZ | $1,200.00 |
| 15 | JOSE DE JESUS MORALES PEREZ | $2,494.72 |
| 16 | ISRAEL ROBLES RAMIREZ | $1,694.72 |
| 17 | EMILIO JOSE SANDOVAL MORA | $2,894.72 |
| 20 | FERNANDO MUNIZ CARDENAS | $360.00 |
| 21 | JUAN ANTONIO MIRANDA CORNEJO | $2,505.20 |
| 22 | RODOLFO NORIEGA RAMIREZ | $350.00 |
| 43 | ANDRES GARCIA DE LA ROSA | $294.72 |
| 45 | ILIANA GUADALUPE MARTINEZ GOMEZ | $1,094.72 |
| 46 | MARIA DEL CARMEN MUÑOZ RAMIREZ | $500.00 |
| 52 | FEDERICO RODRIGUEZ PACHECO | $2,124.72 |
| 57 | JOSE FEDERICO HUERTA ROJAS | $1,724.72 |
| 61 | JUAN DANIEL MANCERA OLVERA | $500.00 |

## Filas finales del Excel

| Fila | Nombre en el Excel | Efectivo Excel |
| --- | --- | ---: |
| 80 | MIRIAM CRISTINA CORNEJO FERNANDEZ | $300.00 |
| 81 | JONATHAN ORIA | $2,205.28 |
| 82 | MIGUEL MUÑOZ | $2,205.28 |

Estas filas no traen ID. Los perfiles relacionados NO 1, NO 2 y NO 3 tienen flujo cero y no generan fiscal ni efectivo en esta proyección. La identidad de Miriam requiere confirmación porque el apellido del perfil es HERNANDEZ. No se asignó ni modificó su sueldo durante la carga de las cinco columnas. Elizabeth, fila 83, tiene efectivo cero y no aporta diferencia.

## Diferencias con TOTAL numérico

Valores positivos: la app entrega más efectivo. Negativos: entrega menos.

| Fila | Colaborador | Diferencia | Causa comprobada |
| --- | --- | ---: | --- |
| 18 | GABRIEL RODRIGUEZ CARRANCO | +163.00 | Horas extra de asistencia por $163; Z18 está vacía. |
| 26 | JOSE JESUS CIENEGA HERNANDEZ | -945.12 | U26 = $4,600 − ($945.12 + $315.04) = $3,339.84. Personal conserva flujo contractual $2,394.72. El Excel aumenta el complemento cuando disminuye jornada; los $720 de bonos/extra coinciden. |
| 27 | JAVIER MARTINEZ BARRERA | +0.04 | Ajuste autorizado para cerrar en $4,900: $315.08. El Excel termina en $4,899.96. |
| 36 | MARITSA LOPEZ MORENO | +24.20 | U36 descuenta manualmente $24.20 dentro de la fórmula de sueldo; no es una de las columnas cargadas. |
| 37 | JOSE ANGEL LOPEZ PEREZ | -24.20 | U37 agrega manualmente $24.20 dentro de la fórmula de sueldo; no es una de las columnas cargadas. |
| 50 | LUIS ANGEL CENTENO GONZALEZ | -249.48 | Excel: $2,700 − $276.36 = $2,423.64. App: cheque $1,955.80 + flujo $494.72 − $276.36 = $2,174.16. El importe del cheque no equivale a la base contractual. P50 también contiene $276.36: revisar si AB50 representa el mismo descuento ya incluido en CONTPAQ antes del cierre. |
| 56 | JUAN MANUEL PAVANA SAGRERO | +0.12 | Cheque $2,205.40 + flujo $294.72 = $2,500.12; Excel $2,500. |
| 58 | RAMON FERNANDO MIRANDA LOPEZ | +694.72 | Excel registra $1,687.08 de vacaciones y U58 vacía; app añade flujo contractual $694.72. S58 contiene el texto INCAPACIDAD, cuyo impacto requiere revisar. |
| 63 | MARICRUZ GARCIA YAÑEZ | +500.00 | Salario total en Personal $3,500 frente a $3,000 en G63; diferencia de flujo $500. Los $30 de bonos/extra coinciden. |
| 66 | ERNESTO RICO MENDOZA | -0.08 | Cheque $2,205.20 + flujo $294.72 = $2,499.92; Excel $2,500. |
| 69 | LUIS GABRIEL SALOMON CISNEROS | -0.08 | Cheque $2,205.20 + flujo $94.72 = $2,299.92; Excel $2,300. |
| 70 | DIANA ABRIL PAVANA FLORES | -0.08 | Cheque $2,174.40 + flujo $200 = $2,374.40; Excel $2,374.48. |
| 73 | DANIA DE LA VEGA GARCIA | -2,165.20 | Excel registra $2,260 todo en efectivo; app registra $2,177.60 en depósito y $94.80 de flujo. La diferencia de efectivo es $2,165.20, mientras que la diferencia total pagado es sólo $12.40. |
| 78 | FERNANDO AXEL SOTO TAMAYO | +315.04 | U78 contiene literalmente 2202 − 315.04. App entrega el cheque oficial completo de $2,202. No se cargó ese descuento incrustado en U. |
| 79 | JOSE PILAR RANGEL MALAGON | -294.60 | Personal tiene total $2,205.20 y flujo $0; Excel tiene sueldo $2,500. Con cheque $2,205.40 y bono $40, app entrega $2,245.40 frente a $2,540 en Excel. |

## Dos cifras distintas que no deben sumarse a esta diferencia

- La diferencia fiscal sigue siendo $27.64 (Excel $148,753.44 frente a app $148,725.80). Incluye la corrección de Rebeca, la distribución de Dania y cuatro centavos de Jesús Alejandro. La captura reciente no cambió ese total.
- Los préstamos de Miguel Ángel Abundis ($600) y Cruz Ángel Ramírez ($100) producen flujo negativo porque no tienen flujo disponible. El sobre se limita a cero; por eso depósito más sobres supera en $700 el total calculado de Prenómina. Es un pendiente de cobro, no otros $700 que deban agregarse a los $12,840.76.

Se verificó que el archivo original conserva el mismo SHA-256 utilizado para la carga. Esta revisión no modificó datos de la app ni del Excel.
