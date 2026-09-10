# Escape y estado del teclado

Se reportó en Flutter 3.38.9 una aserción de `HardwareKeyboard`: llega un
`KeyDownEvent` de Escape cuando la tecla ya está registrada como presionada.
El registro no identifica qué pantalla o acción originó la desincronización.

## Causa reproducida en el código de la app

Tickets de Menudeo, Depósitos y gastos, y Entradas y salidas de Dirección
llamaban a `HardwareKeyboard.instance.syncKeyboardState()` en `initState`.
Flutter ya hace esa sincronización durante la inicialización del binding.

En macOS el motor entrega los datos de tecla y un mensaje raw asociado. Si se
abre una pantalla entre ambos, una sincronización adicional puede copiar la
tecla presionada desde el motor antes de que Flutter procese su `KeyDownEvent`
pendiente. La prueba reproduce así la misma aserción del reporte.

Se eliminaron las tres sincronizaciones de página. Los controles siguen
recibiendo los eventos normales de Flutter. No se suprimen excepciones, no se
vacían los manejadores globales y no se altera el SDK.

Durante la prueba de Dirección se detectó además un desbordamiento del selector
de filas por página. `isExpanded: true` lo mantiene dentro de su ancho existente.

## Validación

- `test/shared/page_keyboard_state_test.dart`: abre las tres pantallas reales
  entre los dos mensajes de Escape; verifica dos pulsaciones completas y que
  no quede ninguna tecla presionada. HTTP y almacenamiento son simulados.
- La sincronización anterior se reintrodujo únicamente en una ejecución de
  diagnóstico del test y reprodujo `physical key is already pressed`.
- Las nueve pruebas de `human_resources_prenomina_editor_test.dart` pasan.
- Análisis estático sin incidencias en los archivos de esta corrección.

La prueba demuestra un desencadenante de la app, pero no permite atribuirle
con certeza el caso observado en la sesión del usuario sin conocer la acción
inicial. El acceso de control a la ventana falló durante la revisión.

## Recuperación de una sesión ya afectada

Guardar cualquier captura pendiente y hacer un **hot restart** con `R`
mayúscula en la terminal que ejecuta `flutter run`, o detener y volver a ejecutar
la app. Una recarga con `r` conserva el estado del binding y no reinicia la cola
de teclado. No es necesario borrar datos, limpiar la base ni reinstalar paquetes.

No volver a llamar `syncKeyboardState` al navegar o abrir diálogos. Tampoco usar
`HardwareKeyboard.clearState` como arreglo: es una API de pruebas que elimina
los manejadores registrados.

Referencias del framework:
- [Sincronización del teclado](https://api.flutter.dev/flutter/services/HardwareKeyboard/syncKeyboardState.html)
- [Procesamiento de mensajes raw](https://api.flutter.dev/flutter/services/KeyEventManager/handleRawKeyMessage.html)
- [Incidencia de Flutter sobre eventos durante el arranque/reinicio](https://github.com/flutter/flutter/issues/125975)
