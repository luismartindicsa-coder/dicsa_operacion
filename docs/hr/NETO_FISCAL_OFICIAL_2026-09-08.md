# Neto fiscal oficial

CONTPAQ define el neto fiscal final. Prenómina conserva ese importe en source_snapshot.contpaq_official_net para mantenerlo al recargar sin la importación presente. No se restan retardos, faltas ni permisos nuevamente; tampoco se suman vacaciones fiscales Las vacaciones previamente pagadas se liquidan por separado en fiscal y flujo: son sueldo ya cubierto por un anticipo, no un descuento por incidencias. El flujo conserva su cálculo independiente para vacaciones.

Las incidencias operativas se presentan como referencias de RH calculadas sobre salario base semanal: días por base/7 y horas por base/7/8. No se presentan como conciliación exacta del neto de CONTPAQ. source_snapshot.incidences_informational marca el tratamiento nuevo para que Nómina y recibos tampoco resten las incidencias. Historial publicado anterior conserva su tratamiento.

Se verifican guardado y recarga repetidos, neto importado que prevalece sobre borrador anterior, referencias de faltas/retardos/permisos, publicación y cálculo del recibo. No se modificaron datos de producción.
