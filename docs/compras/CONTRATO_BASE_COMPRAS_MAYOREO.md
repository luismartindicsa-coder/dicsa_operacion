# Contrato Base: Compras Mayoreo

Este documento fija el contrato operativo para construir nuevas páginas dentro del área `Compras Mayoreo` sin mezclar referencias ni reinterpretar visuales por pantalla.

## Regla madre

Cuando se pida:

`copia esta página de referencia pero con el contexto y contrato de compras`

la traducción obligatoria es:

1. Copiar de la página de referencia:
   - funcionamiento
   - layout
   - flujo interno
   - relaciones entre bloques
   - descubribilidad de acciones
   - comportamiento de mouse, teclado, foco, hover, selección, drag y menús
2. Aplicar el contrato visual del área `Compras Mayoreo` usando como fuente de verdad:
   - `Catálogo Compras Mayoreo`
3. Aplicar el contrato del menú de navegación usando como fuente de verdad:
   - `Dashboard Compras Mayoreo`
4. Conectar el contexto de negocio real del área `Compras`:
   - proveedores
   - materiales
   - precios
   - tickets
   - directorio
   - relaciones futuras con finanzas

## Contrato visual del área

La página maestra para congelar la identidad visual de `Compras Mayoreo` es:

- `Catálogo Compras Mayoreo`

Todo módulo nuevo de `Compras Mayoreo` debe heredar de ahí:

- paleta del área
- atmósfera general
- background
- composición de header
- color del título superior
- glass cards
- side panel
- nav items
- botones de header
- botones principales/secundarios
- sombras
- badges
- contraste base
- densidad visual
- espaciado general

Regla explícita:

- Si una página nueva de `Compras` se ve distinta a `Catálogo Compras` en color, header, side panel, botones o superficies, debe asumirse incorrecta hasta demostrar que esa diferencia responde a una necesidad real del módulo.

## Contrato de navegación

La página maestra para congelar el comportamiento y visual del menú de navegación de `Compras Mayoreo` es:

- `Dashboard Compras Mayoreo`

Todo módulo nuevo de `Compras Mayoreo` debe heredar de ahí:

- botón `Navegación`
- tamaño y estilo de botones del header
- apertura/cierre del panel
- distribución del side panel
- títulos de secciones
- estructura `AREA / ACCESOS`
- acceso cruzado solo por `Dashboard Finanzas`
- accesos a `Dashboard Dirección` cuando el perfil lo permita

Regla explícita:

- El menú lateral de una página nueva de `Compras` no se diseña desde cero.
- Se copia del `Dashboard Compras` y solo se cambia qué item queda activo y qué páginas del área aparecen listadas.

## Contrato de interacción

La referencia de interacción base para páginas tipo grid dentro de `Compras Mayoreo` sigue siendo el contrato global reusable de DICSA.

Pero en términos prácticos, cualquier pantalla nueva del área debe respetar:

- hover
- foco
- teclado
- click simple
- `Cmd/Ctrl + click`
- `Shift + click`
- drag selection
- click derecho
- `...`
- edición inline o modal
- filtros
- popups
- pickers
- refresh silencioso

Regla explícita:

- Si la página de referencia ya resuelve una interacción, primero se copia esa interacción.
- No se inventa una variante “parecida” solo porque el área sea `Compras`.

## Contrato funcional de pantalla

La página de referencia elegida manda en:

- layout interno
- secuencia de trabajo
- bloques y jerarquía
- ubicación de acciones
- lógica de filtros
- forma de presentar historial, selección y vistas previas

Ejemplo:

- Si se pide `copia Ajuste de precios de Ventas Mayoreo pero con contexto de Compras`, entonces:
  - `Ajuste de precios Ventas Mayoreo` manda en layout, flujo y comportamiento
  - `Catálogo Compras` manda en visual del área
  - `Dashboard Compras` manda en navegación
  - `Compras` manda en proveedores/materiales/precios/historial

## Contexto de negocio

`Contexto de compras` no significa “hacer que se vea rojo/negro”.

`Contexto de compras` significa que la página debe usar entidades y relaciones reales del área:

- proveedores de `Compras`
- materiales de `Compras`
- precios vigentes de `Compras`
- historial de ajustes de `Compras`
- tickets de `Compras`
- navegación entre páginas de `Compras`

Regla explícita:

- El contexto de negocio se adapta.
- El funcionamiento y layout se clonan.
- El diseño del área se hereda.

## Modelo de lenguaje para coordinación

Para reducir ambigüedad, usar estas etiquetas:

### 1. Contrato visual del área

Es el look & feel del área.

Incluye:

- paleta
- background
- cards
- header
- side panel
- botones
- sombras
- tono tipográfico

En `Compras Mayoreo`, la referencia es:

- `Catálogo Compras Mayoreo`

### 2. Contrato de navegación

Es cómo se arma y se ve el menú lateral y los accesos globales.

Incluye:

- botón de navegación
- side panel
- `AREA`
- `ACCESOS`
- páginas visibles por área

En `Compras Mayoreo`, la referencia es:

- `Dashboard Compras Mayoreo`

### 3. Contrato de interacción

Es cómo usa la página el usuario.

Incluye:

- mouse
- teclado
- foco
- hover
- selección
- drag
- click derecho
- filtros
- menús
- edición

### 4. Contrato funcional

Es cómo está organizada la página y cómo fluye.

Incluye:

- layout
- jerarquía
- orden de bloques
- ubicación de acciones
- relaciones entre paneles
- secuencia operativa

### 5. Contexto de negocio

Es de dónde salen los datos y con qué se relacionan.

Incluye:

- proveedores
- materiales
- precios
- tickets
- finanzas
- directorio
- facturas

## Checklist de cierre para nuevas páginas de Compras

Una página nueva de `Compras Mayoreo` no debe considerarse homologada si falla cualquiera de estos puntos:

- Usa el contrato visual de `Catálogo Compras`.
- Usa el contrato de navegación de `Dashboard Compras`.
- Copia el funcionamiento de la página de referencia real.
- No introduce layout alterno sin razón fuerte.
- No mezcla paletas de otras áreas.
- No mezcla copy de ventas cuando el contexto es compras.
- No consume entidades ajenas al área si la pantalla es de compras.
- Si al comparar con `Catálogo Compras` hay diferencias visibles no justificadas en header, panel, botones o superficies, debe corregirse.
