import 'dart:io';

const int menudeoTicketPrintCopies = 2;

typedef MenudeoPrintProcess =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Sends each receipt as its own Windows print job, using the installed PDF
/// application's existing Print action. A two-page job can feed both receipts
/// together on a thermal printer configured to cut at the end of each job.
class MenudeoTicketPrinter {
  static final instance = MenudeoTicketPrinter();

  final MenudeoPrintProcess _runProcess;
  Future<void> _pending = Future<void>.value();

  MenudeoTicketPrinter({MenudeoPrintProcess? runProcess})
    : _runProcess = runProcess ?? _run;

  static Future<ProcessResult> _run(
    String executable,
    List<String> arguments,
  ) => Process.run(executable, arguments);

  Future<void> printCopies(File singlePagePdf) {
    // Keep each pair together even if another ticket is requested meanwhile.
    final result = _pending.then((_) => _sendCopies(singlePagePdf));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _sendCopies(File singlePagePdf) async {
    var sent = 0;
    try {
      final directory = await singlePagePdf.parent.createTemp('menudeo_print_');
      final name = singlePagePdf.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final files = <File>[];
      for (var copy = 1; copy <= menudeoTicketPrintCopies; copy++) {
        files.add(
          await singlePagePdf.copy(
            '${directory.path}${Platform.pathSeparator}${name}_copia_$copy.pdf',
          ),
        );
      }

      for (final file in files) {
        // Separate paths prevent a PDF viewer from reusing the same document
        // for both requests. Do not delete them: the viewer reads asynchronously.
        final escapedPath = file.path.replaceAll("'", "''");
        final result = await _runProcess('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "\$ErrorActionPreference = 'Stop'; "
              "Start-Process -FilePath '$escapedPath' -Verb Print -ErrorAction Stop",
        ]);
        if (result.exitCode != 0) {
          throw ProcessException(
            'powershell',
            const [],
            result.stderr.toString().trim(),
            result.exitCode,
          );
        }
        sent++;
      }
    } catch (error) {
      // Never retry both copies after a partial dispatch: that could duplicate
      // a receipt already accepted by the PDF application.
      throw MenudeoTicketPrintException(copiesSent: sent, cause: error);
    }
  }
}

class MenudeoTicketPrintException implements Exception {
  final int copiesSent;
  final Object cause;

  const MenudeoTicketPrintException({
    required this.copiesSent,
    required this.cause,
  });

  @override
  String toString() => copiesSent == 0
      ? 'No se pudo enviar el ticket a impresión. Revisa la impresora y el programa para abrir PDF.'
      : 'Se envió $copiesSent de $menudeoTicketPrintCopies copias y falló el envío de la siguiente. Revisa la cola de impresión antes de volver a imprimir.';
}
