# Especificacion Catalogo Materiales V2

Este documento fija el modelo funcional acordado para materiales en la app.

## Modelo

- `material_general`: catalogo corto de familias base.
- `material_comercial`: catalogo amplio de nombres reales de compra, produccion y venta.
- `inventario_general`: saldo de materia prima o material base.
- `inventario_comercial`: saldo clasificado de patio.

## Regla operativa

1. Una entrada comercial suma a un `material_general`.
2. Una transformacion consume `material_general` y produce `material_comercial`.
3. Una salida comercial descuenta de `inventario_comercial`.
4. Aperturas y cortes deben contemplar ambos niveles:
   - general
   - comercial

## Criterios de clasificacion

- `general_input`: se usa para entradas que alimentan el material general base.
- `classified_stock`: representa material clasificado que puede existir en patio.
- `legacy_alias`: codigo heredado que no debe usarse en el modelo nuevo.

## Archivos fuente

- Catalogo general: [catalogo_material_general_v2.csv](/Users/martinvelzat/DICSA/apps/dicsa_operacion/docs/operacion/catalogo_material_general_v2.csv)
- Catalogo comercial: [catalogo_material_comercial_v2.csv](/Users/martinvelzat/DICSA/apps/dicsa_operacion/docs/operacion/catalogo_material_comercial_v2.csv)

## Notas

- El CSV historico original se uso solo como fuente de nombres reales del negocio.
- Las relaciones antiguas `inventory_material` y `material_id` del modelo previo no deben heredarse como verdad funcional.
- Los registros `legacy_alias` pueden conservarse para migracion, pero no deben exponerse en captura nueva.
