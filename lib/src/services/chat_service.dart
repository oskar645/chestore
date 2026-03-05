import 'dart:io';

import 'package:chestore2/src/models/chat.dart';
import 'package:chestore2/src/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final SupabaseClient _db = Supabase.instance.client;
  final _uuid = const Uuid();

  // =========================
  // STREAMS
  // =========================

  /// Чаты пользователя (buyer_id или seller_id)
  Stream<List<Chat>> streamMyChats(String uid) {
    final stream = _db
        .from('chats')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false);

    return stream.map((rows) {
      final out = <Chat>[];

      for (final r in rows) {
        final buyerId = (r['buyer_id'] ?? '').toString();
        final sellerId = (r['seller_id'] ?? '').toString();
        if (buyerId != uid && sellerId != uid) continue;

        out.add(Chat.fromMap(Map<String, dynamic>.from(r)));
      }

      out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return out;
    });
  }

  Stream<int> streamUnreadTotal(String uid) {
    final stream = _db.from('chats').stream(primaryKey: ['id']);

    return stream.map((rows) {
      int total = 0;

      for (final r in rows) {
        final buyerId = (r['buyer_id'] ?? '').toString();
        final sellerId = (r['seller_id'] ?? '').toString();
        if (buyerId != uid && sellerId != uid) continue;

        final ub = (r['unread_for_buyer'] as num?)?.toInt() ?? 0;
        final us = (r['unread_for_seller'] as num?)?.toInt() ?? 0;

        total += (uid == buyerId) ? ub : us;
      }

      return total;
    });
  }

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    final stream = _db
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return stream.map((rows) {
      final out = <ChatMessage>[];
      for (final r in rows) {
        if ((r['chat_id'] ?? '').toString() != chatId) continue;
        out.add(ChatMessage.fromMap(Map<String, dynamic>.from(r)));
      }
      return out;
    });
  }

  // =========================
  // GET / CREATE CHAT
  // =========================

  Future<String> getOrCreateChat({
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String sellerId,
  }) async {
    final existing = await _db
        .from('chats')
        .select('id')
        .eq('listing_id', listingId)
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      return existing['id'].toString();
    }

    final newId = _uuid.v4();

    await _db.from('chats').insert({
      'id': newId,
      'listing_id': listingId,
      'listing_title': listingTitle,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'last_message': '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'unread_for_buyer': 0,
      'unread_for_seller': 0,
    });

    return newId;
  }

  // =========================
  // READ
  // =========================

  Future<void> markChatRead({
    required String chatId,
    required String uid,
  }) async {
    final chat = await _db
        .from('chats')
        .select('buyer_id, seller_id')
        .eq('id', chatId)
        .maybeSingle();

    if (chat == null) return;

    final buyerId = (chat['buyer_id'] ?? '').toString();
    final sellerId = (chat['seller_id'] ?? '').toString();

    if (uid == buyerId) {
      await _db.from('chats').update({'unread_for_buyer': 0}).eq('id', chatId);
    } else if (uid == sellerId) {
      await _db.from('chats').update({'unread_for_seller': 0}).eq('id', chatId);
    }
  }

  // =========================
  // SEND TEXT
  // =========================

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final chat = await _db
        .from('chats')
        .select('buyer_id, seller_id, unread_for_buyer, unread_for_seller')
        .eq('id', chatId)
        .maybeSingle();

    if (chat == null) throw Exception('Чат не найден');

    final buyerId = (chat['buyer_id'] ?? '').toString();
    final sellerId = (chat['seller_id'] ?? '').toString();

    await _db.from('chat_messages').insert({
      'id': _uuid.v4(),
      'chat_id': chatId,
      'sender_id': senderId,
      'text': t,
      'image_url': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    int ub = (chat['unread_for_buyer'] as num?)?.toInt() ?? 0;
    int us = (chat['unread_for_seller'] as num?)?.toInt() ?? 0;

    if (senderId == buyerId) {
      us += 1;
    } else if (senderId == sellerId) {
      ub += 1;
    }

    await _db.from('chats').update({
      'last_message': t,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'unread_for_buyer': ub,
      'unread_for_seller': us,
    }).eq('id', chatId);
  }

  // =========================
  // SEND IMAGE
  // =========================

  Future<void> sendImage({
    required String chatId,
    required String senderId,
    required File file,
  }) async {
    final chat = await _db
        .from('chats')
        .select('buyer_id, seller_id, unread_for_buyer, unread_for_seller')
        .eq('id', chatId)
        .maybeSingle();

    if (chat == null) throw Exception('Чат не найден');

    final buyerId = (chat['buyer_id'] ?? '').toString();
    final sellerId = (chat['seller_id'] ?? '').toString();

    const bucket = 'chat_images'; // bucket должен существовать

    final fileId = _uuid.v4();
    final path = '$chatId/$fileId.jpg';

    final bytes = await file.readAsBytes();
    await _db.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        cacheControl: '3600',
        upsert: false,
        contentType: 'image/jpeg',
      ),
    );

    final url = _db.storage.from(bucket).getPublicUrl(path);

    await _db.from('chat_messages').insert({
      'id': _uuid.v4(),
      'chat_id': chatId,
      'sender_id': senderId,
      'text': '',
      'image_url': url,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    int ub = (chat['unread_for_buyer'] as num?)?.toInt() ?? 0;
    int us = (chat['unread_for_seller'] as num?)?.toInt() ?? 0;

    if (senderId == buyerId) {
      us += 1;
    } else if (senderId == sellerId) {
      ub += 1;
    }

    await _db.from('chats').update({
      'last_message': '📷 Фото',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'unread_for_buyer': ub,
      'unread_for_seller': us,
    }).eq('id', chatId);
  }

  // =========================
  // DELETE CHAT
  // =========================

  Future<void> deleteChat({
    required String chatId,
    required String uid,
  }) async {
    final chat = await _db
        .from('chats')
        .select('buyer_id, seller_id')
        .eq('id', chatId)
        .maybeSingle();

    if (chat == null) return;

    final buyerId = (chat['buyer_id'] ?? '').toString();
    final sellerId = (chat['seller_id'] ?? '').toString();

    if (uid != buyerId && uid != sellerId) {
      throw Exception('Нет доступа к удалению чата');
    }

    await _db.from('chat_messages').delete().eq('chat_id', chatId);
    await _db.from('chats').delete().eq('id', chatId);
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    final msg = await _db
        .from('chat_messages')
        .select('id, chat_id, sender_id')
        .eq('id', messageId)
        .maybeSingle();

    if (msg == null) return;
    if ((msg['chat_id'] ?? '').toString() != chatId) return;
    if ((msg['sender_id'] ?? '').toString() != uid) {
      throw Exception('Можно удалить только своё сообщение');
    }

    await _db.from('chat_messages').delete().eq('id', messageId);
  }
}
