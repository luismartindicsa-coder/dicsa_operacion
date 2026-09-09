# Complemento de flujo y descuentos fiscales

El complemento automático usa max(0, salario percibido semanal - salario base semanal). No usa el neto ni el sueldo reducido importados de CONTPAQ. Si faltan salarios contractuales positivos, no se inventa un complemento. Las deducciones incluidas en el neto fiscal permanecen en ese neto.

Ejemplo de prueba: base y percibido de 2205.28, neto fiscal de 1530.50: flujo automático cero y total 1530.50. Con percibido 3000 y la misma base, el complemento es 794.72; el neto reducido no incrementa ese complemento.

Los borradores automáticos recalculan el complemento aunque tengan un importe antiguo guardado. Los importes manuales y publicados se conservan. Guardar el borrador persiste el resultado; no se actualizaron registros de producción.

Pruebas cubren neto reducido, cero y mayor al base, diferencia contractual, corrección de borradores con recarga repetida, captura manual y publicación. Las pruebas de vacaciones ahora incluyen explícitamente el neto fiscal cuando esperan un sueldo fiscal completo, en lugar de depender del relleno automático anterior.
