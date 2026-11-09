import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Printable route data deliberately excludes internal notes/indications.
class LogisticsRoutePrintData {
  const LogisticsRoutePrintData({
    required this.id,
    required this.date,
    required this.minutes,
    required this.vehicleId,
    required this.vehicle,
    required this.driverId,
    required this.driver,
    required this.company,
    required this.movement,
    required this.material,
  });

  final String id;
  final DateTime? date;
  final int? minutes;
  final String? vehicleId;
  final String vehicle;
  final String? driverId;
  final String driver;
  final String company;
  final String movement;
  final String material;

  String get timeLabel => minutes == null
      ? 'Sin horario'
      : '${_two(minutes! ~/ 60)}:${_two(minutes! % 60)}';
}

class LogisticsRouteAgenda {
  LogisticsRouteAgenda(List<LogisticsRoutePrintData> routes)
    : routes = List.unmodifiable(routes);

  final List<LogisticsRoutePrintData> routes;
  DateTime? get date => routes.first.date;
  String get vehicle => _or(routes.first.vehicle, 'Unidad pendiente');
  String get driver => _or(routes.first.driver, 'Chofer pendiente');
}

/// Keep distinct assignments separate even when their visible labels coincide.
List<LogisticsRouteAgenda> groupLogisticsRouteAgendas(
  List<LogisticsRoutePrintData> routes,
) {
  final grouped =
      <(DateTime?, String, String), List<LogisticsRoutePrintData>>{};
  String identity(String? id, String label) => id?.trim().isNotEmpty == true
      ? 'id:${id!.trim()}'
      : 'label:${label.trim().toUpperCase()}';
  for (final route in routes) {
    final d = route.date;
    final key = (
      d == null ? null : DateTime(d.year, d.month, d.day),
      identity(route.vehicleId, route.vehicle),
      identity(route.driverId, route.driver),
    );
    grouped.putIfAbsent(key, () => []).add(route);
  }
  final agendas = [
    for (final group in grouped.values)
      LogisticsRouteAgenda(
        group..sort((a, b) {
          final byTime = (a.minutes ?? 1440).compareTo(b.minutes ?? 1440);
          if (byTime != 0) return byTime;
          final byCompany = a.company.compareTo(b.company);
          return byCompany != 0 ? byCompany : a.id.compareTo(b.id);
        }),
      ),
  ];
  int compareLabel(String a, String b) {
    String sortable(String value) => value.toUpperCase().replaceAllMapped(
      RegExp(r'\d+'),
      (m) => m[0]!.padLeft(12, '0'),
    );
    return sortable(a).compareTo(sortable(b));
  }

  agendas.sort((a, b) {
    final ad = a.date;
    final bd = b.date;
    final byDate =
        (ad == null ? DateTime(9999) : DateTime(ad.year, ad.month, ad.day))
            .compareTo(
              bd == null ? DateTime(9999) : DateTime(bd.year, bd.month, bd.day),
            );
    if (byDate != 0) return byDate;
    final byVehicle = compareLabel(a.vehicle, b.vehicle);
    if (byVehicle != 0) return byVehicle;
    final byDriver = compareLabel(a.driver, b.driver);
    return byDriver != 0
        ? byDriver
        : a.routes.first.id.compareTo(b.routes.first.id);
  });
  return agendas;
}

const _ink = PdfColor.fromInt(0xFF202831);
const _muted = PdfColor.fromInt(0xFF59636E);
const _line = PdfColor.fromInt(0xFFC4CBD1);
const _soft = PdfColor.fromInt(0xFFE9EDF0);
const _paper = PdfColor.fromInt(0xFFF6F7F8);
const _accent = PdfColor.fromInt(0xFF147B72);
const _gap = 12.0;
final _laneWidth = (PdfPageFormat.a4.landscape.width - 48 - 2 * _gap) / 3;
const _boardHeight = 425.0;
final _textWidth = _laneWidth - 42;

class _Line {
  const _Line(this.text, this.size, this.height, {this.bold = false});
  final String text;
  final double size;
  final double height;
  final bool bold;

  pw.Widget build() => pw.SizedBox(
    height: height,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: bold ? _ink : _muted,
      ),
    ),
  );
}

class _RouteCard {
  const _RouteCard(
    this.route,
    this.number,
    this.lines, {
    this.continued = false,
  });
  final LogisticsRoutePrintData route;
  final int number;
  final List<_Line> lines;
  final bool continued;
  double get height => 43 + lines.fold(0.0, (h, line) => h + line.height);

  pw.Widget build() => pw.Container(
    height: height - 8,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(5),
      border: pw.Border.all(color: _line, width: .55),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              route.timeLabel,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: route.minutes == null ? _muted : _accent,
              ),
            ),
            pw.Text(
              '$number${continued ? ' (cont.)' : ''}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        ...lines.map((line) => line.build()),
      ],
    ),
  );
}

class _Lane {
  _Lane(this.agenda, this.heading, this.cards, this.part);
  final LogisticsRouteAgenda agenda;
  final List<_Line> heading;
  final List<_RouteCard> cards;
  final int part;

  pw.Widget build() => pw.Container(
    width: _laneWidth,
    height: _boardHeight,
    decoration: pw.BoxDecoration(
      color: _paper,
      border: pw.Border.all(color: _line, width: .6),
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _soft,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(6),
              topRight: pw.Radius.circular(6),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...heading.map((line) => line.build()),
              pw.SizedBox(height: 5),
              pw.Text(
                'Rutas ${cards.first.number}-${cards.last.number} de ${agenda.routes.length}'
                '${part > 1 ? ' · Continuación $part' : ''}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Column(
            children: cards.map((card) => card.build()).toList(),
          ),
        ),
      ],
    ),
  );
}

/// A landscape day board: three unit/driver agendas per sheet, with measured
/// continuations. Long routes are split at line boundaries, never clipped.
Future<Uint8List> buildLogisticsRoutesPdf({
  required List<LogisticsRoutePrintData> routes,
  required bool isTodayDispatch,
  required DateTime generatedAt,
}) async {
  if (routes.isEmpty) throw ArgumentError('No hay rutas para imprimir.');
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load(
      'assets/images/logo_dicsa.png',
    )).buffer.asUint8List(),
  );
  final title = isTodayDispatch ? 'DESPACHO DE HOY' : 'CALENDARIO DE RUTAS';
  final document = pw.Document(
    title: 'DICSA | $title',
    author: 'DICSA',
    creator: 'DICSA - Logística',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final context = pw.Context(document: document.document);
  final regularMetrics = regular.getFont(context);
  final boldMetrics = bold.getFont(context);
  List<_Line> lines(
    String text,
    double size,
    double height, {
    bool strong = false,
    double? width,
  }) => [
    for (final line in _wrap(
      text,
      strong ? boldMetrics : regularMetrics,
      width ?? _textWidth,
      size,
    ))
      _Line(line, size, height, bold: strong),
  ];
  final days = <DateTime?, List<LogisticsRouteAgenda>>{};
  for (final agenda in groupLogisticsRouteAgendas(routes)) {
    final date = agenda.date;
    final day = date == null ? null : DateTime(date.year, date.month, date.day);
    days.putIfAbsent(day, () => []).add(agenda);
  }
  final sheets =
      <
        ({
          DateTime? date,
          List<LogisticsRouteAgenda> agendas,
          List<_Lane> lanes,
        })
      >[];
  for (final day in days.entries) {
    final lanes = <_Lane>[];
    for (final agenda in day.value) {
      final heading = [
        ...lines(
          'UNIDAD · ${agenda.vehicle}',
          12,
          15,
          strong: true,
          width: _laneWidth - 22,
        ),
        ...lines('CHOFER · ${agenda.driver}', 10, 13, width: _laneWidth - 22),
      ];
      final capacity =
          _boardHeight - 58 - heading.fold(0.0, (h, line) => h + line.height);
      if (capacity < 90) {
        throw ArgumentError(
          'El nombre de unidad o chofer es demasiado largo para imprimir.',
        );
      }
      var cards = <_RouteCard>[];
      var used = 0.0;
      var part = 1;
      void finishLane() {
        if (cards.isEmpty) return;
        lanes.add(_Lane(agenda, heading, cards, part++));
        cards = [];
        used = 0;
      }

      for (var index = 0; index < agenda.routes.length; index++) {
        final route = agenda.routes[index];
        final detail = [
          ...lines(
            _or(route.company, 'Empresa pendiente'),
            11,
            14,
            strong: true,
          ),
          ...lines(_or(route.movement, 'Movimiento pendiente'), 9.5, 12),
          ...lines('Material: ${_or(route.material, 'Pendiente')}', 10, 13),
        ];
        // Prefer a whole route on the next lane; split only oversized routes.
        final whole = _RouteCard(route, index + 1, detail);
        if (cards.isNotEmpty && used + whole.height > capacity) finishLane();
        var remaining = detail;
        var continued = false;
        while (remaining.isNotEmpty) {
          final chunk = <_Line>[];
          var height = 43.0;
          for (final line in remaining) {
            if (height + line.height > capacity - used) break;
            chunk.add(line);
            height += line.height;
          }
          if (chunk.isEmpty) {
            finishLane();
            continue;
          }
          cards.add(_RouteCard(route, index + 1, chunk, continued: continued));
          used += height;
          remaining = remaining.sublist(chunk.length);
          if (remaining.isNotEmpty) finishLane();
          continued = true;
        }
      }
      finishLane();
    }
    for (var start = 0; start < lanes.length; start += 3) {
      sheets.add((
        date: day.key,
        agendas: day.value,
        lanes: lanes.sublist(start, math.min(start + 3, lanes.length)),
      ));
    }
  }
  for (var page = 0; page < sheets.length; page++) {
    final sheet = sheets[page];
    final date = sheet.date;
    final count = sheet.agendas.fold(0, (total, a) => total + a.routes.length);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.SizedBox(
              height: 76,
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 62,
                    height: 64,
                    decoration: pw.BoxDecoration(
                      color: _soft,
                      borderRadius: pw.BorderRadius.circular(7),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          date == null
                              ? 'S/F'
                              : _weekdays[date.weekday - 1].toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: _muted,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          date == null ? '-' : _two(date.day),
                          style: pw.TextStyle(
                            fontSize: 28,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 18,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          date == null
                              ? 'Sin fecha programada'
                              : '${_weekdays[date.weekday - 1]}, ${date.day} de ${_months[date.month - 1]} de ${date.year}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: _ink,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Control Diario de Logística · $count rutas del día · ${sheet.agendas.length} agendas de unidad / chofer',
                          style: const pw.TextStyle(fontSize: 9, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  pw.Image(logo, width: 56, height: 48, fit: pw.BoxFit.contain),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var lane = 0; lane < sheet.lanes.length; lane++) ...[
                  if (lane > 0) pw.SizedBox(width: _gap),
                  sheet.lanes[lane].build(),
                ],
              ],
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _line, width: .5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DICSA · Agenda por unidad y chofer · Horarios en formato de 24 h',
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                  pw.Text(
                    'Emitido ${_two(generatedAt.day)}/${_two(generatedAt.month)}/${generatedAt.year} · Hoja ${page + 1} de ${sheets.length}',
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  return document.save();
}

List<String> _wrap(String input, PdfFont font, double width, double size) {
  final result = <String>[];
  for (final paragraph in input.replaceAll('\r', '').split('\n')) {
    var line = '';
    for (final word
        in paragraph.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      final next = line.isEmpty ? word : '$line $word';
      if (font.stringMetrics(next).width * size <= width) {
        line = next;
        continue;
      }
      if (line.isNotEmpty) result.add(line);
      line = '';
      for (final rune in word.runes) {
        final char = String.fromCharCode(rune);
        if (line.isNotEmpty &&
            font.stringMetrics('$line$char').width * size > width) {
          result.add(line);
          line = '';
        }
        line += char;
      }
    }
    result.add(line);
  }
  return result;
}

String _or(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();
String _two(int value) => value.toString().padLeft(2, '0');
const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
