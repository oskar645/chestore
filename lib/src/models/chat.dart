// lib/src/models/chat.dart
class Chat {
  final String id;

  final String listingId;
  final String listingTitle;

  final String buyerId;
  final String sellerId;

  final String lastMessage;
  final DateTime updatedAt;

  final int unreadForBuyer;
  final int unreadForSeller;

  Chat({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.buyerId,
    required this.sellerId,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadForBuyer,
    required this.unreadForSeller,
  });

  String otherUserId(String myUid) {
    if (myUid == buyerId) return sellerId;
    return buyerId;
  }

  int unreadFor(String myUid) {
    if (myUid == buyerId) return unreadForBuyer;
    if (myUid == sellerId) return unreadForSeller;
    return 0;
  }

  static DateTime _parseDt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory Chat.fromMap(Map<String, dynamic> row) {
    return Chat(
      id: (row['id'] ?? '').toString(),
      listingId: (row['listing_id'] ?? '').toString(),
      listingTitle: (row['listing_title'] ?? '').toString(),
      buyerId: (row['buyer_id'] ?? '').toString(),
      sellerId: (row['seller_id'] ?? '').toString(),
      lastMessage: (row['last_message'] ?? '').toString(),
      updatedAt: _parseDt(row['updated_at']),
      unreadForBuyer: (row['unread_for_buyer'] as num?)?.toInt() ?? 0,
      unreadForSeller: (row['unread_for_seller'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'listing_id': listingId,
      'listing_title': listingTitle,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'last_message': lastMessage,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'unread_for_buyer': unreadForBuyer,
      'unread_for_seller': unreadForSeller,
    };
  }
}