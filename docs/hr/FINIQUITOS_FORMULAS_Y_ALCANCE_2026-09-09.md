# Finiquitos: fórmulas y alcance

Estado: pantalla, motor, historial de versiones y PDF implementados. Migración `20260909210000` aplicada en Supabase el 09/09/2026 mediante conexión directa autenticada a PostgreSQL. Guardado, lectura y permisos comprobados en la base real con transacción revertida. No se modificaron nóminas, asistencias ni Personal.

## Fuentes y decisiones confirmadas

- Archivo del usuario: `FINIQUITO.xlsx`, hoja `Hoja1`. Las otras dos hojas están vacías.
- Personal aporta salario Base, Flujo y Total. Total = Base + Flujo. El salario semanal de referencia no debe deducirse del neto de una nómina con retenciones.
- Deben existir finiquito, liquidación de 12 días por año e indemnización.
- El SDI anotado en la parte superior de la imagen anterior es informativo, según aclaración del usuario.
- El ISR procede de CONTPAQ. Su importe se conserva aunque no coincida con una fórmula informativa de la plantilla.
- La diferencia entre el cálculo con salario Total y el cálculo con salario Base se presenta en Flujo. El ISR no determina esa diferencia.

## Fórmulas verificadas en el Excel

| Concepto | Entradas | Fórmula actual | Resultado guardado |
| --- | --- | --- | ---: |
| Salario diario | F7: 2,205.20 semanales | M5 = F7 / 7 | 315.0285714285714 |
| Días de aguinaldo | F9: 04/09/2026; F21: 01/01/2026 | J14 = F9 - F21 | 246 |
| Aguinaldo proporcional | F10: 15; J14; M5 | M12 = F10 / 365; M13 = M12 × J14; N14 = M13 × M5 | 3,184.8093933463792 |
| Días desde aniversario | F22: 30/07/2026; F9 | J19 = F9 - F22 | 36 |
| Vacaciones proporcionales | F11: 22; J19; M5 | J20 = F11 / 365; J21 = J19 × J20; N20 = M5 × J21 | 683.5688454011741 |
| Prima vacacional | J21; M5 | M23 = J21 × 0.25; N23 = M23 × M5 | 170.89221135029354 |
| Bruto mostrado | N14:N23 | N24 = SUM(N14:N23) | 4,039.270450097847 |
| ISR oficial | O27: captura de CONTPAQ | Sin fórmula | 125.48 |
| Neto mostrado | N24; O27; P31 vacío | P33 = N24 - O27 - P31 | 3,913.790450097847 |

Este archivo tiene otros datos que la imagen anterior; su ISR es 125.48, no los 255.73 del ejemplo anterior. No deben mezclarse los casos.

## Conexiones que la plantilla aún no resuelve

1. F13 (días pendientes) no está conectado a una fórmula de salario pendiente en N6.
2. N7 (prima de antigüedad / 12 días por año) y N8 (indemnización) están vacías.
3. F18 (antigüedad en años) contiene un cero manual. No se calcula desde F8/F9.
4. N24 sólo suma N14:N23; deja fuera N6:N10, incluido el fondo de ahorro de N10.
5. F12 contiene el porcentaje de prima, pero M23 usa 0.25 fijo. Cambiar F12 no actualiza la prima.
6. Comisiones (F15) y bono nocturno (F16) no están incorporados a las percepciones.
7. La fila rotulada SDI tiene N9 = F17, que es bono de asistencia/puntualidad. No puede usarse como salario integrado para indemnización.
8. P9 referencia L32 vacía. O14 y O20 están vacías; el cero de base gravable O25 no acredita que todos los ingresos estén exentos. El ISR oficial está capturado aparte.
9. La nota de vacaciones habla de 12 días, mientras F11 contiene 22; la descripción debe seguir al dato efectivo.
10. Las diferencias de fechas no incluyen ambos extremos. La convención de días debe quedar explícita y comprobada con RH antes de fijarla como regla automática.

## Motor implementado

Cada renglón salarial conserva:

- concepto;
- periodo de devengo;
- cantidad de días/años;
- salario y fórmula aplicados;
- importe calculado con Base;
- importe calculado con Total;
- Flujo = importe con Total menos importe con Base;
- pagos anteriores aplicables, con referencia;
- ajustes RH y su justificación.

Ejemplo de diez días de vacaciones, antes de prima o retenciones: Base semanal 2,205.28 y Total semanal 4,900.00 producen Base 3,150.40, Flujo 3,849.60 y Total 7,000.00. Una retención fiscal posterior no aumenta los 3,849.60 de Flujo.

Los pagos anteriores se capturan por concepto y canal; RH registra los recibos y el periodo de devengo. El historial de Vacaciones/Prenómina se consulta como referencia, sin sumar versiones ni inferir que cualquier cálculo fue pagado. Vacaciones pagadas y disfrutadas son movimientos diferentes: no se resta dos veces el mismo antecedente.

Finiquito incluye prestaciones devengadas pendientes y conceptos adicionales aplicables. Los 12 días por año se identifican con prima de antigüedad; su procedencia y base tienen reglas propias. La indemnización requiere su salario integrado laboral aplicable; no debe usar una anotación informativa ni confundirse automáticamente con el SBC del IMSS. Los importes no salariales, como un fondo de ahorro, se toman de sus saldos reales, no de un multiplicador de salario.

El reparto Base/Flujo no constituye una clasificación fiscal de exento/gravado. Las retenciones oficiales y su origen se registran por separado.

## Modalidades confirmadas por el usuario

El usuario confirmó **modalidades acumulativas**:

1. Finiquito: sueldo pendiente, proporcionales y saldos adicionales.
2. Liquidación: finiquito + 12 días por año y fracción de antigüedad.
3. Indemnización: liquidación + 90 días sobre integrado laboral confirmado.

Los 12 días corresponden a prima de antigüedad y aplican el tope de dos salarios mínimos a cada base de cálculo. El campo permite confirmar el salario mínimo por zona/fecha; el valor sugerido 2026 es 315.04 para zona general. RH confirma procedencia y salario integrado; no se decide una causal automáticamente.

## Pantalla y persistencia

- Navegación RH → Pago → Finiquitos, disponible desde las pantallas RH.
- Buscador de Personal incluye perfiles activos y bajas. Precarga fecha de ingreso y Base/Flujo; Total es su suma. Cambiar el salario exige referencia para revisión.
- Datos, Prestaciones y ajustes, Antecedentes y Resultado. Los controladores se conservan al editar/borrar o cambiar de tab.
- Fechas de devengo propuestas desde inicio de año y último aniversario; RH las confirma. El conteo reproduce el Excel (final − inicial / 365), con opción explícita de incluir ambos extremos.
- ISR del finiquito: captura del importe oficial y referencia CONTPAQ. No se toma el ISR ni neto de una nómina ordinaria como si fueran de esta separación. ISR vacío produce neto pendiente; cero requiere captura explícita.
- Guardar borrador / revisado inserta una versión completa en `hr_employee_termination_calculations`. Incluye datos de Personal, antecedentes, entradas, fórmulas, resultados, autor y fecha. Abrir copia permite editar una versión anterior y requiere nueva revisión.
- RLS restringe lectura e inserción a RH/Dirección, sin UPDATE/DELETE para el cliente. Revisiones numeradas bajo bloqueo por colaborador. La migración no altera tablas de nómina ni marca la baja en Personal.
- PDF usa los resultados del registro guardado, sin recalcularlo con salarios actuales; muestra versión y estado. Exportar sin guardar produce borrador.

## Validación

El caso exacto de `FINIQUITO.xlsx` produce bruto **4,039.27**, ISR **125.48** y neto **3,913.79**. La suite completa de Recursos Humanos pasa: **104 pruebas**. Los archivos nuevos pasan `flutter analyze` sin incidencias. Las pruebas cubren modalidades, Base/Flujo, límites de antigüedad, pagos previos, prima variable, ISR desconocido/cero, deducciones excesivas, fechas y edición/guardado. Se generaron y revisaron visualmente PDFs de las tres modalidades con datos de ejemplo.

## Activación y verificación remota · 09/09/2026

La contraseña de base de datos proporcionada por el usuario permitió conectar directamente sin depender de la sesión de la API administrativa que devolvía 401. `supabase db push --dry-run` confirmó que la única migración pendiente era `20260909210000_create_hr_termination_calculations.sql`; se aplicó esa migración.

Validación en PostgreSQL real, mediante TLS con verificación de certificado y hostname:

- Migración registrada y RLS activo.
- El rol `authenticated` tiene SELECT/INSERT, sin UPDATE/DELETE; `anon` no tiene SELECT/INSERT.
- Con identidad de un perfil activo de RH: inserción y lectura de un borrador y una versión revisada, revisiones consecutivas y autor generado correctamente por el servidor.
- Las entradas y resultados provinieron del motor Dart de la app. El registro mantuvo exactamente bruto 4,039.27, ISR 125.48 y neto 3,913.79.
- La base rechazó marcar como revisado un cálculo sin ISR; también rechazó UPDATE y DELETE desde el rol de la app.
- Una identidad sin perfil RH no pudo ver los registros ni insertar.
- Todas las inserciones de validación se hicieron en una única transacción; se ejecutó ROLLBACK y una consulta posterior confirmó que no quedó ninguno de sus registros.

Las 104 pruebas de la suite RH y el análisis de los archivos nuevos ya habían pasado antes de la activación. La prueba remota verifica persistencia y políticas; no equivale a ejecutar un pago ni a probar la navegación de la aplicación instalada.

## Corrección de acceso y revisión · 17/09/2026

- La cuenta oficial `rh@dicsamx.com` no tenía fila en `profiles`. La app permitía entrar por correo, pero la función de RLS exigía ese registro y rechazaba el guardado con `42501`. Dirección sí tenía un perfil activo. El rechazo dependía de la cuenta, no del sistema operativo.
- Migración `20260917150000_fix_hr_termination_email_access.sql` aplicada en Supabase con autorización del usuario. La función resuelve el correo desde `auth.users` usando `auth.uid()`, reconoce las cuentas oficiales sin perfil y conserva el bloqueo de perfiles explícitamente inactivos y de usuarios ajenos a RH/Dirección. No cambia los permisos de modificación o eliminación del historial.
- El editor ofrece **Ver pendientes** junto al guardado y muestra los requisitos al principio de Resultado. La referencia de ISR y la confirmación de antecedentes siguen siendo necesarias; capturar ISR cero no sustituye su referencia. Los errores de permisos conservan lo capturado y muestran una explicación legible.
- Validación: 21 pruebas de cálculo/editor, incluyendo el recorrido para completar referencias y habilitar revisado con configuración Windows y macOS; pruebas SQL de acceso, historial inmutable, autor y revisión incompleta; análisis sin incidencias y compilación macOS correcta. Verificación remota con la identidad de RH de inserción/lectura de borrador y revisado dentro de una transacción revertida; consulta posterior confirmó cero registros de prueba. La migración guardada en Supabase coincide exactamente con el archivo local.
- El permiso corregido funciona desde la instalación existente. La nueva ayuda visual requiere actualizar la app de Windows; no se generó un ejecutable Windows desde este entorno macOS.

## Referencias verificadas

- LFT, artículos 79, 80, 87, 89 y 162; aplicación y bases de las indemnizaciones según el supuesto de separación: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFT.pdf
- PROFEDET, despido: https://www.profedet.gob.mx/micrositio/index.php/despido
- LISR, artículos 93–96: https://www.diputados.gob.mx/LeyesBiblio/pdf/LISR.pdf

Antes de usar un cálculo como autorización de pago, RH debe confirmar los antecedentes del colaborador y el ISR oficial del finiquito; la app conserva esa revisión y no ejecuta pagos.
