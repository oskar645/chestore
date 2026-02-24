import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupportService {
  final SupabaseClient _db = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  Future<String?> getOrCreateMyTicketId({required String uid}) async {
    final row = await _db.from('support_tickets').select('id').eq('id', uid).maybeSingle();
    return row == null ? null : uid;
  }

  Future<String> createTicketAndSendFirstMessage({
    required String uid,
    required String name,
    required String text,
  }) async {
    await _db.from('support_tickets').upsert({
      'id': uid,
      'uid': uid,
      'name': name,
      'status': 'open',
      'created_at': DateTime.now().toUtc(),
      'updated_at': DateTime.now().toUtc(),
      'last_message': text,
      'unread_for_admin': true,
    }, onConflict: 'id');

    await _db.from('support_messages').insert({
      'id': _uuid.v4(),
      'ticket_id': uid,
      'sender': 'user',
      'text': text,
      'created_at': DateTime.now().toUtc(),
    });

    return uid;
  }

  Future<void> sendMessage({
    required String ticketId,
    required String text,
  }) async {
    await _db.from('support_messages').insert({
      'id': _uuid.v4(),
      'ticket_id': ticketId,
      'sender': 'user',
      'text': text,
      'created_at': DateTime.now().toUtc(),
    });

    await _db.from('support_tickets').update({
      'updated_at': DateTime.now().toUtc(),
      'last_message': text,
      'unread_for_admin': true,
    }).eq('id', ticketId);
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String ticketId) {
    final stream = _db
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return stream.map((rows) {
      return rows
          .where((r) => r['ticket_id']?.toString() == ticketId)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    });
  }

  // Для админки
  Stream<List<Map<String, dynamic>>> streamTicketsForAdmin() {
    final stream = _db
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false);

    return stream.map((rows) => rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  Future<void> adminReply({
    required String ticketId,
    required String text,
  }) async {
    await _db.from('support_messages').insert({
      'id': _uuid.v4(),
      'ticket_id': ticketId,
      'sender': 'admin',
      'text': text,
      'created_at': DateTime.now().toUtc(),
    });

    await _db.from('support_tickets').update({
      'updated_at': DateTime.now().toUtc(),
      'last_message': text,
      'unread_for_admin': false,
    }).eq('id', ticketId);
  }

  Future<void> markReadByAdmin(String ticketId) async {
    await _db.from('support_tickets').update({
      'unread_for_admin': false,
    }).eq('id', ticketId);
  }
}