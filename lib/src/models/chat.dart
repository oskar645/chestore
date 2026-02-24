
// lib/src/models/chat.dart
class Chat {
  final String id;

  final String listingId;
  final String listingTitle;

  final List<String> memberIds; // uuid[]
  final Map<String, String> memberEmails; // jsonb {uid: email/name}

  final String lastMessage;
  final DateTime updatedAt; // timestamptz

  final Map<String, int> unread; // jsonb {uid: count}

  Chat({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.memberIds,
    required this.memberEmails,
    required this.lastMessage,
    required this.updatedAt,
    required this.unread,
  });

  int unreadFor(String uid) => unread[uid] ?? 0;

  // ===============================
  // SUPABASE: row -> Chat
  // ===============================
  factory Chat.fromMap(Map<String, dynamic> row) {
    DateTime parseDt(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseUuidArray(dynamic v) {
      if (v == null) return <String>[];
      if (v is List) return v.map((e) => e.toString()).toList();
      return <String>[];
    }

    Map<String, String> parseEmails(dynamic v) {
      final out = <String, String>{};
      if (v is Map) {
        v.forEach((k, val) {
          out[k.toString()] = (val ?? '').toString();
        });
      }
      return out;
    }

    Map<String, int> parseUnread(dynamic v) {
      final out = <String, int>{};
      if (v is Map) {
        v.forEach((k, val) {
          if (val is num) out[k.toString()] = val.toInt();
          if (val is String) out[k.toString()] = int.tryParse(val) ?? 0;
        });
      }
      return out;
    }

    return Chat(
      id: row['id']?.toString() ?? '',
      listingId: (row['listing_id'] ?? '').toString(),
      listingTitle: (row['listing_title'] ?? '').toString(),
      memberIds: parseUuidArray(row['member_ids']),
      memberEmails: parseEmails(row['member_emails']),
      lastMessage: (row['last_message'] ?? '').toString(),
      updatedAt: parseDt(row['updated_at']),
      unread: parseUnread(row['unread']),
    );
  }

  // ===============================
  // Chat -> map (для insert/update)
  // ===============================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'listing_id': listingId,
      'listing_title': listingTitle,
      'member_ids': memberIds,
      'member_emails': memberEmails,
      'last_message': lastMessage,
      'unread': unread,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}