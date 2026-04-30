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
  - `#04142E`
  - `#0C2147`
  - `#133963`
  - `#7AAFFF`
  - `#00B7FF`
  - `#4BFFE0`
  - `#224CFF`
  - `#7D63FF`
  - `#39F0E1`
  - `#0C8CFF`
  - `#FFD28B`
  - `#7FD7FF`

#### Direccion: contrato visual congelado

- `Direccion` usa fondo nocturno ejecutivo en familia azul profunda.
- El fondo no es plano: siempre lleva gradiente base y masas grandes homologadas.
- Las masas del fondo respetan la geometria oficial del sistema:
  - esfera superior izquierda
  - esfera superior derecha
  - esfera inferior izquierda
  - masa vertical inferior derecha
- En `Direccion` esas masas se renderizan con lectura `neon glass bubble`:
  - cuerpo translucido
  - glow exterior suave
  - borde tenue luminoso
  - modelado interno sutil sin lineas, barras ni geometria ajena al blob
- El centro del dashboard debe quedar mas limpio que las esquinas para contenido ejecutivo.
- El acento calido en `Direccion` es minimo; no domina el fondo.

#### Direccion: glass congelado

- El glass de `Direccion` es oscuro-translucido, no lechoso.
- Los paneles usan:
  - blur visible
  - relleno azul profundo con baja opacidad
  - borde claro luminoso
  - glow frio sutil
- Los bordes pueden ser mas luminosos que en otras areas, pero sin caer en neon agresivo de videojuego.
- La jerarquia del glass se apoya en:
  - borde
  - blur
  - contraste del fondo
  - leve glow
- No introducir highlights internos rectangulares, capsulas, barras o cortes que no sigan la silueta del blob o del panel.

#### Direccion: contraste y texto

- Titulares y acciones principales sobre fondo oscuro van en blanco o azul hielo claro.
- El texto secundario usa azul grisaceo claro; no gris oscuro.
- Los estados activos pueden tomar acento dorado suave o cyan frio, pero solo como detalle.

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
