# DICSA Area Palettes Contract

Contrato oficial de areas y direccion cromatica para toda la app.

Este documento no redefine el sistema visual base de DICSA. Solo establece que areas existen, cuales ya tienen paleta congelada y cuales quedan aprobadas como direccion cromatica inicial.

## Regla de sistema

Toda pagina nueva se define por:

`arquetipo funcional + implementacion homologada + paleta del area + datos del modulo`

No se permite redisenar componentes por area.

Solo cambia la gama cromatica mediante tokens semanticos.

## Areas oficiales actuales

- `Operaciones`
- `Direccion`
- `Recursos Humanos`
- `Menudeo`
- `Mayoreo`
- `Gestion Documental`
- `Finanzas`
- `Contabilidad`
- `Apaseo`

## Areas congeladas

Estas areas ya quedan oficiales con base en la UI actual y no deben reinterpretarse sin actualizar este contrato.

### Operaciones

- estado: `congelada`
- caracter: industrial, operativa, teal profundo
- anclas actuales:
  - `#0B2B2B`
  - `#1E8E63`
  - `#4F8E8C`
  - `#2A4B49`
  - `#52CFA6`
  - `#6CB7E2`

### Direccion

- estado: `congelada`
- caracter: ejecutiva, premium, sobria, transversal
- base oficial: `GeneralDashboard`
- anclas actuales:
  - `#0B2B2B`
  - `#355454`
  - `#F7FCFF`
  - `#E7FFF5`
  - `#FFF7E8`
  - `#FFF3D7`
  - `#F1F7FF`
  - `#E4FFF2`
  - `#D99532`
  - `#FFD27A`

## Areas congeladas adicionales

Estas areas ya quedan oficiales con paleta congelada y no deben reinterpretarse sin actualizar este contrato.

### Recursos Humanos

- estado: `congelada`
- caracter: humano, institucional, ejecutivo-operativo
- familia oficial: morado corporativo / violeta profundo
- objetivo de diferenciacion:
  - no confundirse con `Menudeo`
  - no confundirse con `Contabilidad`
- anclas actuales:
  - `#6F3FE8`
  - `#2B114F`
  - `#EEE5FF`
  - `#A66BFF`
  - `#F6F1FF`
  - `#D6C6F4`
  - `#E9DEFF`
  - `#5B2AB5`
  - `#8D63E8`

### Menudeo

- estado: `congelada`
- caracter: comercial, agil, institucional
- familia oficial: azul royal / navy / midnight
- objetivo de diferenciacion:
  - no confundirse con `Recursos Humanos`
  - no regresar a coral, terracota, miel o ambar
- anclas actuales:
  - `#1149B5`
  - `#06152E`
  - `#D6E1F2`
  - `#245FCF`
  - `#EEF3FA`
  - `#9EB3D6`
  - `#DFE9F8`
  - `#123B89`
  - `#3F69BD`

## Areas propuestas v1

Estas areas quedan aprobadas solo como direccion cromatica inicial. Sus tokens finales se definiran despues contra este mismo contrato.

### Mayoreo

- estado: `direccion aprobada`
- caracter: comercial institucional, mas robusto que Menudeo, orientado a venta mayorista
- familia sugerida: amarillo institucional / oro comercial
- objetivo de diferenciacion:
  - no confundirse con `Menudeo`
  - no reciclar teal de `Operaciones`
  - no sentirse advertencia, error o estado de sistema
- direccion de uso:
  - la paleta amarilla vive solo en tokens semanticos de area
  - glass, blur, sombras, layout y microinteracciones permanecen iguales al lenguaje base de la app

### Gestion Documental

- caracter: limpio, ordenado, neutro, documental
- familia sugerida: gris azulado

### Finanzas

- caracter: ejecutivo, control, claridad
- familia sugerida: verde sobrio

### Contabilidad

- caracter: tecnico, preciso, serio
- familia sugerida: vino / ciruela

### Apaseo

- caracter: territorial DICSA, no producto distinto
- familia sugerida: oliva mineral

## Regla de no confusion

- `Operaciones` y `Finanzas` no deben verse iguales.
- `Menudeo` y `Mayoreo` deben sentirse relacionadas, pero no intercambiables.
- `Mayoreo` usa direccion amarilla propia; no debe leerse como `warning`, `pending` o estado de alerta.
- `Finanzas` y `Contabilidad` deben ser hermanas, no gemelas.
- `Apaseo` debe sentirse como sede o territorio, no como nueva marca.
- `Direccion` no usa la paleta azul de la tarjeta de `Administracion`; usa la paleta real del dashboard general.

## Tokens obligatorios por area

Cada area debe definirse unicamente con:

- `area-primary`
- `area-primary-strong`
- `area-primary-soft`
- `area-accent`
- `area-surface-tint`
- `area-border`
- `area-badge-bg`
- `area-badge-text`
- `area-glow`

## Regla de implementacion

- `Operaciones`, `Direccion`, `Recursos Humanos` y `Menudeo` se respetan tal como ya estan.
- `Mayoreo` se implementa con familia amarilla propia, sin tocar el lenguaje visual base del sistema.
- Las otras areas se construyen tomando como referencia estas paletas congeladas.
- Ninguna nueva area puede alterar glass, blur, radios, sombras, spacing, botones, foco, teclado o patrones de interaccion.

## Nota de alcance

- `Administracion` no queda como area oficial independiente por ahora.
- La tarjeta azul que hoy aparece como `Administracion` no define la paleta de `Direccion`.
- Esa familia azul puede reciclarse despues para `Gestion Documental` si hace sentido.
