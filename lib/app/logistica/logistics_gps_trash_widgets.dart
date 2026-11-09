import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logistics_gps_curation_store.dart';
import 'logistics_gps_visit_store.dart';
import 'logistics_theme.dart';

Future<String?> gpsReviewReason(
  BuildContext context,
  String title,
  String explanation,
) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title, explanation),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title, explanation;
  const _ReasonDialog(this.title, this.explanation);
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void submit() {
    if (text.text.trim().isNotEmpty) Navigator.pop(context, text.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: kLogisticsSilverSurfaceTop,
    title: Text(widget.title),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.explanation),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('gps-review-reason'),
            controller: text,
            autofocus: true,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Motivo'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => submit(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: text.text.trim().isEmpty ? null : submit,
        child: const Text('Guardar'),
      ),
    ],
  );
}

String gpsWriteError(Object error) =>
    error is PostgrestException && error.code == 'P0001'
    ? error.message
    : 'No se pudo guardar. Revisa la conexión y vuelve a intentarlo.';

class GpsTrashButton extends StatefulWidget {
  final String kind, eventId, label;
  final bool enabled;
  final Future<void> Function() onChanged;
  final Future<void> Function(String, String, String) discard;
  const GpsTrashButton({
    super.key,
    required this.kind,
    required this.eventId,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.discard = GpsCurationStore.discard,
  });
  @override
  State<GpsTrashButton> createState() => _GpsTrashButtonState();
}

class _GpsTrashButtonState extends State<GpsTrashButton> {
  bool _busy = false;
  Future<void> _discard() async {
    final reason = await gpsReviewReason(
      context,
      'Enviar a papelera',
      '${widget.label}\nSe ocultará de las listas de trabajo. Podrás restaurarlo desde Papelera.',
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.discard(widget.kind, widget.eventId, reason);
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(gpsWriteError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: ValueKey('trash-${widget.kind}-${widget.eventId}'),
    onPressed: widget.enabled && !_busy ? _discard : null,
    icon: const Icon(Icons.delete_outline),
    label: Text(_busy ? 'Guardando…' : 'A papelera'),
  );
}

class LogisticsGpsTrashPanel extends StatefulWidget {
  final GpsCuration curation;
  final Future<void> Function() onChanged;
  final Future<void> Function(String) restore;
  const LogisticsGpsTrashPanel({
    super.key,
    required this.curation,
    required this.onChanged,
    this.restore = GpsCurationStore.restore,
  });
  @override
  State<LogisticsGpsTrashPanel> createState() => _TrashState();
}

class _TrashState extends State<LogisticsGpsTrashPanel> {
  String _query = '', _kind = 'Todas';
  final _busy = <String>{};
  Future<void> _restore(GpsTrashEntry entry) async {
    setState(() => _busy.add(entry.id));
    try {
      await widget.restore(entry.id);
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(gpsWriteError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.curation.available) {
      return const Center(
        child: Text('La papelera todavía no está habilitada en el servidor.'),
      );
    }
    final rows = widget.curation.trash
        .where(
          (r) =>
              (_kind == 'Todas' ||
                  (_kind == 'Visitas'
                      ? r.kind == 'visit'
                      : r.kind == 'stop')) &&
              '${r.unit} ${r.place} ${r.reason}'.toUpperCase().contains(
                _query.toUpperCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar unidad, lugar o motivo',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            DropdownButton<String>(
              value: _kind,
              items: [
                'Todas',
                'Visitas',
                'Paradas',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _kind = v!),
            ),
            Text('${rows.length} registros en papelera'),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Registros descartados manualmente. El dato original del GPS se conserva; restaurar lo devuelve a su lista con los filtros habituales.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('La papelera está vacía con estos filtros.'),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return Card(
                      color: kLogisticsSilverSurfaceTop,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              r.kind == 'visit'
                                  ? Icons.location_on_outlined
                                  : Icons.pause_circle_outline,
                              color: kLogisticsSilverIcon,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.unit} · ${r.place}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${r.kind == 'visit' ? 'Visita' : 'Parada'} · ${gpsVisitDate(r.startedAt)}',
                                  ),
                                  Text('Motivo: ${r.reason}'),
                                  Text(
                                    'En papelera desde ${gpsVisitDate(r.discardedAt)}',
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              key: ValueKey('restore-${r.id}'),
                              onPressed: _busy.contains(r.id)
                                  ? null
                                  : () => _restore(r),
                              icon: const Icon(Icons.restore),
                              label: const Text('Restaurar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
