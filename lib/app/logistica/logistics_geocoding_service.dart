import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogisticsGeocodingCandidate {
  final String displayName;
  final String primaryLabel;
  final String secondaryLabel;
  final LatLng point;

  const LogisticsGeocodingCandidate({
    required this.displayName,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.point,
  });

  factory LogisticsGeocodingCandidate.fromRemoteRow(Map<String, dynamic> row) {
    final latitude = double.tryParse((row['lat'] ?? '').toString());
    final longitude = double.tryParse((row['lon'] ?? '').toString());
    if (latitude == null || longitude == null) {
      throw const FormatException('Resultado de geocodificacion invalido.');
    }

    final address = row['address'] is Map
        ? Map<String, dynamic>.from(row['address'] as Map)
        : const <String, dynamic>{};

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (address[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final primaryParts = <String>[
      pick(const ['road', 'pedestrian', 'footway', 'industrial']),
      pick(const ['suburb', 'neighbourhood', 'quarter']),
      pick(const ['city', 'town', 'village', 'municipality']),
    ].where((part) => part.isNotEmpty).toList(growable: false);

    final secondaryParts = <String>[
      pick(const ['county', 'state_district']),
      pick(const ['state']),
      pick(const ['postcode']),
    ].where((part) => part.isNotEmpty).toList(growable: false);

    final displayName = (row['display_name'] ?? '').toString().trim();
    final primaryLabel = primaryParts.isNotEmpty
        ? primaryParts.join(', ')
        : displayName.split(',').first.trim();
    final secondaryLabel = secondaryParts.isNotEmpty
        ? secondaryParts.join(' · ')
        : displayName;

    return LogisticsGeocodingCandidate(
      displayName: displayName,
      primaryLabel: primaryLabel.isEmpty ? displayName : primaryLabel,
      secondaryLabel: secondaryLabel,
      point: LatLng(latitude, longitude),
    );
  }
}

class LogisticsGeocodingService {
  static const String _cachePrefix = 'logistics_geocode_v1::';
  static Future<PackageInfo>? _packageInfoFuture;
  static DateTime? _lastRemoteRequestAt;

  static Future<List<LogisticsGeocodingCandidate>> searchAddress(
    String query,
  ) async {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.isEmpty) return const <LogisticsGeocodingCandidate>[];

    final cachedRows = await _readCachedRows(normalizedQuery);
    if (cachedRows != null) return _decodeCandidates(cachedRows);

    await _respectThrottle();
    final response = await http
        .get(_buildSearchUri(query.trim()), headers: await _buildHeaders())
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception(
        'El mapa no devolvio resultados (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Respuesta inesperada del geocodificador.');
    }

    final rows = decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    await _writeCachedRows(normalizedQuery, rows);
    return _decodeCandidates(rows);
  }

  static Uri _buildSearchUri(String query) {
    return Uri.https('nominatim.openstreetmap.org', '/search', <String, String>{
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '5',
      'dedupe': '1',
      'countrycodes': 'mx',
      'viewbox': '-101.1500,20.7200,-100.5200,20.2900',
    });
  }

  static String _normalizeQuery(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<LogisticsGeocodingCandidate> _decodeCandidates(
    List<Map<String, dynamic>> rows,
  ) {
    final candidates = <LogisticsGeocodingCandidate>[];
    for (final row in rows) {
      try {
        candidates.add(LogisticsGeocodingCandidate.fromRemoteRow(row));
      } on FormatException {
        continue;
      }
    }
    return candidates;
  }

  static Future<List<Map<String, dynamic>>?> _readCachedRows(
    String query,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cachePrefix$query');
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static Future<void> _writeCachedRows(
    String query,
    List<Map<String, dynamic>> rows,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachePrefix$query', jsonEncode(rows));
  }

  static Future<Map<String, String>> _buildHeaders() async {
    final packageInfo = await _loadPackageInfo();
    final userAgent =
        'DICSA-Operacion/${packageInfo.version} (${packageInfo.packageName}; geocodificacion manual)';
    return <String, String>{
      'Accept': 'application/json',
      'Accept-Language': 'es-MX,es;q=0.9',
      'User-Agent': userAgent,
    };
  }

  static Future<PackageInfo> _loadPackageInfo() {
    _packageInfoFuture ??= PackageInfo.fromPlatform().catchError(
      (_) => PackageInfo(
        appName: 'DICSA Operacion',
        packageName: 'com.dicsa.operacion',
        version: 'local',
        buildNumber: '0',
        buildSignature: '',
        installerStore: null,
      ),
    );
    return _packageInfoFuture!;
  }

  static Future<void> _respectThrottle() async {
    final previous = _lastRemoteRequestAt;
    if (previous != null) {
      final elapsed = DateTime.now().difference(previous).inMilliseconds;
      if (elapsed < 1000) {
        await Future<void>.delayed(Duration(milliseconds: 1000 - elapsed));
      }
    }
    _lastRemoteRequestAt = DateTime.now();
  }
}
