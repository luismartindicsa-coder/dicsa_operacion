# Diferencia fiscal del periodo 35 por bajas posteriores

La caída de $148,725.80 a $140,236.00 se explica exactamente por cuatro colaboradores que pasaron a baja en Personal con fecha efectiva 2026-09-08. Prenómina filtraba `employment_status != baja` al consultar los perfiles, incluso al abrir el periodo del 21 al 27 de agosto. Por eso pasó de 78 a 74 colaboradores.

| ID | Colaborador | Fiscal omitido | Medio fiscal |
|---|---|---:|---|
| 234 | Rigoberto González Malagón | $2,205.20 | Depósito |
| 252 | Juan Manuel Pavana Sagrero | $2,205.40 | Cheque |
| 261 | María G. Hernández Montelongo | $1,877.20 | Depósito |
| 298 | Fernando Axel Soto Tamayo | $2,202.00 | Cheque |
| | Total | $8,489.80 | |

La importación CONTPAQ del periodo es idéntica a la copia de la comparación anterior. La migración de compensaciones no modificó ningún salario base ni importe total existente: sólo hay una normalización de total nulo a cero en un perfil ajeno a estos cuatro casos. El cambio a cheque actualizó únicamente el medio fiscal. No hay evidencia de que esos cambios causaran la reducción del fiscal; la exclusión de las cuatro bajas la explica por completo.

## Corrección

Se cargan los perfiles con estado y fecha de baja, y se decide su inclusión para el periodo seleccionado. Una baja posterior al final del periodo conserva al colaborador en ese periodo histórico. Un borrador ya guardado también permanece visible. Se mantiene la exclusión anterior en el periodo de la baja y posteriores cuando no existe un borrador, sin inventar liquidaciones ni prorrateos. No se reactivaron personas en Personal.

Los contadores y el número esperado para cierre usan el padrón del periodo, no el total de perfiles consultados. Se mantienen los importes individuales y la asignación de depósito/cheque; no se cambian vacaciones, CONTPAQ, movimientos ni cálculos monetarios.

## Conciliación

| Concepto | Excel NOMINA35.xlsx | App corregida | Excel menos app |
|---|---:|---:|---:|
| Depósito fiscal | $125,093.64 | $125,066.00 | $27.64 |
| Cheque fiscal | $23,659.80 | $23,659.80 | $0.00 |
| Fiscal total | $148,753.44 | $148,725.80 | $27.64 |

Fuente Excel: Hoja1, R84:S84. La diferencia grande anterior era $8,517.44: $8,489.80 por las cuatro bajas más los $27.64 originales.

Los $27.64 son una diferencia neta de tres registros: Rebeca (fila 12) tiene $2,205.20 en el Excel y cero en la app por sus vacaciones ya pagadas, cuyo pago duplicado el usuario identificó como error; Dania (fila 73) tiene cero fiscal en el Excel y $2,177.60 oficiales de CONTPAQ en la app; Jesús Alejandro (fila 65) tiene $1,890.24 en el Excel contra $1,890.20 en CONTPAQ. No se ajustaron estos registros para forzar una coincidencia.

## Evidencia y pruebas

- Proyección con los datos consultados: 74 → 78 colaboradores y recuperación exacta de $8,489.80. Los 78 importes fiscales coinciden individualmente con la comparación anterior.
- Reparto recuperado: depósito $4,082.40 y cheque $4,407.40.
- Tres pruebas nuevas de conservación de periodos anteriores, límites de baja/ingreso y persistencia de borradores publicados. Las 83 pruebas de RH pasan; análisis Dart sin incidencias.
- Consulta limitada y análisis sin escrituras en Supabase. Evidencia local en `/private/tmp/dicsa_fiscal_delta/`; comparación anterior en `/private/tmp/dicsa_nomina35_compare/`.
