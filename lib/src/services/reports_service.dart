import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<void> reportListing({
    required String listingId,
    required String listingOwnerId,
    required String reporterId,
    required String reason,
    required String comment,
  }) async {
    await _db.from('reports').insert({
      'listing_id': listingId,
      'listing_owner_id': listingOwnerId,
      'reporter_id': reporterId,
      'reason': reason,
      'comment': comment.trim(),
      'status': 'open',
      'created_at': DateTime.now().toUtc(),
      'handled_at': null,
      'handled_by': null,
      'admin_note': null,
    });
  }

  Stream<List<Map<String, dynamic>>> streamOpenReports() {
    final stream = _db
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return stream.map((rows) {
      return rows
          .where((r) => (r['status'] ?? '').toString() == 'open')
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    });
  }

  Future<void> closeReport({
    required String reportId,
    required String adminUid,
    String? adminNote,
    required String result, // 'closed' | 'deleted_listing' | 'warning'
  }) async {
    await _db.from('reports').update({
      'status': result,
      'handled_at': DateTime.now().toUtc(),
      'handled_by': adminUid,
      'admin_note': (adminNote ?? '').trim().isEmpty ? null : adminNote!.trim(),
    }).eq('id', reportId);
  }
}