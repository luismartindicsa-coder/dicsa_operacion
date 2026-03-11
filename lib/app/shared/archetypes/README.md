# Archetypes

Infraestructura reusable por arquetipo funcional.

Cada pagina nueva debe declarar su arquetipo antes de implementarse.

## Primera fase

- `grid_editable`
- `grid_editable_tabbed`
- `auxiliary_surfaces`
- `workflow_master_detail`
- `dashboard`
- `operacion_hibrida_tabs`

Las demas capas pueden agregarse despues sin romper esta estructura.

## Regla de adopcion

- pantallas existentes: solo fixes puntuales
- pantallas nuevas: uso obligatorio del arquetipo correspondiente
- si existe wrapper oficial del arquetipo, no se reimplementa desde cero

## Capas previstas

- `grid_editable`
- `grid_editable_tabbed`
- `workflow_master_detail`
- `operacion_hibrida_tabs`
- `dashboard`
- `auxiliary_surfaces`

## Fuente de verdad

El contrato funcional sigue viviendo en:

- `app_ui/DICSA_APP_UI_STANDARD.md`
- `app_ui/NEW_ARCHETYPE_PAGE_TEMPLATE.md`
- `app_ui/ARCHETYPE_IMPLEMENTATION_BLUEPRINT.md`
- `app_ui/UI_CONTRACT_IMPLEMENTATION_BACKLOG.md`
- `archetypes/ARCHETYPE_ADOPTION_GUIDE.md`

Esta carpeta es la bajada ejecutable de esos contratos para nuevas paginas.

## Estado actual

- `grid_editable`: fuerte
- `auxiliary_surfaces`: fuerte
- `grid_editable_tabbed`: fuerte
- `workflow_master_detail`: media-alta
- `dashboard`: media-alta
- `operacion_hibrida_tabs`: media
