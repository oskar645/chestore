import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Профиль (имя, телефон и т.д.)
  Stream<Map<String, dynamic>> streamProfile(String uid) {
    final stream = _db
        .from('users')
        .stream(primaryKey: ['id']);

    return stream.map((rows) {
      final row = rows.cast<Map<String, dynamic>>().firstWhere(
            (r) => r['id']?.toString() == uid,
            orElse: () => <String, dynamic>{},
          );
      return row;
    });
  }

  /// Один раз получить профиль
  Future<Map<String, dynamic>> getProfile(String uid) async {
    final row = await _db.from('users').select().eq('id', uid).maybeSingle();
    return row ?? <String, dynamic>{};
  }

  /// Обновление профиля (ник, телефон и т.п.)
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.from('users').upsert({
      'id': uid,
      ...data,
    }, onConflict: 'id');
  }

  /// Количество моих объявлений
  Stream<int> streamMyListingsCount(String uid) {
    final stream = _db
        .from('listings')
        .stream(primaryKey: ['id']);

    return stream.map((rows) {
      return rows.where((r) => r['owner_id']?.toString() == uid).length;
    });
  }

  // ===============================
  // ✅ РЕЙТИНГ И ОТЗЫВЫ ПРОДАВЦА
  // ===============================

  Stream<double> streamMyRatingAvg(String uid) {
    final stream = _db
        .from('reviews')
        .stream(primaryKey: ['id']);

    return stream.map((rows) {
      final my = rows.where((r) => r['seller_id']?.toString() == uid).toList();
      if (my.isEmpty) return 0.0;

      final sum = my.fold<num>(
        0,
        (p, r) => p + ((r['rating'] as num?) ?? 0),
      );

      return (sum / my.length).toDouble();
    });
  }

  Stream<int> streamMyReviewsCount(String uid) {
    final stream = _db
        .from('reviews')
        .stream(primaryKey: ['id']);

    return stream.map((rows) {
      return rows.where((r) => r['seller_id']?.toString() == uid).length;
    });
  }
}