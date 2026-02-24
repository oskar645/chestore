import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewsService {
  final SupabaseClient _c = Supabase.instance.client;

  // Все отзывы продавца (лента)
  Stream<List<Map<String, dynamic>>> streamSellerReviews(String sellerId) {
    final stream = _c
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);

    return stream.map((rows) => rows.cast<Map<String, dynamic>>());
  }

  // Рейтинг продавца: avg + count (считаем на клиенте)
  Stream<Map<String, dynamic>> streamSellerRating(String sellerId) {
    return streamSellerReviews(sellerId).map((items) {
      if (items.isEmpty) return {'avg': 0.0, 'count': 0};

      double sum = 0;
      int cnt = 0;
      for (final r in items) {
        final v = r['rating'];
        if (v is num) {
          sum += v.toDouble();
          cnt++;
        }
      }
      final avg = cnt == 0 ? 0.0 : sum / cnt;
      return {'avg': avg, 'count': cnt};
    });
  }

  Future<void> addReview({
    required String sellerId,
    required String reviewerId,
    required String reviewerName,
    required String listingId,
    required int rating,
    required String text,
  }) async {
    await _c.from('reviews').insert({
      'seller_id': sellerId,
      'reviewer_id': reviewerId,
      'reviewer_name': reviewerName,
      'listing_id': listingId,
      'rating': rating,
      'text': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> replyToReview({
    required String sellerId,
    required String reviewId,
    required String replyText,
  }) async {
    await _c.from('reviews').update({
      'reply_text': replyText,
      'reply_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reviewId).eq('seller_id', sellerId);
  }

  // Если у тебя это поле было во Firestore — пока делаем no-op, чтобы не ломать UI
  Future<void> resetNewReviewsCount(String sellerId) async {
    // Можно реализовать позже (например в users.new_reviews_count)
    return;
  }
}