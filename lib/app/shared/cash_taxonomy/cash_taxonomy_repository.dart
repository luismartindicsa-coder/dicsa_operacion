import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CashTaxonomyRepository {
  CashTaxonomyRepository._();

  static final CashTaxonomyRepository instance = CashTaxonomyRepository._();

  SupabaseClient get _supa => Supabase.instance.client;

  Future<Map<String, dynamic>?> loadArea(String area) async {
    try {
      final row = await _supa
          .from('cash_taxonomy_configs')
          .select('payload')
          .eq('area', area)
          .maybeSingle();
      if (row == null) return null;
      final payload = row['payload'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'CashTaxonomyRepository.loadArea($area) failed: $error\n$stackTrace',
      );
    }
    return null;
  }

  Future<void> saveArea(String area, Map<String, dynamic> payload) async {
    try {
      await _supa.from('cash_taxonomy_configs').upsert({
        'area': area,
        'payload': payload,
      }, onConflict: 'area');
    } catch (error, stackTrace) {
      debugPrint(
        'CashTaxonomyRepository.saveArea($area) failed: $error\n$stackTrace',
      );
    }
  }
}
