import 'dart:math' as math;
import 'dart:typed_data';

/// Money is kept in integer cents throughout selection and persistence.
int? parseReconciliationCents(String input) {
  final text = input.trim().replaceFirst(RegExp(r'^\$\s*'), '');
  if (!RegExp(r'^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }
  final parts = text.replaceAll(',', '').split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null || whole > 9999999999) return null;
  final cents =
      whole * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  return cents > 0 ? cents : null;
}

class MayoreoInvoiceTicket {
  final String clientKey;
  final String clientName;
  final String ticketKey;
  final String ticket;
  final DateTime saleDate;
  final int amountCents;
  final List<String> sourceIds;
  final List<Map<String, dynamic>> details;
  final DateTime? releasedAt;

  const MayoreoInvoiceTicket({
    required this.clientKey,
    required this.clientName,
    required this.ticketKey,
    required this.ticket,
    required this.saleDate,
    required this.amountCents,
    required this.sourceIds,
    this.details = const [],
    this.releasedAt,
  });

  factory MayoreoInvoiceTicket.fromJson(Map<String, dynamic> json) =>
      MayoreoInvoiceTicket(
        clientKey: json['client_key'] as String,
        clientName: json['client_name'] as String,
        ticketKey: json['ticket_key'] as String,
        ticket: json['ticket'] as String,
        saleDate: DateTime.parse(json['sale_date'] as String),
        amountCents: (json['amount_cents'] as num).toInt(),
        sourceIds: (json['source_ids'] as List).cast<String>(),
        details: (json['details'] as List? ?? [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(),
        releasedAt: DateTime.tryParse(json['released_at'] as String? ?? ''),
      );

  Map<String, dynamic> toProposalJson() => {
    'ticket_key': ticketKey,
    'amount_cents': amountCents,
    'source_ids': sourceIds,
    'details': details,
  };
}

class MayoreoInvoiceMatch {
  final List<MayoreoInvoiceTicket> tickets;
  final int targetCents;

  /// False only when a very large search required conservative quantization.
  final bool exhaustive;

  const MayoreoInvoiceMatch({
    required this.tickets,
    required this.targetCents,
    required this.exhaustive,
  });

  int get totalCents => tickets.fold(0, (sum, row) => sum + row.amountCents);
  int get missingCents => targetCents - totalCents;
}

class MayoreoInvoiceSearch {
  final List<MayoreoInvoiceTicket> candidates;
  final String clientKey;
  final int targetCents;

  const MayoreoInvoiceSearch(this.candidates, this.clientKey, this.targetCents);
}

/// 0/1 subset sum: every complete ticket can be used at most once.
/// Bitset shifts run descending, with immutable first-discovery predecessors.
/// GCD compression preserves exact cents. Oversized searches round each ticket
/// UP, so even their approximate results can never exceed the requested amount.
MayoreoInvoiceMatch findMayoreoInvoiceMatch(MayoreoInvoiceSearch request) {
  final target = request.targetCents;
  if (target <= 0) throw ArgumentError.value(target, 'targetCents');
  final seen = <String>{};
  final rows =
      request.candidates
          .where(
            (row) =>
                row.clientKey == request.clientKey &&
                row.amountCents > 0 &&
                row.amountCents <= target &&
                seen.add(row.ticketKey),
          )
          .toList()
        ..sort((a, b) {
          final amount = b.amountCents.compareTo(a.amountCents);
          if (amount != 0) return amount;
          final date = b.saleDate.compareTo(a.saleDate);
          return date != 0 ? date : a.ticketKey.compareTo(b.ticketKey);
        });
  MayoreoInvoiceMatch result(List<MayoreoInvoiceTicket> chosen, bool exact) {
    chosen.sort((a, b) {
      final date = b.saleDate.compareTo(a.saleDate);
      return date != 0 ? date : a.ticket.compareTo(b.ticket);
    });
    return MayoreoInvoiceMatch(
      tickets: chosen,
      targetCents: target,
      exhaustive: exact,
    );
  }

  if (rows.isEmpty) return result([], true);
  if (rows.fold<int>(0, (sum, row) => sum + row.amountCents) <= target) {
    return result(rows, true);
  }
  final divisor = rows.map((row) => row.amountCents).reduce((a, b) => a.gcd(b));
  final units = target ~/ divisor;
  // At most 80 MB of predecessors and 160 million word operations.
  final capacity = math.min(
    20000000,
    math.max(10000, 160000000 * 32 ~/ rows.length),
  );
  final quantum = (units + capacity - 1) ~/ capacity;
  final limit = units ~/ quantum;
  final values = rows
      .map((row) => ((row.amountCents ~/ divisor) + quantum - 1) ~/ quantum)
      .toList();
  final bits = Uint32List((limit >> 5) + 1)..[0] = 1;
  final parent = Int32List(limit + 1);
  var reachableMax = 0;
  for (var index = 0; index < rows.length; index++) {
    final value = values[index];
    if (value > limit) continue;
    final wordShift = value >> 5;
    final bitShift = value & 31;
    final nextMax = math.min(limit, reachableMax + value);
    for (var word = nextMax >> 5; word >= wordShift; word--) {
      var shifted = (bits[word - wordShift] << bitShift) & 0xffffffff;
      if (bitShift != 0 && word > wordShift) {
        shifted |= bits[word - wordShift - 1] >> (32 - bitShift);
      }
      if (word == limit >> 5 && (limit & 31) != 31) {
        shifted &= (1 << ((limit & 31) + 1)) - 1;
      }
      var added = shifted & ~bits[word];
      bits[word] |= shifted;
      while (added != 0) {
        final bit = (added & -added).bitLength - 1;
        parent[(word << 5) + bit] = index + 1;
        added &= added - 1;
      }
    }
    reachableMax = nextMax;
    if ((bits[limit >> 5] & (1 << (limit & 31))) != 0) break;
  }
  var best = limit;
  while (best > 0 && (bits[best >> 5] & (1 << (best & 31))) == 0) {
    best--;
  }
  final selected = <MayoreoInvoiceTicket>[];
  while (best > 0) {
    final index = parent[best] - 1;
    selected.add(rows[index]);
    best -= values[index];
  }
  // A simple exact-cent baseline also protects small selections near a rounded
  // boundary (e.g. a single ticket exactly equal to the requested total).
  if (quantum > 1) {
    final greedy = <MayoreoInvoiceTicket>[];
    var sum = 0;
    for (final row in rows) {
      if (sum + row.amountCents <= target) {
        greedy.add(row);
        sum += row.amountCents;
      }
    }
    if (sum > selected.fold<int>(0, (sum, row) => sum + row.amountCents)) {
      return result(greedy, sum == target);
    }
  }
  return result(selected, quantum == 1);
}
