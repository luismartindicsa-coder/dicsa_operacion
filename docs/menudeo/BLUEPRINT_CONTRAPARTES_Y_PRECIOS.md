# Menudeo: Contrapartes y Precios

## Objetivo

Definir una sola superficie operativa para administrar:

- contrapartes de menudeo
- materiales que manejan
- precio final por material

sin volver rígida la captura ni depender de relaciones perfectas para seguir operando.

## Principio base

Tomar la misma filosofía de `Entradas y salidas`:

- usar catálogo vivo cuando ayuda
- guardar snapshot textual cuando protege la operación
- permitir editar, agregar, desactivar y volver a capturar sin bloquear al usuario

## Superficie propuesta

Una sola página:

- `Contrapartes y precios`

Arquetipo sugerido:

- `Grid con panel lateral` o `híbrido`

## Qué resuelve esta página

Desde una sola vista el usuario con permiso debe poder:

- crear una contraparte nueva
- editar contraparte existente
- desactivar contraparte
- asignar o corregir su grupo
- agregar materiales
- agregar nuevos precios
- corregir precios
- desactivar precios viejos
- capturar materiales nuevos mediante alias si todavía no están perfectos en catálogo

## Modelo de datos simplificado

### `men_counterparties`

Guarda la contraparte comercial.

Campos clave:

- `site_id`: relación opcional al catálogo corporativo
- `name`: snapshot principal visible para operación
- `kind`: `supplier`, `customer` o `both`
- `group_code`: clasificación simple como `general`, `triciclo`, `preferencial`
- `is_active`

### `men_material_aliases`

Permite capturar nombres operativos o duplicados normalizados sin frenar la operación.

Campos clave:

- `general_material_id` opcional
- `commercial_material_id` opcional
- `label`
- `normalized_label`
- `is_active`

### `men_counterparty_material_prices`

Guarda el precio final que realmente usará caja.

Campos clave:

- `counterparty_id`
- `general_material_id` opcional
- `commercial_material_id` opcional
- `material_alias_id` opcional
- `material_label_snapshot`
- `final_price`
- `is_active`

## Regla de operación

Para la captura futura de tickets:

1. seleccionar contraparte
2. seleccionar material
3. buscar precio final activo para esa combinación
4. si no existe relación exacta, usar el snapshot o alias si está definido
5. si no hay precio, avisar y permitir corregir desde administración

## Qué sí debe permitirse

- relacionar una contraparte con `sites` si ya existe
- capturar contraparte nueva aunque todavía no exista en `sites`
- relacionar un precio con material general o comercial
- usar alias temporal si el material todavía no está fino en catálogo
- desactivar sin borrar cuando ya no se use

## Qué se evita

- obligar a relaciones perfectas para poder operar
- multiplicar páginas para segmentos, ajustes, listas y excepciones
- hacer que el usuario normal entienda fórmulas o capas de precio

## Permisos mínimos

### Usuario operativo autorizado

- alta de contraparte
- edición de contraparte
- alta de precio
- edición de precio
- desactivación

### Supervisor o administración

- lo anterior
- depuración de alias
- homologación con catálogo corporativo

## Decisiones futuras compatibles

Este modelo permite después agregar sin romper:

- historial de precios
- reglas de grupo
- precios especiales
- conciliación contra tickets de caja

pero no obliga a construir eso desde el inicio.
