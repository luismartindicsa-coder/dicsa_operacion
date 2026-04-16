import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'app_update_service.dart';

Future<void> showAppUpdatePrompt(
  BuildContext context,
  AppUpdateInfo update,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final publishedAt = update.publishedAt;
      final publishedLabel = publishedAt == null
          ? null
          : '${publishedAt.day.toString().padLeft(2, '0')}/'
                '${publishedAt.month.toString().padLeft(2, '0')}/'
                '${publishedAt.year}';
      final notes = update.notes.isEmpty
          ? 'Esta version incluye cambios nuevos y correcciones.'
          : update.notes;

      return AlertDialog(
        title: const Text('Nueva version disponible'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tienes ${update.currentVersion} y ya esta disponible ${update.latestVersion}.',
              ),
              if (publishedLabel != null) ...[
                const SizedBox(height: 8),
                Text('Publicada: $publishedLabel'),
              ],
              const SizedBox(height: 14),
              Text(notes),
              const SizedBox(height: 14),
              const Text(
                'Al continuar se abrira la descarga del instalador para actualizar Windows.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Despues'),
          ),
          FilledButton(
            onPressed: () async {
              await launchUrlString(
                update.downloadUrl,
                mode: LaunchMode.externalApplication,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Descargar actualizacion'),
          ),
        ],
      );
    },
  );
}
