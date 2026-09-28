# Auditoría de nómina y soporte compartidos

## Conclusión

El importe presentado como «Nómina compartida» reunía remuneraciones de RH y otros gastos administrativos. Además, contenía dos retiros de efectivo que Dirección confirmó como fondeo de nómina/caja. Primero se corrigió esa duplicación y el nombre visible. Después, por indicación de Dirección, se sustituyó el reparto uniforme de RH por proporciones de actividad: transporte por viajes/km y resto del personal común por kg/movimientos. Se conserva íntegro el total de nómina; cambia su distribución.

## Verificación inicial de RH, antes del reparto proporcional

Lectura de solo consulta de perfiles y cierres, sin exportar nombres, salarios individuales ni credenciales. Periodo 01–22/09/2026:

- Dos cierres publicados cubren 04–10 y 11–17 de septiembre: 14 días.
- Los otros ocho días utilizan el sueldo semanal acordado dividido entre siete, respetando fechas de ingreso y baja.
- No se encontraron duplicados por empleado/día en los cierres consultados.
- No se encontró al mismo empleado/día simultáneamente en nómina publicada y en la estimación por perfil.
- Los grupos internos DICSA CELAYA, DICSA APASEO y APASEO entran al reparto común; el algoritmo no distingue sus funciones de administración, patio y transporte.
- Los pagos identificados expresamente como nómina en Finanzas se excluyen para usar RH como fuente única. La detección depende de la descripción o vínculo documental; no demuestra ausencia de todos los posibles duplicados financieros.

## Duplicación confirmada y corregida

Dirección confirmó que estos movimientos son retiros para nómina/caja:

| Fecha | Referencia | Importe |
|---|---|---:|
| 11/09/2026 | 0007667 · CHEQUE DICSA · PAGO EN EFECTIVO | $19,168.60 |
| 18/09/2026 | 0007668 · CHEQUE DICSA · PAGO EN EFECTIVO | $28,709.80 |
| Total | | $47,878.40 |

El motor reconoce la combinación exacta de beneficiario «CHEQUE DICSA» y comentario «PAGO EN EFECTIVO» en movimientos bancarios como fondeo de caja/nómina. Conserva importe y referencia en `non_operating_flows`. No elimina movimientos ni altera RH o Finanzas. Los pagos en efectivo a otros proveedores y los cheques con descripciones diferentes conservan su tratamiento anterior. Este fondeo tampoco alimenta el promedio histórico de gastos operativos.

Con 75 cuentas en el corte actual, el efecto es $638.38 menos por cuenta. Nómina y soporte pasa de $10,747.41 a $10,109.03. La nómina de RH permanece intacta. Dentro del nuevo importe, aproximadamente $5,361 provienen de RH; el resto incluye IMSS y otros conceptos administrativos. Los costos globales disminuyen exactamente $47,878.40 y el valor generado permanece igual.

Se corrigió la etiqueta visible a «Nómina y soporte compartidos», preservando la clave interna de la línea para mantener los ajustes existentes.

## Diagnóstico del reparto anterior

La bolsa se divide por el número de cuentas del periodo: 75 en la lectura actual, independientemente de toneladas, viajes o intensidad de atención. Una cuenta con un movimiento recibe el mismo reparto común que una de actividad constante. La nómina de patio y transporte no está separada por función dentro de esa bolsa.

La composición también mezcla IMSS, impuestos, remodelaciones, honorarios, papelería y otros gastos. Las fechas de pago pueden diferir del periodo de consumo: por ejemplo, hay honorarios de julio pagados en septiembre. No se han reclasificado automáticamente esos documentos ni eliminado sus costos.

Para una asignación operativa más representativa: conservar el personal dedicado en su empresa; identificar personal de transporte y patio para repartir según actividad pertinente; mantener administración separada con una base explícita; atribuir cargas laborales conforme a la nómina a la que corresponden. El aporte antes del soporte compartido y el aporte después del reparto deben seguir visibles. No se cambió esa política de reparto durante esta corrección.

## Validación de la corrección de retiros

43 pruebas de motor operativo, PDF y widgets, incluidas regresiones que conservan gastos en efectivo auténticos y nómina RH, y excluyen los retiros también de referencias históricas. Consulta de integración real y comparación antes/después con variación exacta de $47,878.40, sin cambiar ingresos ni operaciones de origen. Análisis estático sin observaciones y compilación macOS debug completada.

## Reparto proporcional implementado después de la confirmación de Dirección

Modelo `activity-proportions-v1`. No se crean categorías permanentes de cliente ni se modifica la nómina de origen:

1. Personal dedicado: permanece atribuido a su empresa.
2. Choferes comunes identificados: `bolsa × (viajes de la cuenta / viajes totales + km de la cuenta / km totales) / 2`.
3. Resto del personal común: `bolsa × (kg de la cuenta / kg totales + movimientos de la cuenta / movimientos totales) / 2`.

Las dos medidas tienen el mismo peso como aproximación inicial; no son horas de trabajo medidas. Los movimientos comprenden documentos canónicos de compra/entrada, servicios completados y documentos de venta de servicios. Si solo hay una base disponible, absorbe el 100% del peso. Sin viajes/km en toda la operación, la capacidad de transporte se conserva como costo y utiliza provisionalmente la base de patio/soporte. Si tampoco existe esa actividad, se reparte entre cuentas y se explica la falta de base.

Una cuenta sin viajes ni km recibe cero de la bolsa de choferes identificados cuando sí existe transporte en el corte. Los demás gastos de Finanzas, incluido IMSS, conservan sus bases anteriores: no se afirma que este cambio resuelva su atribución por función.

Los nombres abreviados del catálogo de Logística se comparan transitoriamente con RH mediante coincidencia única de al menos dos palabras. En la lectura actual hay 13 coincidencias inequívocas: 12 del grupo interno y una de empresa dedicada. Las coincidencias ambiguas permanecen sin clasificar. Se eliminan los nombres antes de construir el análisis; las fórmulas declaran que la función es inferida. El resto del personal se presenta como «patio y soporte sin puesto desglosado», no como administración comprobada. Esta falta de clasificación completa limita la precisión del reparto.

### Comprobación real: 01–22/09/2026

Lectura del 22/09/2026 a las 15:26, 75 cuentas. Comparación con el mismo corte anterior después de excluir los retiros; la actividad puede variar con nuevos registros.

| Bolsa de RH | Antes | Después |
|---|---:|---:|
| Personal compartido | $402,070.13 | $402,070.13 |
| Personal dedicado | $247,012.26 | $247,012.26 |
| Total | $649,082.39 | $649,082.39 |

Las 47 cuentas sin viajes tienen cero de nómina de choferes identificados. Ejemplos de **RH compartido únicamente**, sin sumar IMSS ni otros gastos administrativos:

| Empresa | Reparto anterior | Transporte nuevo | Patio y soporte nuevo |
|---|---:|---:|---:|
| ADRIAN CARDENAS | $5,360.94 | $0.00 | $1,257.62 |
| JUAN CARLOS TORRES | $5,360.94 | $0.00 | $221.54 |
| ANTONIO MORALES | $5,360.94 | $0.00 | $19,610.32 |
| LICBOX | $5,360.94 | $1,610.17 | $12,634.46 |
| AVON | $5,360.94 | $23,699.20 | $25,066.51 |

El resultado no mejora artificialmente todas las cuentas: las de mayor actividad absorben más del mismo costo total. La atribución no convierte el costo distribuido en costo evitable si se retira una cuenta.

Validación del reparto: 78 pruebas del módulo (77 en la suite completa y una nueva regresión de exportación), incluidas conservación monetaria, entrega directa, cambios graduales de viajes/km, normalización de unidades, ausencia de bases, coincidencias ambiguas, personal dedicado y protección contra estimar otro grupo funcional en días ya publicados. Comparación real con diferencia menor de un centavo en cada bolsa y sin escrituras a operaciones de origen. Análisis estático sin observaciones, compilación macOS debug y recarga de la app abierta; el detalle de LICBOX muestra las dos bolsas por separado. Se generaron y revisaron las siete páginas de cada PDF de control (LICBOX y ADRIAN CARDENAS), con totales conciliados y sin problemas de desbordamiento. Los valores de la pantalla pueden cambiar al entrar nuevos movimientos después de la lectura comparativa.
