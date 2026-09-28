import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';
import 'mayoreo_invoice_reconciliation.dart';

class MayoreoInvoiceClient {
  final String key;
  final String name;
  const MayoreoInvoiceClient(this.key, this.name);
}

class MayoreoManagedInvoiceTicket {
  final MayoreoInvoiceTicket ticket;
  final bool used;
  final bool eligible;
  final String eligibilityReason;
  final List<String> claimIds;
  final String? usageOrigin;

  const MayoreoManagedInvoiceTicket({
    required this.ticket,
    required this.used,
    required this.eligible,
    required this.claimIds,
    this.eligibilityReason = '',
    this.usageOrigin,
  });

  String get key => '${ticket.clientKey}\u0000${ticket.ticketKey}';
  String get statusLabel => used
      ? usageOrigin == 'reconciliation'
            ? 'Usada en conciliación'
            : 'Marcada como usada'
      : eligible
      ? 'Disponible'
      : 'Sin usar · $eligibilityReason';

  factory MayoreoManagedInvoiceTicket.fromJson(Map<String, dynamic> json) =>
      MayoreoManagedInvoiceTicket(
        ticket: MayoreoInvoiceTicket.fromJson(json),
        used: json['used'] as bool,
        eligible: json['eligible'] as bool,
        claimIds: (json['claim_ids'] as List).cast<String>(),
        eligibilityReason: json['eligibility_reason'] as String? ?? '',
        usageOrigin: json['usage_origin'] as String?,
      );
}

class MayoreoInvoiceHistory {
  final String id;
  final String clientName;
  final int targetCents;
  final int totalCents;
  final String reference;
  final DateTime createdAt;
  final bool historical;

  const MayoreoInvoiceHistory({
    required this.id,
    required this.clientName,
    required this.targetCents,
    required this.totalCents,
    required this.reference,
    required this.createdAt,
    this.historical = false,
  });

  factory MayoreoInvoiceHistory.fromJson(Map<String, dynamic> json) =>
      MayoreoInvoiceHistory(
        id: json['id'] as String,
        clientName: json['client_name'] as String,
        targetCents: (json['target_cents'] as num).toInt(),
        totalCents: (json['total_cents'] as num).toInt(),
        reference: json['reference'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        historical: json['origin'] == 'historical',
      );
}

abstract class MayoreoInvoiceRepository {
  Future<List<MayoreoManagedInvoiceTicket>> loadTickets();
  Future<MayoreoManagedInvoiceTicket> setTicketUsed({
    required String requestId,
    required MayoreoManagedInvoiceTicket ticket,
    required bool used,
  });
  Future<List<MayoreoInvoiceClient>> loadClients();
  Future<List<MayoreoInvoiceTicket>> loadCandidates(String clientKey);
  Future<List<MayoreoInvoiceHistory>> loadHistory(int offset);
  Future<List<MayoreoInvoiceTicket>> loadDetails(String reconciliationId);
  Future<MayoreoInvoiceHistory> save({
    required String requestId,
    required String clientKey,
    required MayoreoInvoiceMatch match,
    required String reference,
  });
}

class SupabaseMayoreoInvoiceRepository implements MayoreoInvoiceRepository {
  final SupabaseClient client;
  SupabaseMayoreoInvoiceRepository(this.client);

  @override
  Future<List<MayoreoManagedInvoiceTicket>> loadTickets() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => client
          .from('mayoreo_invoice_ticket_catalog')
          .select()
          .order('sale_date', ascending: false)
          .order('ticket_key')
          .order('client_key')
          .range(from, to),
    );
    return rows.map(MayoreoManagedInvoiceTicket.fromJson).toList();
  }

  @override
  Future<MayoreoManagedInvoiceTicket> setTicketUsed({
    required String requestId,
    required MayoreoManagedInvoiceTicket ticket,
    required bool used,
  }) async {
    final result = await client.rpc(
      'mayoreo_set_invoice_ticket_usage',
      params: {
        'p_request_id': requestId,
        'p_client_key': ticket.ticket.clientKey,
        'p_ticket_key': ticket.ticket.ticketKey,
        'p_used': used,
        'p_expected_claim_ids': ticket.claimIds,
        'p_snapshot': ticket.ticket.toProposalJson(),
      },
    );
    return MayoreoManagedInvoiceTicket.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<List<MayoreoInvoiceClient>> loadClients() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => client
          .rpc('mayoreo_invoice_reconciliation_clients')
          .select()
          .order('client_name')
          .order('client_key')
          .range(from, to),
    );
    return rows
        .map(
          (row) => MayoreoInvoiceClient(
            row['client_key'] as String,
            row['client_name'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<MayoreoInvoiceTicket>> loadCandidates(String clientKey) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => client
          .from('mayoreo_invoice_available_tickets')
          .select()
          .eq('client_key', clientKey)
          .order('sale_date', ascending: false)
          .order('ticket_key')
          .range(from, to),
    );
    return rows.map(MayoreoInvoiceTicket.fromJson).toList();
  }

  @override
  Future<List<MayoreoInvoiceHistory>> loadHistory(int offset) async {
    final rows = await client
        .from('mayoreo_invoice_reconciliations')
        .select()
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 39);
    return rows.map(MayoreoInvoiceHistory.fromJson).toList();
  }

  @override
  Future<List<MayoreoInvoiceTicket>> loadDetails(
    String reconciliationId,
  ) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => client
          .from('mayoreo_invoice_reconciliation_tickets')
          .select()
          .eq('reconciliation_id', reconciliationId)
          .order('sale_date', ascending: false)
          .order('ticket_key')
          .range(from, to),
    );
    return rows.map(MayoreoInvoiceTicket.fromJson).toList();
  }

  @override
  Future<MayoreoInvoiceHistory> save({
    required String requestId,
    required String clientKey,
    required MayoreoInvoiceMatch match,
    required String reference,
  }) async {
    final result = await client.rpc(
      'mayoreo_save_invoice_reconciliation',
      params: {
        'p_id': requestId,
        'p_client_key': clientKey,
        'p_target_cents': match.targetCents,
        'p_tickets': match.tickets.map((row) => row.toProposalJson()).toList(),
        'p_reference': reference.trim(),
      },
    );
    return MayoreoInvoiceHistory.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
