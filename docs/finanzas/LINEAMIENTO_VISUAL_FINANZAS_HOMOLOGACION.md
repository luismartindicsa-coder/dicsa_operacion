## Lineamiento visual Finanzas

Este lineamiento captura la dirección visual aprobada en `Centro de pagos` y sirve como base para homologar el resto de las pantallas de `Finanzas`.

### Objetivo

`Finanzas` debe verse ejecutivo, limpio y preciso.

No debe sentirse:
- pesado
- gris sucio
- lleno de placas duplicadas
- improvisado en tamaños, alineaciones o densidad

Sí debe sentirse:
- flotante
- claro en jerarquía
- homogéneo
- premium
- analítico

### Paleta

Base del área:
- fondo negro profundo
- acentos naranja neón DICSA
- apoyo plateado / gris frío

Uso recomendado:
- `naranja` para acción principal, totales clave, focos de atención y estados activos
- `verde` para cobertura, disponible, saldos sanos, confirmación
- `rojo` para presión, vencidos, obligatorio, urgencia crítica
- `gris frío / plateado` para texto secundario, bordes y estados neutros

Evitar:
- mezclar naranja con negro en gradientes turbios dentro de módulos grandes
- superficies blancas sólidas como base del contrato
- rojos o cafés “terrosos” como relleno dominante

### Glass

El glass de Finanzas debe ser:
- transparente
- ligero
- brillante en bordes
- con fondo respirando detrás

Debe evitar:
- módulos dobles
- una placa grande detrás y otra encima
- capas grises opacas que “ensucian” los cards

Regla:
- preferir `cards` o `paneles` individuales flotantes
- si existe un módulo contenedor, debe ser muy ligero y no competir con el contenido

### Estructura

Cada pantalla debe buscar:
- header claro
- acciones principales arriba
- métricas o resumen ejecutivo en una franja homogénea
- cuerpo principal con módulos bien separados
- ritmo visual parejo entre bloques

Evitar:
- secciones descentradas
- cards de distintos tamaños sin razón funcional
- filas o módulos que rompan la cuadrícula

### Tamaños y alineación

Reglas base:
- cards equivalentes deben compartir ancho y alto
- títulos, métricas y acciones deben alinearse entre sí
- los grupos deben verse centrados visualmente
- los bloques repetidos deben usar la misma plantilla

Si un dato no cabe:
- reducir tipografía con `scaleDown`
- ajustar padding
- acortar copy

No se debe:
- partir palabras
- dejar números con `...`
- mandar nombres o montos a varias líneas cuando deberían leerse de un vistazo

### Tipografía y contenido

Preferencias aprobadas:
- nombres, montos y métricas en una sola línea
- subtítulos cortos y directos
- labels secundarios discretos pero legibles
- números fuertes y protagonistas

Regla:
- si una línea es importante para decisión, debe leerse completa

### Visualización

No todo debe ser:
- listas
- barras lineales
- tablas planas

Sí se permite y se recomienda combinar:
- cards métricos
- anillos / donuts
- porcentajes destacados
- badges de estado
- bloques comparativos
- resúmenes visuales por bucket o prioridad

La visualización debe ayudar a decidir, no solo decorar.

### Grid y filas

Las grids de Finanzas deben conservar legibilidad ejecutiva:
- headers limpios
- filtros visibles pero sobrios
- rows oscuras o glass limpias
- acciones ancladas consistentes

Evitar:
- filas blancas sobre fondos oscuros
- contrastes sucios
- menús de acciones desconectados del contrato visual

### Modales

Los modales deben seguir el mismo contrato:
- shell glass oscuro
- campos oscuros / transparentes
- pasos claros
- botones consistentes con el área

Evitar:
- formularios blancos dentro de shell oscuro
- close buttons ajenos al contrato
- bloques interiores con exceso de gris opaco

### Regla de homologación

Antes de tocar contrato funcional de pantalla o interacción:

1. homologar fondo
2. homologar glass
3. homologar header
4. homologar tarjetas resumen
5. homologar grid / rows / acciones
6. homologar modales

Solo después:
- depurar navegación funcional
- depurar interacción
- congelar contrato de pantalla

### Referencia viva

La referencia visual actual para `Finanzas` es:
- `Centro de pagos`

Las siguientes páginas deben buscar acercarse a ese lenguaje, adaptándose a su función:
- `Cuentas Bancarias`
- `Pagos fijos`
- `Cuentas por Proveedor`
- `Directorio Empresas`
- `Catálogo Finanzas`
