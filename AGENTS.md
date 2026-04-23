# Contrato Frontend Base (DICSA App)

Estas reglas son obligatorias para cualquier cambio de frontend en módulos tipo grid/tabla.

## Regla Base de Paridad (obligatoria)
Para cualquier módulo nuevo o refactor de módulo existente (ej. Pesadas, Servicios, Producción, Entradas/Salidas):

1. Primero clonar 1:1 el comportamiento funcional base de `Entradas y Salidas`.
2. Después adaptar únicamente columnas/campos del módulo.
3. Nunca rediseñar ni reinterpretar la interacción base.

### Excepción declarada: Ventas Mayoreo

Para páginas del área `Ventas Mayoreo` con flujo comercial tipo catálogo/precios/reportes/flujo de efectivo:

1. La referencia principal de secuencia de trabajo, organización comercial y modelado operativo es `Menudeo`.
2. La referencia secundaria obligatoria para foco, hover editable, click, selección, teclado, edición inline y refresh silencioso sigue siendo `Entradas y Salidas`.
3. `Ventas Mayoreo` no puede copiar la interacción base de `Menudeo` si eso rompe la paridad de grid ya homologada en `Entradas y Salidas`.
4. `Ventas Mayoreo` usa paleta amarilla del área por tokens semánticos; no por colores hardcodeados en widgets.

### Regla de Clonado Máximo: Ventas Mayoreo

Para cualquier página nueva de `Ventas Mayoreo`, la postura por defecto no es “reinterpretar Menudeo”, sino `clonar Menudeo al máximo` y después sustituir solo lo estrictamente necesario.

Orden obligatorio:

1. Primero identificar la página equivalente más cercana en `Menudeo`.
2. Clonar 1:1 su estructura visual, jerarquía, navegación, top bar, cards, tabs, distribución, insert row, headers, fila, slot de acciones y copy operativo base.
3. Cambiar únicamente:
   - paleta del área a tokens `Mayoreo`
   - entidades/campos propios de `Mayoreo`
   - reglas de negocio donde `Mayoreo` difiera realmente de `Menudeo`
4. Solo después validar la interacción base contra `Entradas y Salidas` y corregir ahí foco, teclado, hover editable, selección, multiedición, click derecho y refresh si hiciera falta.

Regla explícita:
- Si una pieza ya existe en `Menudeo` y cumple la misma función en `Mayoreo`, debe copiarse antes de intentar rediseñarla.
- Cualquier desviación visual, estructural o de comportamiento respecto a `Menudeo` debe asumirse incorrecta hasta demostrar que responde a una diferencia real del módulo o a una obligación contractual del grid.
- Si hay conflicto entre “verse como Menudeo” y “comportarse como grid homologado”, domina `Entradas y Salidas` en interacción, pero domina `Menudeo` en composición, secuencia comercial y descubribilidad.

## Comportamientos que deben clonarse 1:1 antes de personalizar
- Foco y edición:
  - Click simple en `TextField` debe permitir escribir al primer click (sin perder caret).
  - No se permite requerir doble click para escribir.
  - Evitar rebuilds estructurales que roben foco al activar celda.
- Teclado:
  - `Enter` y `Esc` deben funcionar igual que en Entradas/Salidas para edición/guardar/cancelar.
  - `Delete`/`Backspace` dentro de inputs editables borran texto, no disparan eliminar fila.
- Grid interactions:
  - Selección simple/múltiple, hover, fila activa, edición de celdas y navegación por teclado deben comportarse igual.
- Refresh:
  - Priorizar recarga automática con las mismas reglas de defer/sincronización de Entradas/Salidas.
  - No agregar botón manual de recarga salvo requerimiento explícito del usuario.
 - UI contract:
  - Mantener diseño, paleta, sombras, estados hover/selected, diálogos y filtros exactamente alineados a Entradas/Salidas.
  - Si la página pertenece a un área distinta (`Ventas`, `Finanzas`, `RH`, etc.), mantener fijo todo el lenguaje visual base y cambiar únicamente la gama cromática mediante tokens semánticos de área.
  - No hardcodear colores por componente; el color del área debe entrar por contrato de tema, no por reinterpretación local.
  - En `Ventas Mayoreo`, la secuencia de trabajo y el modelado comercial deben parecerse primero a `Menudeo`; la interacción base del grid debe parecerse primero a `Entradas y Salidas`.
  - Cuando un campo represente una clasificación operativa o comercial estable (`grupo de contraparte`, `tipo de movimiento`, `familia contractual`, etc.), debe modelarse como catálogo controlado/picker y no como texto libre.
  - En Menudeo, el grupo de contraparte queda homologado como catálogo controlado con estas opciones base: `PUBLICO GENERAL`, `PROVEEDOR GRANDE`, `TRICICLOS`.
  - En Menudeo, los ajustes de precio siempre se aplican sobre el precio vigente actual; el nuevo resultado absorbe al anterior y se convierte en la nueva base operativa.
  - El historial de precios debe separarse del precio vigente: no recalcular desde una base congelada ni reaplicar alzas viejas ya absorbidas.
  - El hover editable debe vivir en la celda, no en toda la fila: debe sobresalir visualmente como cápsula local, ganar color/tinte del área, crecer levemente y empujar/acomodar la fila sin romper su altura o ancho contractual.
  - Ese comportamiento de hover editable debe ser idéntico entre módulos tipo grid; solo cambia la paleta por tokens de área.
  - Las celdas del grid deben conservar separadores verticales contractuales entre columnas cuando el arquetipo los use; esos separadores deben desvanecerse en la fila cuando una celda editable entra en hover o edición activa, para que la cápsula no parezca “comerse” la línea.
 - Ancho de filas y overflow:
   - La fila de datos debe ocupar exactamente la misma huella horizontal que el `insert row` dentro del mismo módulo.
   - El ancho efectivo de headers, `insert row` y filas renderizadas debe salir de la misma fuente de verdad; no recalcular cada capa con paddings distintos.
   - El contrato reusable base para grids debe vivir en componentes compartidos; no volver a codificar localmente la estructura de escalado o el slot de acciones en cada página.
   - Para el escalado estructural del row, usar el patrón compartido equivalente a `Card -> Padding -> ContractGridScaledRow -> Row(mainAxisSize: MainAxisSize.min, children: [...])`.
   - Para columnas con acción final (`...`, `Agregar`, `Estado + acción`), reservar el slot con un componente compartido tipo `AnchoredActionSlot`: contenido principal a la izquierda y acción anclada a la derecha, sin overlap.
   - Los overflows se atacan primero revisando desalineación de ancho estructural entre header/insert/grid y luego celdas compactas que intentan meter más contenido del que cabe; no se resuelven a prueba y error con offsets locales.
   - Controles compactos (`Switch`, menú `...`, badges, acciones`) dentro de celdas angostas no deben acompañarse de texto adicional si eso rompe el ancho contractual.

## Criterio de aceptación
Un módulo nuevo se considera terminado solo si es réplica funcional y visual de Entradas/Salidas en interacción (mouse/teclado/foco) y estilo, cambiando únicamente los campos propios del módulo.

## Cierre contractual Menudeo
Antes de dar por cerrada una página de Menudeo, validar explícitamente este checklist sobre la propia pantalla:

- Shell, glass y navegación:
  - El header usa el mismo lenguaje glass del sistema.
  - El botón de navegación abre panel/overlay; no es solo un back temporal.
  - Hover de botones y tiles de navegación debe levantar visualmente la pieza: leve escala, desplazamiento vertical y sombra más profunda.
  - `Esc` debe cerrar paneles, menús y overlays abiertos.
- Grid:
  - Header, `insert row`, filas normales y filas en edición comparten la misma huella horizontal.
  - No hay overflow residual en acciones, switches, badges, menús `...` ni celdas compactas.
  - El hover editable existe solo en celdas realmente editables.
  - El hover editable sobresale como cápsula local y la fila se acomoda sin romper layout.
- Mouse:
  - Click simple selecciona.
  - `Cmd/Ctrl + click` agrega o quita de selección.
  - `Shift + click` extiende rango cuando aplique.
  - Drag selection puede seguir bajando filas y hacer autoscroll.
  - Click derecho respeta la selección activa y el menú `...` opera sobre ella.
  - Click afuera cancela edición inline o multiedición sin guardar.
- Teclado:
  - Flechas navegan entre celdas del `insert row`.
  - `ArrowDown` baja del `insert row` al grid.
  - `ArrowUp` desde la primera fila visible puede regresar al `insert row`.
  - Al retomar navegación con flechas después de scroll, la fila activa vuelve a viewport para que el usuario vea dónde está parado.
  - `Enter` guarda edición o abre/aplica la interacción primaria visible del contexto.
  - `Esc` cancela edición; un segundo `Esc` puede limpiar selección según el arquetipo.
  - `Delete/Backspace` dentro de inputs editables borran texto; fuera de texto operan sobre selección.
- Pickers, filtros y catálogos:
  - Dropdowns y filtros por popup aceptan `ArrowUp/ArrowDown`, `Enter`, `Space` y `Esc`.
  - Los diálogos de filtros usan la paleta del área anfitriona y no heredan azul de Operación.
  - Clasificaciones estables de Menudeo no se capturan como texto libre.
  - Normalizar captura operativa a mayúsculas limpias cuando aplique: sin acentos raros ni variantes innecesarias.
- Multiedición:
  - La multiedición se siente igual que en la referencia: edición inline sobre filas seleccionadas, no como banda ajena al grid.
  - `Enter` guarda, `Esc` cancela y `Cmd/Ctrl + S` guarda selección cuando aplique.
  - La selección persiste al abrir el menú contextual o el `...`.

Si un punto del checklist falla, la página no debe considerarse homologada aunque visualmente “ya se vea bien”.

## Cierre contractual Ventas Mayoreo

Antes de dar por cerrada una página de `Ventas Mayoreo`, validar explícitamente este checklist adicional:

- Referencia base:
  - Existe una página espejo identificable en `Menudeo`.
  - La implementación arrancó copiando esa página y no armando una variante desde cero.
  - Toda desviación respecto a `Menudeo` responde a datos/reglas de `Mayoreo` o a obligación contractual del grid.
- Composición y layout:
  - Header, top bar, cards de métrica, tabs, header row, insert row, filas y paginación conservan la misma jerarquía y orden que la referencia de `Menudeo`.
  - El insert row usa la misma familia estructural de `Menudeo`; no una versión “parecida”.
  - El botón `Agregar`, el slot final `...` y los badges compactos usan la misma lógica de espacio y anclaje que en `Menudeo`.
  - No hay piezas extra, textos explicativos, subtítulos, botones o métricas que no existan en la referencia sin razón real del módulo.
- Descubribilidad:
  - Si en `Menudeo` una acción vive en header, top bar, `...`, click derecho o inline edit, en `Mayoreo` debe vivir en el mismo lugar salvo excepción justificada.
  - Si `Menudeo` usa picker, popup de filtro o catálogo controlado, `Mayoreo` debe arrancar igual antes de considerar texto libre o un control distinto.
- Captura comercial:
  - Campos nominales y operativos se normalizan a mayúsculas limpias cuando aplique.
  - Clasificaciones comerciales repetibles no se capturan como texto libre.
  - La relación entre entidades comerciales debe copiar primero el modelo de `Menudeo` cuando sea análoga.
- Regla práctica de revisión:
  - Si al comparar capturas `Menudeo` vs `Mayoreo` aparece una diferencia visible que no proviene de color, datos o una obligación explícita del grid, debe tratarse como desviación contractual y corregirse.

## Nota mínima de coordinación
- El contrato UI oficial de la app vive en `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md`.
- Si se replica una página, primero validar paridad funcional (foco/teclado/refresh) y luego estilo/columnas.
- El contrato de identidad visual por área también vive en `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md` y aplica incluso cuando el arquetipo funcional cambie.
- `Operación` ya no se trata como excepción visual; es la primera implementación homologada del sistema UI transversal de DICSA.
- En `Ventas Mayoreo`, declarar explícitamente en cada página: referencia comercial principal `Menudeo`, referencia de interacción base `Entradas y Salidas`, paleta del área `Mayoreo`.
