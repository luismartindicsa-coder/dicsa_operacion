import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/menudeo/menudeo_ticket_pdf.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_ticket_printing.dart';
import 'package:flutter_test/flutter_test.dart';

const sampleRow = <String, dynamic>{
  'ticket': '59567',
  'date': '15/10/2026',
  'provider': 'PUBLICO GENERAL',
  'material': 'CARTON NACIONAL',
  'gross': 2690,
  'tare': 2450,
  'price': 1.5,
};

int pageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

String printedPath(List<String> arguments) => RegExp(
  r"-FilePath '((?:[^']|'')*)' -Verb Print",
).firstMatch(arguments.last)!.group(1)!.replaceAll("''", "'");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late File receipt;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('menudeo-print-test-');
    receipt = File('${temp.path}/ticket O\'Brien 59567.pdf');
    await receipt.writeAsBytes(
      await buildMenudeoTicketPdf(
        row: sampleRow,
        humidity: 0,
        trash: 0,
        premium: 0,
        exitOrderNumber: '',
        isSale: false,
        printedAt: DateTime(2026, 10, 15, 10, 2),
      ),
    );
  });
  tearDown(() => temp.delete(recursive: true));

  test(
    'one action dispatches two identical single-page documents sequentially',
    () async {
      final calls = <String>[];
      final firstStarted = Completer<void>();
      final allowFirstToFinish = Completer<void>();
      final printer = MenudeoTicketPrinter(
        runProcess: (executable, arguments) async {
          expect(executable, 'powershell');
          expect(arguments, contains('-NonInteractive'));
          expect(arguments.last, contains("\$ErrorActionPreference = 'Stop'"));
          expect(arguments.last, contains('-ErrorAction Stop'));
          final path = printedPath(arguments);
          calls.add(path);
          final bytes = await File(path).readAsBytes();
          expect(pageCount(bytes), 1);
          expect(bytes, await receipt.readAsBytes());
          if (calls.length == 1) {
            firstStarted.complete();
            await allowFirstToFinish.future;
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      final printing = printer.printCopies(receipt);
      await Future.any([firstStarted.future, printing]);
      expect(calls, hasLength(1));
      allowFirstToFinish.complete();
      await printing;
      expect(calls, hasLength(2));
      expect(calls.toSet(), hasLength(2));
      expect(calls[0], endsWith('_copia_1.pdf'));
      expect(calls[1], endsWith('_copia_2.pdf'));
      for (final path in calls) {
        expect(
          await File(path).exists(),
          isTrue,
          reason: 'PDF viewer may read the file after the shell returns',
        );
      }
    },
  );

  test(
    'overlapping tickets keep both copies together and use distinct files',
    () async {
      final paths = <String>[];
      final firstStarted = Completer<void>();
      final release = Completer<void>();
      final printer = MenudeoTicketPrinter(
        runProcess: (_, arguments) async {
          paths.add(printedPath(arguments));
          if (paths.length == 1) {
            firstStarted.complete();
            await release.future;
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      final first = printer.printCopies(receipt);
      await Future.any([firstStarted.future, first]);
      final second = printer.printCopies(receipt);
      await Future<void>.delayed(Duration.zero);
      expect(paths, hasLength(1));
      release.complete();
      await Future.wait([first, second]);
      expect(paths.toSet(), hasLength(4));
      expect(File(paths[0]).parent.path, File(paths[1]).parent.path);
      expect(File(paths[2]).parent.path, File(paths[3]).parent.path);
      expect(File(paths[0]).parent.path, isNot(File(paths[2]).parent.path));
    },
  );

  for (final failedCopy in [1, 2]) {
    test(
      'failure in copy $failedCopy reports partial dispatch without resending and lets later requests proceed',
      () async {
        var calls = 0;
        final printer = MenudeoTicketPrinter(
          runProcess: (_, _) async {
            calls++;
            return ProcessResult(
              1,
              calls == failedCopy ? 1 : 0,
              '',
              'Print failed',
            );
          },
        );
        await expectLater(
          printer.printCopies(receipt),
          throwsA(
            isA<MenudeoTicketPrintException>().having(
              (e) => e.copiesSent,
              'copiesSent',
              failedCopy - 1,
            ),
          ),
        );
        expect(calls, failedCopy);
        await printer.printCopies(receipt);
        expect(calls, failedCopy + 2);
      },
    );
  }

  test('missing PDF stops before any print command', () async {
    var calls = 0;
    final printer = MenudeoTicketPrinter(
      runProcess: (_, _) async {
        calls++;
        return ProcessResult(1, 0, '', '');
      },
    );
    await expectLater(
      printer.printCopies(File('${temp.path}/missing.pdf')),
      throwsA(
        isA<MenudeoTicketPrintException>().having(
          (e) => e.copiesSent,
          'copiesSent',
          0,
        ),
      ),
    );
    expect(calls, 0);
  });

  test(
    'purchase and sale keep the original receipt size, and desktop preview retains two pages',
    () async {
      for (final isSale in [false, true]) {
        final bytes = await buildMenudeoTicketPdf(
          row: sampleRow,
          humidity: 0,
          trash: 0,
          premium: 0,
          exitOrderNumber: 'OS-123',
          isSale: isSale,
          printedAt: DateTime(2026, 10, 15, 10, 2),
        );
        expect(pageCount(bytes), 1);
        final box = RegExp(
          r'/MediaBox\s*\[([^\]]+)\]',
        ).firstMatch(latin1.decode(bytes))!;
        final dimensions = box
            .group(1)!
            .trim()
            .split(RegExp(r'\s+'))
            .map(double.parse)
            .toList();
        expect(dimensions[2] * 25.4 / 72, closeTo(78, 0.01));
        expect(dimensions[3] * 25.4 / 72, closeTo(133, 0.01));
        final qaDir = Platform.environment['DICSA_PRINT_QA_DIR'];
        if (qaDir != null) {
          await Directory(qaDir).create(recursive: true);
          await File(
            '$qaDir/${isSale ? 'sale' : 'purchase'}.pdf',
          ).writeAsBytes(bytes);
        }
      }
      final preview = await buildMenudeoTicketPdf(
        row: sampleRow,
        humidity: 0,
        trash: 0,
        premium: 0,
        exitOrderNumber: '',
        isSale: false,
        copies: menudeoTicketPrintCopies,
      );
      expect(pageCount(preview), 2);
    },
  );
}
