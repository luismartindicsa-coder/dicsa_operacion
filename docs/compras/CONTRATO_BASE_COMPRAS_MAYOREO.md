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
- familia cromática `negro / plateado / blanco`
- atmósfera general
- background
- composición de header
- color del título superior
- `super glass` oscuro para cards, grids, side panel y botones
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
- Si una pantalla introduce rojo como color dominante del área, debe asumirse incorrecta salvo que represente un estado puntual y no identidad visual.

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

En el estado actual de `Compras Mayoreo`, el contrato funcional ya queda validado al 100% para:

- `Catálogo Compras Mayoreo`

Eso significa:

- el catálogo es la fuente de verdad para layout operativo del área
- cualquier nueva pantalla debe copiar primero ese nivel de claridad y densidad
- las demás páginas del área se depuran contra ese contrato, no al revés

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

Alcance aprobado para `Dashboard Compras Mayoreo`:

- funcionar como hub ejecutivo y de navegación
- dar acceso rápido a `Catálogo`, `Tickets`, `Ajuste de precios`, `Directorio Proveedores` y cruce con `Finanzas`
- evitar KPIs o widgets decorativos que todavía no tengan definición operativa real
- reservar el detalle operativo para cada módulo especializado

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

## Blueprint: Dashboard Compras Mayoreo

El `Dashboard Compras Mayoreo` no debe comportarse como una pantalla de accesos rápidos ni como una lista de pendientes aislados.

Su función válida es:

- servir como hub de toma de decisiones rápidas
- resumir la operación de compra en ventanas ejecutivas
- mostrar concentración por proveedor y material
- mostrar lectura de costo real contra precio vigente
- anticipar impacto de pago y desviaciones relevantes

Regla explícita:

- la navegación ya vive en el menú lateral
- el dashboard no debe repetir esa navegación como protagonista dentro del canvas
- si el dashboard se siente como una botonera, debe asumirse incorrecto

### Horizonte temporal correcto

`Compras Mayoreo` no se consolida por corte diario como `Menudeo`.

Por eso, la ventana primaria del dashboard debe ser:

- `mes actual`

Y como comparativos secundarios:

- `mes anterior`
- `últimos 90 días`

Regla explícita:

- no priorizar lectura “de hoy” como centro del dashboard
- si aparece una métrica diaria, debe ser apoyo puntual y no eje principal

### Estructura recomendada

#### 1. Fila superior: resumen mensual ejecutivo

Cards sugeridas:

- total comprado del mes
- kilogramos comprados del mes
- precio promedio ponderado del mes
- tickets de compra del mes
- proveedores con compra en el mes
- materiales comprados en el mes

Cada card debe ayudar a responder:

- cuánto se compró
- en qué volumen
- con qué intensidad operativa
- con qué nivel de costo promedio

#### 2. Bloque central: concentración por material

Debe mostrar:

- top materiales por kilogramos comprados
- top materiales por importe comprado
- precio promedio real por material en el mes
- participación de cada material dentro del total comprado

Preguntas que debe responder:

- qué materiales concentraron más compra
- cuánto costó realmente cada material
- qué materiales están jalando el gasto del mes

#### 3. Bloque central: concentración por proveedor

Debe mostrar:

- top proveedores por kilogramos comprados
- top proveedores por importe comprado
- precio promedio pagado por proveedor
- participación del proveedor dentro del total mensual

Preguntas que debe responder:

- a quién se le compró más
- quién concentra más volumen
- quién concentra más importe
- en qué proveedor está más caro o más barato el mes

#### 4. Bloque de lectura de precios

Debe mostrar:

- último precio vigente configurado por material
- precio promedio real pagado en el mes
- desviación entre precio vigente y precio realmente pagado
- materiales con sobreprecio aplicado
- materiales con mayor cambio vs mes anterior

Preguntas que debe responder:

- si la operación está comprando al precio esperado
- dónde ya se está pagando por arriba del vigente
- qué materiales están cambiando de costo y requieren decisión

#### 5. Bloque de alertas ejecutivas

Debe mostrar solo alertas que ayuden a decidir, por ejemplo:

- materiales con mayor subida de costo vs mes anterior
- proveedores con mayor concentración de compra
- compras relevantes con sobreprecio
- proveedores con compra activa y situación de pago delicada
- volumen importante comprado sin buena cobertura financiera

Regla explícita:

- `tickets pendientes`, `sin factura` o `sin pago` pueden existir como alertas secundarias
- no deben ser el centro conceptual del dashboard

#### 6. Bloque de cruce con Finanzas

Debe resumir:

- monto pendiente de pago por proveedor
- concentración de pagos próximos
- compras del mes que ya comprometen flujo
- proveedores relevantes con crédito activo o presión de pago

Objetivo:

- conectar compras con decisión financiera
- no obligar al usuario a saltar de inmediato a otra pantalla para entender el riesgo

### Comparativos válidos

Los comparativos más útiles para `Compras Mayoreo` son:

- mes actual vs mes anterior en importe
- mes actual vs mes anterior en kilogramos
- mes actual vs mes anterior en precio promedio ponderado
- cambio de participación por proveedor
- cambio de participación por material

### Información que no debe dominar el dashboard

No conviene que el dashboard se centre en:

- navegación repetida a módulos
- botonera superior extensa
- métricas decorativas sin decisión asociada
- lectura diaria tipo corte
- widgets genéricos de “pendientes” sin contexto de costo, volumen o concentración

### Traducción práctica a layout

Layout recomendado:

1. fila superior con `6 KPI cards mensuales`
2. segunda fila con `compras por material` y `compras por proveedor`
3. tercera fila con `precio promedio real vs vigente` y `alertas ejecutivas`
4. bloque final con `cruce con finanzas`

### Fuente de verdad operativa

El dashboard debe construirse con datos reales derivados de:

- `Tickets Compras`
- `Catálogo Compras`
- `Ajuste de precios`
- `Directorio Proveedores`
- relaciones con `Finanzas`

Eso implica que los cálculos más valiosos saldrán de:

- proveedor
- material
- precio
- sobreprecio
- peso pagable
- importe
- factura
- pago
- situación de pago del proveedor

### Criterio final de validación

El `Dashboard Compras Mayoreo` queda bien resuelto si permite responder rápido:

- cuánto se compró este mes
- qué material concentró más compra
- con qué proveedor se compró más
- a qué precio real se compró
- dónde estamos pagando arriba del vigente
- qué combinación proveedor/material está empujando el costo
- qué parte de esa compra ya compromete flujo o pago
