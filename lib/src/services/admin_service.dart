import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _db = Supabase.instance.client;

  /// true если запись admin_users(uid) существует и is_admin == true
  Stream<bool> streamIsAdmin(String uid) {
    final stream = _db.from('admin_users').stream(primaryKey: ['uid']);

    return stream.map((rows) {
      final row = rows.cast<Map<String, dynamic>>().firstWhere(
            (r) => r['uid']?.toString() == uid,
            orElse: () => <String, dynamic>{},
          );
      final isAdmin = row['is_admin'] ?? row['isAdmin'] ?? false;
      return isAdmin == true;
    });
  }

  Future<bool> isAdminOnce(String uid) async {
    final row = await _db.from('admin_users').select('is_admin').eq('uid', uid).maybeSingle();
    return row?['is_admin'] == true;
  }
}