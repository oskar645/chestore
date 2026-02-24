import 'dart:io';

import 'package:chestore2/src/models/chat.dart';
import 'package:chestore2/src/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final SupabaseClient _db = Supabase.instance.client;
  final _uuid = const Uuid();

  // =========================
  // HELPERS
  // =========================

  List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return <String>[];
  }

  Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  // =========================
  // STREAMS
  // =========================

  /// В твоей версии stream-builder не умеет server-side eq/match, поэтому фильтруем на клиенте
  Stream<List<Chat>> streamMyChats(String uid) {
    final stream = _db
        .from('chats')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false);

    return stream.map((rows) {
      final items = <Chat>[];

      for (final r in rows) {
        final memberIds = _toStringList(r['member_ids']);
        if (!memberIds.contains(uid)) continue;

        // ⚠️ Chat.fromDoc был под Firestore.
        // Поэтому делаем совместимый Map и используем fromMap (если есть),
        // иначе создаём через Chat.fromJson/constructor — зависит от твоей модели.
        //
        // Если у тебя есть Chat.fromMap(Map), используй его.
        // Ниже предполагаю, что есть Chat.fromMap / Chat.fromJson.
        items.add(Chat.fromMap(_chatRowToCompatMap(r)));
      }

      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  Stream<int> streamUnreadTotal(String uid) {
    final stream = _db.from('chats').stream(primaryKey: ['id']);

    return stream.map((rows) {
      int total = 0;
      for (final r in rows) {
        final memberIds = _toStringList(r['member_ids']);
        if (!memberIds.contains(uid)) continue;

        final unread = _toMap(r['unread']);
        final v = unread[uid];
        if (v is num) total += v.toInt();
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
      final items = <ChatMessage>[];
      for (final r in rows) {
        if (r['chat_id']?.toString() != chatId) continue;
        items.add(ChatMessage.fromMap(_msgRowToCompatMap(r)));
      }
      return items;
    });
  }

  // =========================
  // CREATE / GET CHAT
  // =========================

  Future<String> getOrCreateChat({
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String buyerEmail,
    required String sellerId,
    required String sellerEmail,
  }) async {
    final chatId = '${listingId}_$buyerId';

    final existing = await _db.from('chats').select('id').eq('id', chatId).maybeSingle();
    if (existing != null) return chatId;

    await _db.from('chats').insert({
      'id': chatId,
      'listing_id': listingId,
      'listing_title': listingTitle,
      'member_ids': [buyerId, sellerId], // text[]
      'member_emails': {
        buyerId: buyerEmail,
        sellerId: sellerEmail,
      }, // jsonb
      'last_message': '',
      'updated_at': DateTime.now().toUtc(),
      'unread': {
        buyerId: 0,
        sellerId: 0,
      }, // jsonb
    });

    return chatId;
  }

  // =========================
  // READ
  // =========================

  Future<void> markChatRead({
    required String chatId,
    required String uid,
  }) async {
    // unread — jsonb, перезапишем ключ uid в 0
    final row = await _db.from('chats').select('unread').eq('id', chatId).maybeSingle();
    final unread = _toMap(row?['unread']);
    unread[uid] = 0;

    await _db.from('chats').update({'unread': unread}).eq('id', chatId);
  }

  // =========================
  // SEND TEXT
  // =========================

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final chat = await _db.from('chats').select('*').eq('id', chatId).maybeSingle();
    if (chat == null) throw Exception('Чат не найден');

    final memberIds = _toStringList(chat['member_ids']);
    final otherId = memberIds.firstWhere((x) => x != senderId, orElse: () => '');

    // 1) вставляем сообщение
    await _db.from('chat_messages').insert({
      'id': _uuid.v4(),
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'image_url': null,
      'created_at': DateTime.now().toUtc(),
    });

    // 2) обновляем чат
    final unread = _toMap(chat['unread']);
    if (otherId.isNotEmpty) {
      final cur = unread[otherId];
      unread[otherId] = (cur is num ? cur.toInt() : 0) + 1;
    }

    await _db.from('chats').update({
      'last_message': text,
      'updated_at': DateTime.now().toUtc(),
      'unread': unread,
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
    final chat = await _db.from('chats').select('*').eq('id', chatId).maybeSingle();
    if (chat == null) throw Exception('Чат не найден');

    final memberIds = _toStringList(chat['member_ids']);
    final otherId = memberIds.firstWhere((x) => x != senderId, orElse: () => '');

    // upload image -> Supabase Storage
    final fileId = _uuid.v4();
    final path = '$chatId/$fileId.jpg';

    final bytes = await file.readAsBytes();
    await _db.storage.from('chat_images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final url = _db.storage.from('chat_images').getPublicUrl(path);

    await _db.from('chat_messages').insert({
      'id': _uuid.v4(),
      'chat_id': chatId,
      'sender_id': senderId,
      'text': '',
      'image_url': url,
      'created_at': DateTime.now().toUtc(),
    });

    final unread = _toMap(chat['unread']);
    if (otherId.isNotEmpty) {
      final cur = unread[otherId];
      unread[otherId] = (cur is num ? cur.toInt() : 0) + 1;
    }

    await _db.from('chats').update({
      'last_message': '📷 Фото',
      'updated_at': DateTime.now().toUtc(),
      'unread': unread,
    }).eq('id', chatId);
  }

  // =========================
  // DELETE CHAT + MESSAGES
  // =========================

  Future<void> deleteChat({
    required String chatId,
    required String uid,
  }) async {
    final chat = await _db.from('chats').select('*').eq('id', chatId).maybeSingle();
    if (chat == null) return;

    final memberIds = _toStringList(chat['member_ids']);
    if (!memberIds.contains(uid)) throw Exception('Нет доступа к удалению чата');

    // удаляем сообщения
    await _db.from('chat_messages').delete().eq('chat_id', chatId);

    // удаляем чат
    await _db.from('chats').delete().eq('id', chatId);

    // storage очистку можно добавить позже (list/remove)
  }

  // =========================
  // COMPAT MAPS FOR MODELS
  // =========================

  Map<String, dynamic> _chatRowToCompatMap(Map<String, dynamic> r) {
    return {
      'id': r['id'],
      'listingId': r['listing_id'],
      'listingTitle': r['listing_title'],
      'memberIds': r['member_ids'],
      'memberEmails': r['member_emails'],
      'lastMessage': r['last_message'],
      'updatedAt': r['updated_at'],
      'unread': r['unread'],
    };
  }

  Map<String, dynamic> _msgRowToCompatMap(Map<String, dynamic> r) {
    return {
      'id': r['id'],
      'senderId': r['sender_id'],
      'text': r['text'],
      'imageUrl': r['image_url'],
      'createdAt': r['created_at'],
    };
  }
}