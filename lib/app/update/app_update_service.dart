import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.notes,
    this.publishedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String notes;
  final DateTime? publishedAt;
}

class AppUpdateService {
  static const String _manifestUrl = String.fromEnvironment(
    'DICSA_UPDATE_MANIFEST_URL',
    defaultValue: '',
  );

  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isWindows || _manifestUrl.isEmpty) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _fullVersion(
      packageInfo.version,
      packageInfo.buildNumber,
    );

    final response = await http
        .get(
          Uri.parse(_manifestUrl),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final latestVersion = (decoded['version'] as String? ?? '').trim();
    final downloadUrl =
        ((decoded['windows_url'] ?? decoded['download_url']) as String? ?? '')
            .trim();
    final notes = (decoded['notes'] as String? ?? '').trim();
    final publishedAtRaw = (decoded['published_at'] as String? ?? '').trim();

    if (latestVersion.isEmpty || downloadUrl.isEmpty) {
      return null;
    }

    if (_compareVersions(latestVersion, currentVersion) <= 0) {
      return null;
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      notes: notes,
      publishedAt: DateTime.tryParse(publishedAtRaw),
    );
  }

  static String _fullVersion(String version, String buildNumber) {
    final cleanBuild = buildNumber.trim();
    if (cleanBuild.isEmpty) {
      return version.trim();
    }
    return '${version.trim()}+$cleanBuild';
  }

  static int _compareVersions(String left, String right) {
    final leftVersion = _ParsedVersion.parse(left);
    final rightVersion = _ParsedVersion.parse(right);

    for (var index = 0; index < 3; index++) {
      final diff = leftVersion.core[index].compareTo(rightVersion.core[index]);
      if (diff != 0) {
        return diff;
      }
    }

    return leftVersion.build.compareTo(rightVersion.build);
  }
}

class _ParsedVersion {
  const _ParsedVersion({required this.core, required this.build});

  final List<int> core;
  final int build;

  factory _ParsedVersion.parse(String input) {
    final trimmed = input.trim();
    final pieces = trimmed.split('+');
    final rawCore = pieces.first.split('.');

    final core = List<int>.generate(3, (index) {
      if (index >= rawCore.length) {
        return 0;
      }
      return int.tryParse(rawCore[index]) ?? 0;
    });

    final build = pieces.length > 1 ? int.tryParse(pieces[1]) ?? 0 : 0;

    return _ParsedVersion(core: core, build: build);
  }
}
