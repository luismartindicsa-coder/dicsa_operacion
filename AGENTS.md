# Contrato Frontend Base (DICSA App)

Estas reglas son obligatorias para cualquier cambio de frontend en módulos tipo grid/tabla.

## Regla Base de Paridad (obligatoria)
Para cualquier módulo nuevo o refactor de módulo existente (ej. Pesadas, Servicios, Producción, Entradas/Salidas):

1. Primero clonar 1:1 el comportamiento funcional base de `Entradas y Salidas`.
2. Después adaptar únicamente columnas/campos del módulo.
3. Nunca rediseñar ni reinterpretar la interacción base.

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

## Nota mínima de coordinación
- El contrato UI oficial de la app vive en `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md`.
- Si se replica una página, primero validar paridad funcional (foco/teclado/refresh) y luego estilo/columnas.
- El contrato de identidad visual por área también vive en `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md` y aplica incluso cuando el arquetipo funcional cambie.
- `Operación` ya no se trata como excepción visual; es la primera implementación homologada del sistema UI transversal de DICSA.
