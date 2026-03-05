import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _db = Supabase.instance.client;

  Stream<bool> streamIsAdmin(String uid) {
    final stream =
        _db.from('admin_users').stream(primaryKey: ['uid']).eq('uid', uid);

    return stream.map((rows) {
      if (rows.isEmpty) return false;
      final row = rows.first;
      return row['is_admin'] == true;
    });
  }

  Future<bool> isAdminOnce(String uid) async {
    final row = await _db
        .from('admin_users')
        .select('is_admin')
        .eq('uid', uid)
        .maybeSingle();

    return row?['is_admin'] == true;
  }

  Stream<int> streamPendingModerationCount() {
    return _db
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map((rows) => rows.length);
  }

  Stream<int> streamOpenReportsCount() {
    return _db.from('reports').stream(primaryKey: ['id']).map(
      (rows) => rows.where((r) => (r['status'] ?? '').toString() == 'open').length,
    );
  }

  Stream<int> streamUnreadSupportForAdminCount() {
    return _db.from('support_tickets').stream(primaryKey: ['id']).map(
      (rows) => rows.where((r) => r['unread_for_admin'] == true).length,
    );
  }

  Stream<bool> streamNeedsAttention() {
    final controller = StreamController<bool>.broadcast();

    int pending = 0;
    int reports = 0;
    int support = 0;

    StreamSubscription<int>? s1;
    StreamSubscription<int>? s2;
    StreamSubscription<int>? s3;

    void emit() {
      if (!controller.isClosed) {
        controller.add(pending > 0 || reports > 0 || support > 0);
      }
    }

    controller.onListen = () {
      s1 = streamPendingModerationCount().listen(
        (v) {
          pending = v;
          emit();
        },
        onError: controller.addError,
      );
      s2 = streamOpenReportsCount().listen(
        (v) {
          reports = v;
          emit();
        },
        onError: controller.addError,
      );
      s3 = streamUnreadSupportForAdminCount().listen(
        (v) {
          support = v;
          emit();
        },
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await s1?.cancel();
      await s2?.cancel();
      await s3?.cancel();
    };

    return controller.stream.distinct();
  }
}
