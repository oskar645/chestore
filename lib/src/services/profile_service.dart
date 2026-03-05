import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
final SupabaseClient _db = Supabase.instance.client;

Stream<Map<String, dynamic>> streamProfile(String uid) {
return _db
.from('users')
.stream(primaryKey: ['id'])
.eq('id', uid)
.map((rows) => rows.isNotEmpty
? Map<String, dynamic>.from(rows.first)
: <String, dynamic>{});
}

Future<Map<String, dynamic>> getProfile(String uid) async {
final row = await _db.from('users').select().eq('id', uid).maybeSingle();
return row ?? <String, dynamic>{};
}

Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
await _db.from('users').upsert({'id': uid, ...data}, onConflict: 'id');
}

// вњ… РРјСЏ РґР»СЏ UI
String pickNameFromRow(
Map<String, dynamic> row, {
String fallback = 'Пользователь',
}) {
final dn = (row['display_name'] ?? row['displayName'] ?? '').toString().trim();
final name = (row['name'] ?? '').toString().trim();
final email = (row['email'] ?? '').toString().trim();
return dn.isNotEmpty ? dn : (name.isNotEmpty ? name : (email.isNotEmpty ? email : fallback));
}

// вњ… РђРІР°С‚Р°СЂ РёР· users
String pickAvatarFromRow(Map<String, dynamic> row) {
final a1 = (row['avatar_url'] ?? '').toString().trim();
if (a1.isNotEmpty) return a1;
final a2 = (row['photo_url'] ?? '').toString().trim();
if (a2.isNotEmpty) return a2;
return '';
}

// ===============================
// вњ… UNIVERSAL AVATAR UPLOAD (Web + Android + iOS)
// ===============================
Future<String> uploadAvatar({
required String uid,
required Uint8List bytes,
String contentType = 'image/jpeg',
}) async {
const bucket = 'avatars'; // Сѓ С‚РµР±СЏ СѓР¶Рµ public bucket
final ext = contentType.contains('png') ? 'png' : 'jpg';
final path = '$uid/avatar.$ext';

await _db.storage.from(bucket).uploadBinary(
path,
bytes,
fileOptions: FileOptions(
cacheControl: '3600',
upsert: true,
contentType: contentType,
),
);

// Р•СЃР»Рё bucket PUBLIC вЂ” Р±СѓРґРµС‚ СЂР°Р±РѕС‚Р°С‚СЊ СЃСЂР°Р·Сѓ
final url = _db.storage.from(bucket).getPublicUrl(path);

// вњ… СЃРѕС…СЂР°РЅСЏРµРј РІ С‚Р°Р±Р»РёС†Сѓ users, С‡С‚РѕР±С‹ РІРµР·РґРµ РїРѕРєР°Р·С‹РІР°Р»РѕСЃСЊ
await updateProfile(uid, {
'avatar_url': url,
'photo_url': url,
});

return url;
}

// ===== С‚РІРѕРё СЃС‚СЂРёРјС‹ СЃС‚Р°С‚РёСЃС‚РёРєРё =====

Stream<int> streamMyListingsCount(String uid) {
final stream = _db.from('listings').stream(primaryKey: ['id']);
return stream.map((rows) => rows.where((r) => r['owner_id']?.toString() == uid).length);
}

Stream<double> streamMyRatingAvg(String uid) {
final stream = _db.from('reviews').stream(primaryKey: ['id']);
return stream.map((rows) {
final my = rows.where((r) => r['seller_id']?.toString() == uid).toList();
if (my.isEmpty) return 0.0;
final sum = my.fold<num>(0, (p, r) => p + ((r['rating'] as num?) ?? 0));
return (sum / my.length).toDouble();
});
}

Stream<int> streamMyReviewsCount(String uid) {
final stream = _db.from('reviews').stream(primaryKey: ['id']);
return stream.map((rows) => rows.where((r) => r['seller_id']?.toString() == uid).length);
}

Stream<String> streamDisplayName(
String uid, {
String fallback = 'Пользователь',
}) {
return streamProfile(uid).map((row) => pickNameFromRow(row, fallback: fallback));
}

Future<String> getDisplayName(
String uid, {
String fallback = 'Пользователь',
}) async {
final row = await getProfile(uid);
return pickNameFromRow(row, fallback: fallback);
}
}
