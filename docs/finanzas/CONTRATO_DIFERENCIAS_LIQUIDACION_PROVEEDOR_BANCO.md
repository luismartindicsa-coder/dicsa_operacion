# Contrato: Diferencias de Liquidacion Proveedor vs Banco

Este documento define como debe comportarse `Cuentas Bancarias` cuando un pago ligado a `COMPRA_FACTURA` no coincide exactamente con el monto pendiente de la factura en `Cuentas por Proveedor`.

Se redacta como prerequisito para ejecutar los casos de `Monto diferente` y `diferencia de centavos` detectados en la conciliacion de [MATRIZ_EJECUCION_SEGURA_CONCILIACION_BANCARIA_2026-06-25.md](./MATRIZ_EJECUCION_SEGURA_CONCILIACION_BANCARIA_2026-06-25.md).

## Problema actual

Hoy la app trata `COMPRA_FACTURA` como liquidacion exacta:

- al elegir factura, el cargo se precarga con `invoice.balanceAmount`
- el campo `Cargo` queda bloqueado para `COMPRA_FACTURA`
- el guardado solo permite `debit_amount == invoice.balanceAmount`
- la capa de reglas vuelve a exigir liquidacion completa

Eso protege contra errores obvios, pero no soporta un caso real de operacion:

- la factura proveedor es el monto correcto a liquidar
- el banco refleja el dinero real transferido
- una persona puede redondear al pagar
- la diferencia puede ser de centavos y no debe romper ni banco ni proveedor

Tambien hay un riesgo tecnico importante:

- crear y borrar movimientos ligados si recalcula la factura proveedor
- editar un `COMPRA_FACTURA` ligado hoy no recalcula automaticamente la factura; hace solo `saveMovement(...)`

Por eso no debemos corregir estos casos forzando montos en banco ni editando linked rows con la logica actual.

## Estrategia de contencion

La implementacion debe ser lo mas puntual posible.

No debe tratarse como refactor general de `Finanzas`.

Principios de contencion:

- cambios aditivos, no destructivos
- comportamiento nuevo solo para `COMPRA_FACTURA`
- `VENTA_FACTURA` queda intacto
- `PAGO_FIJO` queda intacto
- `MANUAL` queda intacto
- `Compras` no cambia su modelo
- `Mayoreo / Ventas` no cambia su modelo

Decision clave:

- no relajar helpers genericos que hoy tambien protegen otros flujos
- en lugar de modificar la regla general de liquidacion exacta, crear una validacion nueva y especifica para diferencias pequenas en proveedor

## Radio de impacto real

### Escritura que si debe cambiar

Solo hay tres rutas de escritura que deben conocer la diferencia entre banco y proveedor:

1. creacion de `COMPRA_FACTURA` ligada
2. edicion de `COMPRA_FACTURA` ligada
3. borrado / reversa de `COMPRA_FACTURA` ligada

Archivos concentradores:

- `finanzas_bank_accounts_store.dart`
- `finanzas_bank_accounts_page.dart`

### Lectura que si debe ajustarse

Hay lectores secundarios que hoy asumen que `debit_amount` tambien es el monto aplicado a proveedor.

Esos lectores si deben usar `effectiveAppliedSupplierAmount`, no `debit_amount`, solo para casos ligados a factura proveedor:

- `finanzas_dashboard_page.dart`
- `finanzas_provider_accounts_page.dart`

### Superficies que deben quedar sin cambio funcional

Estas rutas no deben cambiar su comportamiento en fase 1:

- `mayoreo_accounts_page.dart`
- `mayoreo_dashboard_preview_page.dart`
- `finanzas_fixed_payments_store.dart`
- flujo `VENTA_FACTURA`
- flujo `PAGO_FIJO`
- movimientos `MANUAL`
- modelo de tickets de compras

Eso mantiene el radio de impacto confinado a proveedor + banco.

## Regla madre

La app debe guardar dos verdades distintas sin obligarlas a mentirse entre si:

- `Cuentas por Proveedor` es la verdad de la obligacion.
- `Cuentas Bancarias` es la verdad del efectivo real.

Si ambos montos difieren, la diferencia debe quedar explicita, trazable y reversible.

Regla operativa:

- nunca alterar el monto real del banco para que empate con proveedor
- nunca alterar el saldo de proveedor para que empate con banco sin registrar la diferencia
- nunca crear movimientos bancarios falsos de centavos para "cuadrar"

## Alcance aprobado para Fase 1

La fase 1 existe para desbloquear la conciliacion delicada de centavos sin abrir de golpe todos los casos contables posibles.

Si entra en fase 1:

- diferencias pequenas en `COMPRA_FACTURA`
- objetivo principal: centavos y redondeos operativos
- alta nueva de pago ligado con diferencia pequena
- edicion segura de pago ligado existente
- reversa segura del pago ligado

No entra todavia en fase 1:

- descuentos negociados complejos
- retenciones fiscales
- sobrepagos materiales
- anticipos de proveedor como subflujo completo
- aplicacion de un solo pago a multiples facturas proveedor

## Umbral operativo

Se propone un umbral maximo de diferencia permitido en fase 1:

- `abs(diferencia) <= 1.00`

La diferencia debe entenderse asi:

```text
diferencia = applied_supplier_amount - debit_amount
```

Ejemplos:

- factura `9,383.01`, banco `9,383.00` -> diferencia `+0.01`
- factura `13,850.00`, banco `13,850.01` -> diferencia `-0.01`

Regla:

- si `abs(diferencia) <= 1.00`, la app puede permitir cerrar la factura con motivo obligatorio
- si `abs(diferencia) > 1.00`, la app debe bloquear el cierre automatico en fase 1

## Modelo de datos propuesto

Agregar a `public.finanzas_bank_movements`:

- `applied_supplier_amount numeric(14,2)`
- `settlement_difference_amount numeric(14,2) not null default 0`
- `settlement_difference_reason text`
- `settlement_difference_note text`

Sentido de los campos:

- `debit_amount`: monto real salido del banco
- `applied_supplier_amount`: monto aplicado a la factura proveedor
- `settlement_difference_amount`: `applied_supplier_amount - debit_amount`
- `settlement_difference_reason`: motivo del delta
- `settlement_difference_note`: comentario corto libre cuando haga falta

Catalogo minimo de motivos para fase 1:

- `REDONDEO_OPERATIVO`
- `AJUSTE_CENTAVOS_AUTORIZADO`
- `ERROR_CAPTURA_EN_REVISION`

Regla de compatibilidad hacia atras:

- si `applied_supplier_amount` es `null`, el sistema debe asumir `debit_amount`
- eso hace que los movimientos historicos exactos sigan funcionando sin cambio de comportamiento

## Reglas de negocio

Para un movimiento `COMPRA_FACTURA`:

1. `debit_amount` siempre representa el banco real.
2. `applied_supplier_amount` representa lo que se descuenta de la factura.
3. la factura proveedor cambia de saldo usando `applied_supplier_amount`, no `debit_amount`
4. la diferencia solo se permite en fase 1 si:
   - la factura esta abierta
   - existe motivo
   - `abs(diferencia) <= 1.00`
5. si la diferencia excede el umbral, la factura debe quedar bloqueada para este flujo y escalarse a un tratamiento posterior

Estados esperados:

- si el nuevo `balanceAmount <= 0.009`, la factura queda `PAGADA`
- si aun queda saldo, la factura queda `PARCIAL` o `VENCIDA` segun corresponda

## Regla de cierre en fase 1

Fase 1 no debe abrir una contabilidad paralela completa.

Su regla es mas acotada:

- se permite que la factura quede `PAGADA` usando `applied_supplier_amount`
- el banco conserva el monto real
- la diferencia queda visible como delta de liquidacion

Esto resuelve los casos de conciliacion por centavos sin inventar efectivo ni distorsionar la factura.

## Flujo UI propuesto

Cuando el usuario seleccione `COMPRA_FACTURA`, el modal debe mostrar:

- `Saldo factura`
- `Cargo banco real`
- `Aplicar a factura`
- `Diferencia`
- `Motivo de diferencia`
- `Nota`

Comportamiento:

- por default `Cargo banco real` y `Aplicar a factura` se cargan iguales al saldo de la factura
- si el usuario cambia `Cargo banco real`, la UI recalcula la diferencia en vivo
- si la diferencia es `0`, no pide motivo
- si la diferencia es distinta de `0`, pide motivo obligatorio
- si la diferencia rebasa `1.00`, el boton guardar debe quedar bloqueado en fase 1

## Edicion segura de movimientos ligados

No debe reutilizarse la ruta generica de `saveMovement(...)` para cambiar montos de un `COMPRA_FACTURA` ligado.

Se necesita una ruta dedicada equivalente a la que ya existe para `VENTA_FACTURA`.

Metodo nuevo propuesto en store:

```dart
updateMovementAndApplySupplierSettlement({
  required FinanzasBankMovementRecord previousMovement,
  required FinanzasBankMovementRecord nextMovement,
});
```

Esa ruta debe:

1. cargar la factura ligada anterior
2. revertir el efecto anterior usando `previousAppliedSupplierAmount`
3. guardar el nuevo movimiento
4. aplicar el nuevo efecto usando `nextAppliedSupplierAmount`
5. recalcular `status` y `balanceAmount`
6. resincronizar el estado del proveedor
7. mantener consistencia con tickets ligados a la factura

## Reversa segura

Cuando se borre un `COMPRA_FACTURA` ligado:

- no debe revertirse por `debit_amount`
- debe revertirse por `effectiveAppliedSupplierAmount`

Regla de compatibilidad:

```text
effectiveAppliedSupplierAmount =
  applied_supplier_amount ?? debit_amount
```

Eso evita abrir mal una factura que se habia cerrado con diferencia de centavos.

## Validaciones tecnicas obligatorias

Validaciones nuevas:

- `COMPRA_FACTURA` puede guardar con diferencia solo si existe motivo
- `settlement_difference_amount` debe ser consistente con `applied_supplier_amount - debit_amount`
- si `sourceType != COMPRA_FACTURA`, estos campos deben quedar vacios o en cero
- la UI no debe permitir abono y cargo simultaneo
- la ruta de edicion no debe permitir cambiar la factura ligada sin reversion y reaplicacion controlada

Validaciones que deben dejar de ser exactas solo para proveedor:

- `_canSave` en `finanzas_bank_accounts_page.dart`
- nueva validacion especifica para proveedor en `finanzas_financial_rules.dart`

En lugar de exigir igualdad exacta para `COMPRA_FACTURA`, deben validar:

- igualdad exacta, o
- diferencia pequena autorizada con motivo

Regla de contencion:

- `assertFullSettlementAmount(...)` debe permanecer exacta para flujos existentes como `PAGO_FIJO`
- no debe reaprovecharse para diferencias de proveedor
- debe agregarse un helper nuevo, por ejemplo `assertSupplierSettlementAmountAllowed(...)`

## Endurecimiento recomendado

Dado que esta pantalla esta conectada con proveedor, tickets y conciliacion, la ruta segura recomendada es:

1. encapsular crear, editar y borrar `COMPRA_FACTURA` en metodos dedicados del store
2. evitar que la UI haga upserts directos sobre linked rows de proveedor
3. en una fase posterior, mover esta logica a una RPC transaccional en Supabase

La RPC no es requisito para desbloquear los centavos de hoy, pero si seria la capa correcta para endurecer el proceso antes de volumen alto de correcciones.

## Impacto esperado en conciliacion

Con este contrato implementado, los casos de `Monto diferente` deben partirse asi:

- si la diferencia es `<= 1.00` y el linkage es correcto:
  - se puede editar o crear el `COMPRA_FACTURA` con delta autorizado
- si la diferencia es `> 1.00`:
  - no se toca todavia dentro del bloque seguro
  - se manda a un flujo posterior de descuento, retencion, anticipo o revision

Regla operativa para la conciliacion actual:

- primero implementar este contrato
- despues ejecutar los casos de centavos y monto pequeno
- al final volver a correr el cuadre bancario

## Casos de prueba minimos

1. Pago exacto.
   - factura `10,000.00`
   - banco `10,000.00`
   - factura queda `PAGADA`
   - diferencia `0.00`

2. Banco menor por centavos.
   - factura `9,383.01`
   - banco `9,383.00`
   - aplicar `9,383.01`
   - diferencia `+0.01`
   - motivo `REDONDEO_OPERATIVO`
   - factura queda `PAGADA`
   - banco conserva `9,383.00`

3. Banco mayor por centavos.
   - factura `13,850.00`
   - banco `13,850.01`
   - aplicar `13,850.00`
   - diferencia `-0.01`
   - motivo `AJUSTE_CENTAVOS_AUTORIZADO`
   - factura queda `PAGADA`

4. Reversa de pago con diferencia.
   - borrar el movimiento del caso 2
   - la factura debe reabrirse por `9,383.01`
   - no por `9,383.00`

5. Edicion de pago ligado con diferencia.
   - un movimiento exacto se edita a diferencia `+0.01`
   - la factura no debe duplicar descuento ni quedar sobrepagada

6. Bloqueo por exceso.
   - factura `50,000.00`
   - banco `49,995.00`
   - diferencia `+5.00`
   - fase 1 debe bloquear guardar como cierre automatico

## Plan de implementacion sugerido

1. Migracion de base aditiva para campos de delta.
2. Helpers nuevos y especificos en `finanzas_financial_rules.dart`:
   - resolver `effectiveAppliedSupplierAmount`
   - validar diferencia pequena de proveedor
3. Ajuste de `FinanzasBankMovementRecord` y serialization con campos opcionales.
4. Ruta nueva `createMovementAndApply` para usar `applied_supplier_amount` solo en proveedor.
5. Ruta nueva `updateMovementAndApplySupplierSettlement(...)`.
6. Ajuste de `deleteMovementAndReverse(...)` usando `effectiveAppliedSupplierAmount`.
7. Ajuste puntual de lectores secundarios en:
   - `finanzas_dashboard_page.dart`
   - `finanzas_provider_accounts_page.dart`
8. UI de `COMPRA_FACTURA` con `Cargo banco real`, `Aplicar a factura`, `Diferencia`, `Motivo`.
9. Mantener `Payment Center` en modo exacto en fase 1 para no abrir otro frente.
10. Pruebas manuales con los casos minimos y un smoke test de ventas / pagos fijos.
11. Solo despues ejecutar los movimientos de conciliacion que hoy difieren por centavos.

## Decision operativa

Antes de aplicar cambios para cuadrar cuentas:

- si el caso es `cuenta equivocada`, `fecha diferente` o `faltante manual`, puede seguir su ruta normal
- si el caso toca monto de un `COMPRA_FACTURA` ligado, debe esperar a esta implementacion

Esa separacion evita una cascada de errores entre:

- `Cuentas Bancarias`
- `Cuentas por Proveedor`
- tickets ligados a factura
- conciliacion final por cuenta bancaria
