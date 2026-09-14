part of '../human_resources_prenomina_page.dart';

class _PrenominaPublicationDialog extends StatelessWidget {
  final String title;
  final String period;
  final String message;
  final List<String> details;
  final String? confirmLabel;
  final double? progress;

  const _PrenominaPublicationDialog({
    required this.title,
    required this.period,
    required this.message,
    this.details = const [],
    this.confirmLabel,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = humanResourcesAreaTokens;
    return AlertDialog(
      backgroundColor: tokens.fieldSurface.withValues(alpha: 1),
      surfaceTintColor: Colors.transparent,
      scrollable: true,
      title: Text(
        title,
        style: TextStyle(color: tokens.onGlass, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 580,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: tokens.onGlass),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                period,
                style: TextStyle(
                  color: tokens.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(message),
              if (progress != null) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: progress, color: tokens.accent),
              ],
              for (final detail in details) ...[
                const SizedBox(height: 14),
                Text(detail),
              ],
            ],
          ),
        ),
      ),
      actions: progress != null
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: tokens.onGlass),
                child: Text(confirmLabel == null ? 'Entendido' : 'Cancelar'),
              ),
              if (confirmLabel != null)
                FilledButton(
                  key: const ValueKey('confirm-publish-all'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.primaryStrong,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel!),
                ),
            ],
    );
  }
}
