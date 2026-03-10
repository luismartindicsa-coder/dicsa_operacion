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

## Criterio de aceptación
Un módulo nuevo se considera terminado solo si es réplica funcional y visual de Entradas/Salidas en interacción (mouse/teclado/foco) y estilo, cambiando únicamente los campos propios del módulo.

## Nota mínima de coordinación
- El contrato UI oficial de la app vive en `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md`.
- Si se replica una página, primero validar paridad funcional (foco/teclado/refresh) y luego estilo/columnas.
- El contrato de identidad visual por área también vive en `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md` y aplica incluso cuando el arquetipo funcional cambie.
- `Operación` ya no se trata como excepción visual; es la primera implementación homologada del sistema UI transversal de DICSA.
