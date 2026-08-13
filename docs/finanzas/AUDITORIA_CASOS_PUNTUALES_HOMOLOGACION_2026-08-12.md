# Auditoria de casos puntuales de homologacion

Fecha del corte autenticado: miercoles 12 de agosto de 2026.

Objetivo: revisar uno por uno los casos visibles de homologacion entre `Compras`, `Ventas Mayoreo` y `Finanzas` sin tocar datos, sin correr resincronizaciones masivas y sin mover el catalogo global.

## Regla de seguridad

- No homologar ids en lote.
- No correr `saveCatalogSnapshot` como solucion rapida.
- No mover `compras_counterparties`, `mayoreo_counterparties` ni `finanzas_catalog_companies` para resolver un solo proveedor.
- Si un caso vuelve a fallar, atacarlo por flujo puntual o por empresa puntual.

## Matriz puntual

### 1. AVON

- Finanzas directorio: `compras_co_1779230989617207`
- Finanzas catalogo: `compras_co_1779230989617207`
- Compras: `cp_import_avon`
- Ventas Mayoreo: no aplica en este corte
- Facturas en Finanzas: `27`
- Facturas abiertas en Finanzas: `12`
- Saldo abierto en Finanzas: `607,533.50`
- Convenios en Finanzas: `0`

Lectura:

- En Finanzas el id de trabajo ya esta alineado entre directorio y catalogo.
- El desfase existe contra el id historico de Compras, no dentro del camino activo de Finanzas.
- Es un caso operativo sensible porque tiene saldo abierto alto y `payment_stage = CONVENIO`.

Decision segura:

- No homologar ids de forma global.
- Mantener a Finanzas como canonico para flujos de convenio y cuentas por proveedor.
- Si vuelve a fallar el convenio, revisar validacion o guardado de ese flujo puntual.

### 2. KS

- Finanzas directorio: `ventas_co_seed_ks`
- Finanzas catalogo: `ventas_co_seed_ks`
- Compras: `cp_import_ks`
- Ventas Mayoreo: `co_seed_ks`
- Facturas en Finanzas: `5`
- Facturas abiertas en Finanzas: `3`
- Saldo abierto en Finanzas: `567,782.30`
- Convenios en Finanzas: `1`
- Monto restante en convenio activo: `567,782.30`

Lectura:

- Es el caso mas delicado despues de `AVON` porque ya mezcla saldo abierto y convenio activo.
- La identidad activa en Finanzas hoy esta resuelta hacia la rama de Ventas/Directo, no hacia Compras.
- Una homologacion agresiva aqui puede pegarle directo a presupuesto, centro de pagos y lectura de convenio.

Decision segura:

- No tocar ids.
- Si se necesita un ajuste futuro, debe ser empresa por empresa y validando primero facturas, convenio y centro de pagos.

### 3. TRUPER

- Finanzas directorio: `fc_1784306801560010`
- Finanzas catalogo: `fc_1784306801560010`
- Compras: `co_1785183511873247`
- Ventas Mayoreo: no aplica en este corte
- Facturas en Finanzas: `2`
- Facturas abiertas en Finanzas: `0`
- Saldo abierto en Finanzas: `0.00`
- Convenios en Finanzas: `0`

Lectura:

- Hoy no trae presion operativa en Finanzas.
- El desfase es de identidad contra Compras, no de operacion viva.

Decision segura:

- No mover nada mientras no vuelva a entrar operacion nueva.
- Si reaparece flujo activo, revisar antes de homologar.

### 4. PLASTICOS DE INGENIERIA MEXICANOS

- Finanzas directorio: no aparece activo
- Finanzas catalogo: `fc_import_plasticos_de_ingenieria_mexicanos`
- Compras: `co_1782160320540728`
- Ventas Mayoreo: no aplica en este corte
- Facturas en Finanzas: `3`
- Facturas abiertas en Finanzas: `0`
- Saldo abierto en Finanzas: `0.00`
- Convenios en Finanzas: `0`

Lectura:

- Es mas un residuo historico/importado que una urgencia operativa del dia.
- No aparece hoy en el directorio activo de Finanzas.

Decision segura:

- No tocar por ahora.
- Si vuelve a necesitarse en Finanzas, primero definir si debe vivir como `DIRECTO`, `COMPRAS` o quedar solo historico.

### 5. FERNANDO RUBIO

- Finanzas directorio: `ventas_co_seed_fernando_rubio`
- Finanzas catalogo: `ventas_co_seed_fernando_rubio`
- Compras: `cp_import_fernando_rubio`
- Ventas Mayoreo: no aparece activo en este corte
- Facturas en Finanzas: `0`
- Convenios en Finanzas: `0`

Lectura:

- La identidad activa de Finanzas hoy ya esta resuelta.
- El desfase restante es solo contra el origen de Compras.

Decision segura:

- No requiere accion inmediata.
- Solo vigilar si vuelve a entrar operacion por Compras y Finanzas al mismo tiempo.

### 6. RICARDO GARCIA MENDIETA

- Finanzas directorio: `ventas_co_seed_ricardo_garcia_mendieta`
- Finanzas catalogo: `ventas_co_seed_ricardo_garcia_mendieta`
- Compras: `cp_import_ricardo_garcia_mendieta`
- Ventas Mayoreo: `co_seed_ricardo_garcia_mendieta`
- Facturas en Finanzas: `0`
- Convenios en Finanzas: `0`

Lectura:

- Igual que `FERNANDO RUBIO`, hoy el riesgo es bajo porque no trae saldo ni convenios.
- El desfase es de procedencia, no de operacion.

Decision segura:

- Sin accion inmediata.
- Revisar solo si entra a flujo financiero activo.

### 7. YOROZU

- Finanzas directorio: `ventas_co_seed_yorozu`
- Finanzas catalogo: `ventas_co_seed_yorozu`
- Compras: `cp_import_yorozu`
- Ventas Mayoreo: `co_seed_yorozu`
- Facturas en Finanzas: `0`
- Convenios en Finanzas: `0`

Lectura:

- Existe desfase entre las ramas de origen, pero no hay operacion financiera abierta hoy.

Decision segura:

- Mantener sin cambios.
- Revisar solo si empieza a generar saldo, facturas o convenios.

### 8. QUERETANA CARRILLO

- Finanzas directorio: no aparece
- Finanzas catalogo: no aparece
- Compras: no aparece en el cruce revisado
- Ventas Mayoreo: `co_1786547367751754`
- Facturas en Finanzas: `0`
- Convenios en Finanzas: `0`

Lectura:

- Este es el unico faltante real por nombre frente a Ventas Mayoreo en el corte.
- No es un problema operativo actual de Finanzas porque todavia no vive ahi.

Decision segura:

- No crearla en Finanzas solo por homologacion preventiva.
- Darla de alta en Finanzas solo cuando exista necesidad operativa real.

### 9. DESPERDICIOS QUERETANA PATIO-MICHEL

- Finanzas directorio: no aparece
- Finanzas catalogo: `co_1785443736030589`
- Compras: no aplica en este corte
- Ventas Mayoreo: `co_1785443736030589`
- Facturas en Finanzas: `0`
- Convenios en Finanzas: `0`

Lectura:

- Aqui no falta la empresa; lo raro es que el id en Finanzas no trae el prefijo tipico `ventas_`.
- Aun asi, hoy no tiene operacion financiera abierta.

Decision segura:

- No tocar mientras siga sin flujo en Finanzas.
- Si se activa financieramente, revisar si conviene normalizarla o solo respetar el id vigente.

## Prioridad de vigilancia

- Alta: `AVON`, `KS`
- Media: `TRUPER`
- Baja: `PLASTICOS DE INGENIERIA MEXICANOS`, `FERNANDO RUBIO`, `RICARDO GARCIA MENDIETA`, `YOROZU`
- Preventiva: `QUERETANA CARRILLO`, `DESPERDICIOS QUERETANA PATIO-MICHEL`

## Conclusion

Los hallazgos del 12 de agosto de 2026 no justifican una homologacion masiva. La recomendacion segura es sostener el criterio de correccion puntual por empresa y dejar quietos los catalogos globales hasta que un caso concreto exija cambio aprobado.
