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

## Areas propuestas v1

Estas areas quedan aprobadas solo como direccion cromatica inicial. Sus tokens finales se definiran despues contra este mismo contrato.

### Recursos Humanos

- caracter: calido sobrio, humano, institucional
- familia sugerida: miel / ambar tostado

### Menudeo

- caracter: comercial, agil, energetico
- familia sugerida: coral terracota

### Mayoreo

- caracter: comercial institucional, mas robusto que Menudeo
- familia sugerida: azul petroleo

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

- `Operaciones` y `Direccion` se respetan tal como ya estan.
- Las otras areas se construyen tomando como referencia estas dos paletas congeladas.
- Ninguna nueva area puede alterar glass, blur, radios, sombras, spacing, botones, foco, teclado o patrones de interaccion.

## Nota de alcance

- `Administracion` no queda como area oficial independiente por ahora.
- La tarjeta azul que hoy aparece como `Administracion` no define la paleta de `Direccion`.
- Esa familia azul puede reciclarse despues para `Gestion Documental` si hace sentido.
