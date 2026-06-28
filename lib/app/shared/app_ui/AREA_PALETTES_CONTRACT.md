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
- `Gerencia`
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
  - `#9F6BFF`
  - `#B68CFF`
  - `#6E47A8`
  - `#2B114F`
  - `#24103D`
  - `#130B22`
  - `#34204E`
  - `#432A65`
  - `#C79CFF`
  - `#CFAEFF`

#### Recursos Humanos: contrato visual congelado

- `Recursos Humanos` vive en modo `dark glass`, no en glass lechoso.
- La lectura dominante debe ser:
  - fondo oscuro
  - cards oscuras
  - acentos morados claros
- No se permite en RH la lectura:
  - fondo oscuro
  - cards blancas
  - brillos blancos dominantes
- La mejora de legibilidad en RH se resuelve con:
  - contraste
  - profundidad
  - jerarquia visual
  - distribucion de color
- No se resuelve cambiando identidad de area.

#### Recursos Humanos: distribucion cromatica obligatoria

- objetivo de masa visual:
  - `70%` morado oscuro
  - `20%` morado medio
  - `10%` morado claro
- El morado claro se reserva para:
  - iconos relevantes
  - badges
  - llamados de atencion
  - acentos de hover
- Los fondos claros no deben dominar heroes, cards base ni estados vacios.

#### Recursos Humanos: fondo congelado

- base profunda:
  - `#130B22`
- gradientes de apoyo:
  - `#24103D`
  - `#341A5A`
- Los blobs o masas decorativas permanecen homologados en geometria, pero su protagonismo baja.
- Su opacidad visual debe sentirse alrededor de `15%`; decoran, no lideran la lectura.

#### Recursos Humanos: superficies congeladas

- Hero principal:
  - gradiente oscuro premium
  - borde morado tenue
  - titular en blanco puro
  - subtitulo en blanco translúcido
  - badge claro `#CFAEFF`
- Cards base:
  - fondo oscuro translúcido
  - borde tenue morado
  - sombra profunda negra
- Estado vacio:
  - contenedor oscuro elegante
  - borde punteado morado tenue
  - icono en `#B68CFF`
- Panel derecho:
  - card premium oscura
  - acciones internas en morado medio
  - hover mas brillante en la misma familia
- Cards inferiores:
  - se leen como navegacion futura
  - icono superior
  - titulo
  - descripcion
  - flecha de avance

#### Recursos Humanos: contraste y texto

- `H1`: blanco puro
- `H2`: `#F1E7FF`
- texto normal: blanco con opacidad alta
- texto secundario: blanco con opacidad media
- texto apagado: blanco con opacidad baja
- En RH no se usa gris oscuro sobre superficies oscuras.

### Gerencia

- estado: `direccion cromatica inicial aprobada`
- caracter: ejecutiva, resolutiva, seguimiento transversal
- familia oficial: rojo corporativo / vino profundo
- objetivo de diferenciacion:
  - no confundirse con `Direccion`
  - no reciclar el morado de `Recursos Humanos`
  - no verse como alerta destructiva del sistema
- anclas iniciales:
  - `#D84B5B`
  - `#FF8A7A`
  - `#8F2737`
  - `#4B0E18`
  - `#2A0D14`
  - `#16070B`
  - `#4A1520`
  - `#FFC7CF`
  - `#FFB1BA`

#### Gerencia: direccion visual inicial

- `Gerencia` arranca en modo `dark glass`.
- La lectura dominante debe ser:
  - fondo vino oscuro
  - superficies oscuras elegantes
  - acentos rojos y coral apagado
- El rojo no debe sentirse como error del sistema ni como semaforo destructivo.
- El color sirve para jerarquia ejecutiva, seguimiento y escalamiento, no para saturar toda la interfaz.

#### Gerencia: distribucion cromatica sugerida

- objetivo de masa visual:
  - `72%` vino profundo
  - `18%` rojo medio
  - `10%` rojo claro
- El rojo claro se reserva para:
  - iconos
  - badges
  - llamadas de atencion
  - hover y foco

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
