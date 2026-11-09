import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import 'logistics_geofence_store.dart';
import 'logistics_theme.dart';

class LogisticsGeofenceLayer extends StatelessWidget {
  final List<LogisticsGeofence> fences;
  final String? selectedKey;
  const LogisticsGeofenceLayer({
    super.key,
    required this.fences,
    this.selectedKey,
  });
  Color color(LogisticsGeofence fence) =>
      fence.needsReview ? kLogisticsGpsWarning : kLogisticsSilverTextPrimary;
  @override
  Widget build(BuildContext context) {
    final visible = fences.where((f) => f.showOnMap);
    return Stack(
      children: [
        PolygonLayer(
          polygons: [
            for (final f in visible.where((f) => f.shapeType == 2))
              Polygon(
                points: f.points,
                color: color(
                  f,
                ).withValues(alpha: f.key == selectedKey ? .24 : .10),
                borderColor: color(f),
                borderStrokeWidth: f.key == selectedKey ? 3 : 1.5,
                label: f.name,
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kLogisticsSilverTextPrimary,
                ),
              ),
          ],
        ),
        PolylineLayer(
          polylines: [
            for (final f in visible.where((f) => f.shapeType == 1))
              Polyline(
                points: f.points,
                color: color(f).withValues(alpha: .25),
                strokeWidth: f.widthMeters > 0 ? f.widthMeters : 3,
                useStrokeWidthInMeter: f.widthMeters > 0,
              ),
          ],
        ),
        CircleLayer(
          circles: [
            for (final f in visible.where((f) => f.shapeType == 3))
              CircleMarker(
                point: f.points.first,
                radius: f.widthMeters,
                useRadiusInMeter: true,
                color: color(
                  f,
                ).withValues(alpha: f.key == selectedKey ? .24 : .10),
                borderColor: color(f),
                borderStrokeWidth: f.key == selectedKey ? 3 : 1.5,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final f in visible.where((f) => f.key == selectedKey))
              Marker(
                point: f.points.first,
                width: 220,
                height: 40,
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kLogisticsSilverSurfaceTop,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kLogisticsSilverBorder),
                    ),
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Auxiliary workflow dialog: same searchable picker and silent-refresh isolation
// as the operational Logistics forms. The snapshot version prevents overwrites.
class LogisticsGeofenceLinkDialog extends StatefulWidget {
  final LogisticsGeofence fence;
  const LogisticsGeofenceLinkDialog({super.key, required this.fence});
  @override
  State<LogisticsGeofenceLinkDialog> createState() =>
      _LogisticsGeofenceLinkDialogState();
}

class _LogisticsGeofenceLinkDialogState
    extends State<LogisticsGeofenceLinkDialog> {
  late String _kind;
  String? _siteId, _siteName, _error;
  bool _saving = false, _loading = true;
  List<Map<String, dynamic>> _companies = [];
  @override
  void initState() {
    super.initState();
    _kind = widget.fence.classification;
    _siteId = widget.fence.siteId;
    _siteName = widget.fence.siteName;
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final values = await LogisticsGeofenceStore.companies();
      if (mounted) setState(() => _companies = values);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo consultar el catálogo de empresas.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    final id = await showSearchablePickerDialog<String>(
      context,
      title: 'Vincular empresa',
      options: [
        for (final s in _companies)
          SearchablePickerOption(
            value: s['id'].toString(),
            label: s['name'].toString(),
          ),
      ],
      initialValue: _siteId,
    );
    if (id == null || !mounted) return;
    setState(() {
      _siteId = id;
      _siteName = _companies
          .singleWhere((s) => s['id'] == id)['name']
          .toString();
    });
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (_kind == 'company' && !_companies.any((s) => s['id'] == _siteId)) {
      setState(() => _error = 'Selecciona una empresa activa.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LogisticsGeofenceStore.saveLink(
        widget.fence,
        _kind,
        _kind == 'company' ? _siteId : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PostgrestException && error.code == '40001'
              ? 'El vínculo cambió. Cierra y vuelve a abrir esta geocerca para revisarlo.'
              : 'No se pudo guardar el vínculo. Tu selección se conserva; puedes reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.enter): _save},
      child: AlertDialog(
        title: Text('Vincular ${widget.fence.name}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  isExpanded: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tipo de lugar'),
                  items: [
                    for (final item in logisticsGeofenceKinds.entries)
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _kind = value);
                        },
                ),
                if (_kind == 'company') ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading || _saving ? null : _pick,
                    icon: const Icon(Icons.business_outlined),
                    label: Text(_siteName ?? 'Seleccionar empresa'),
                  ),
                ],
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: kLogisticsGpsWarning),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar vínculo'),
          ),
        ],
      ),
    ),
  );
}
