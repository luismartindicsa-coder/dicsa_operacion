# Cumpleaños en el dashboard de RH

El card muestra los cumpleaños del mes calendario actual a partir del CURP de los perfiles de Personal que no están dados de baja. Al abrirlo aparece la lista completa, ordenada por día y nombre, con nombre, empresa, ID y día del cumpleaños; se destaca el día de hoy. La vista previa contiene hasta tres colaboradores.

La fecha del cumpleaños no depende del periodo de nómina seleccionado. Las fechas ausentes, imposibles o futuras se omiten y el popup informa cuántos expedientes requieren completar o corregir el CURP. No se muestran el CURP completo ni la edad. No se crean columnas ni se modifica información de Personal. Al regresar a través de los accesos de Personal se vuelve a consultar el dashboard.

Se reutilizan el panel interactivo del dashboard, los tokens de RH, el shell de diálogo y su encabezado compacto. El card ocupa la cuarta posición de la fila de indicadores operativos, como en la referencia; el indicador de Permisos y su acceso permanecen en el resumen superior.

## Fecha del CURP

Se extraen año, mes y día de las posiciones 5–10, usando la posición 17 para el siglo. Esto comprueba estructura y fecha, no representa una validación oficial de la clave ante RENAPO. Referencias: [SEGOB: estructura de la CURP](https://www.gob.mx/segob/acciones-y-programas/clave-unica-de-registro-de-poblacion-curp), [instructivo en el DOF](https://dof.gob.mx/nota_detalle_popup.php?codigo=5526717).

## Ilustración

- Modo: herramienta integrada `image_gen`, generación nueva, sin imagen de entrada.
- Archivo en la app: `assets/images/hr_birthday_cake.png`.
- PNG RGBA, 1254 × 1254, con transparencia. El conteo y los textos se dibujan en Flutter.
- Referencia de composición: `Cumpleaños.png`, proporcionada por el usuario.

Prompt utilizado:

```text
Use case: stylized-concept. Asset type: a standalone birthday cake illustration for a compact birthday widget in the DICSA human resources desktop dashboard. Primary request: a beautiful, polished, friendly 3D illustrated birthday cake, centered on a small lavender oval serving plate, with two rounded cake tiers, lilac and purple sponge, white icing gently dripping, a few pink frosting accents, three slim teal-blue candles with warm golden flames, and a few sparse purple and pink confetti pieces around the cake. Style: soft premium clay-like 3D illustration, clean silhouette, readable at 110 pixels tall, soft studio lighting, subtle highlights. Palette: purple #9F6BFF, lavender #B68CFF, creamy white, pink accents, teal candles. Composition: square 1024 by 1024, full cake and plate visible, object fills most of the canvas with a modest transparent margin; candle flames and confetti must not be cropped. Background: genuinely transparent alpha, no backdrop, no floor or checkerboard pattern, suitable for placing on a dark purple dashboard. Constraints: no text, no numbers, no labels, no banner, no logo, no watermark, no people. The employee count and labels will be rendered separately in the app.
```

## Verificación

Pruebas de siglo del CURP, normalización, fechas inválidas y futuras, 29 de febrero, orden, perfiles de baja, duplicados, independencia del periodo, popup completo, mes vacío, scroll, ancho compacto y cierre con Esc o botón. Las pruebas del dashboard de vacaciones también se mantienen. Las capturas visuales usan perfiles ficticios y cargan el asset real.

```sh
flutter test --no-pub test/hr/human_resources_birthdays_test.dart test/hr/human_resources_dashboard_vacations_test.dart
```

El análisis estático no detectó problemas nuevos; conserva el aviso previo sobre `_HrDashboardWorkspace` sin referencias.
