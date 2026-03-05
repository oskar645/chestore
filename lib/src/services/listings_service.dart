// lib/src/services/listings_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:chestore2/src/models/car_specs.dart';
import 'package:chestore2/src/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ListingsService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  // ✅ ВАЖНО: грузим в PUBLIC bucket
  static const String _bucket = 'listing-photos';

  // =========================
  // ЛЕНТА: только approved
  // =========================
  Stream<List<Listing>> streamListings({
    required String category,
    required String search,
  }) {
    final stream = _client
        .from('listings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return stream.map((rows) {
      var items = rows.map((r) => Listing.fromMap(r)).toList();

      items = items.where((x) => x.status == 'approved').toList();

      if (category != 'Все') {
        items = items.where((x) => x.category == category).toList();
      }

      final s = search.trim().toLowerCase();
      if (s.isNotEmpty) {
        items = items.where((x) => x.title.toLowerCase().contains(s)).toList();
      }

      return items;
    });
  }

  // =========================
  // МОИ: все статусы
  // =========================
  Stream<List<Listing>> streamMyListings(String uid) {
    final stream = _client
        .from('listings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return stream.map((rows) {
      final items = rows.map((r) => Listing.fromMap(r)).toList();
      return items.where((x) => x.ownerId == uid).toList();
    });
  }

  Stream<int> streamMyListingsCount(String uid) {
    return streamMyListings(uid).map((items) => items.length);
  }

  // =========================
  // ✅ НОВОЕ: ОБЪЯВЛЕНИЯ ПРОДАВЦА (для профиля как Avito)
  // =========================
  Stream<List<Listing>> streamListingsByOwner(String ownerId) {
    return streamListingsByOwnerAll(ownerId).map(
      (items) => items.where((x) => x.status == 'approved').toList(),
    );
  }

  Stream<List<Listing>> streamListingsByOwnerAll(String ownerId) {
    final stream = _client
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return stream.map((rows) => rows.map((r) => Listing.fromMap(r)).toList());
  }

  Stream<List<Listing>> streamMyListingsByStatuses(
    String uid, {
    required Set<String> statuses,
  }) {
    return streamMyListings(uid).map(
      (items) => items.where((x) => statuses.contains(x.status)).toList(),
    );
  }

  // =========================
  // ✅ НОВОЕ: для кнопки "Написать" в профиле продавца
  // Берём любое последнее approved объявление продавца
  // (чтобы создать чат через listing_id + title)
  // =========================
  Future<Listing?> getLatestApprovedListingByOwner(String ownerId) async {
    final row = await _client
        .from('listings')
        .select('*')
        .eq('owner_id', ownerId)
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return Listing.fromMap(row);
  }

  // =========================
  // СОЗДАТЬ -> pending
  // =========================
  Future<void> createListing({
    required String ownerId,
    required String ownerEmail,
    required String ownerName,
    required String title,
    required String description,
    required String category,
    required String subcategory,
    required int price,
    required String phone,
    required bool phoneHidden,
    required String city,
    required Map<String, bool> delivery,
    required List<File> photos,
    CarSpecs? car,
    String? dealType,
    String? realEstateType,
    String? clothesType,
  }) async {
    final listingId = _uuid.v4();

    final urls = <String>[];

    if (!kIsWeb) {
      for (var i = 0; i < photos.length; i++) {
        try {
          final file = photos[i];
          final ext = file.path.split('.').last.toLowerCase();

          // ✅ ограничим расширения (иначе бывает странный content-type)
          final safeExt =
              (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp')
                  ? ext
                  : 'jpg';

          final path = '$listingId/$i.$safeExt';
          final bytes = await file.readAsBytes();

          final contentType = switch (safeExt) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };

          await _client.storage.from(_bucket).uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(
                  cacheControl: '3600',
                  upsert: false,
                  contentType: contentType,
                ),
              );

          final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);

          debugPrint('PHOTO URL [$i]: $publicUrl');
          urls.add(publicUrl);
        } catch (e) {
          debugPrint('Ошибка загрузки фото $i: $e');
        }
      }
    } else {
      // WEB (пока заглушка)
      urls.add('https://via.placeholder.com/400');
    }

    final now = DateTime.now().toUtc();

    final data = <String, dynamic>{
      'id': listingId,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'owner_name': ownerName,
      'title': title,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'price': price,
      'phone': phone,
      'phone_hidden': phoneHidden,
      'city': city,
      'delivery': delivery,
      'photo_urls': urls,
      'car': car?.toMap(),
      'deal_type': dealType,
      'real_estate_type': realEstateType,
      'clothes_type': clothesType,
      'view_count': 0,
      'status': 'pending',
      'rejection_reason': null,
      'created_at': now.toIso8601String(),
      'updated_at': null,
    };

    await _client.from('listings').insert(data);
  }

  // =========================
  // УДАЛИТЬ
  // =========================
  Future<void> deleteListing({required Listing listing}) async {
    await _client
        .from('listings')
        .update({'status': 'deleted', 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', listing.id);
  }

  // =========================
  // +1 просмотр
  // =========================
  Future<void> incrementView(String listingId) async {
    final row = await _client
        .from('listings')
        .select('view_count')
        .eq('id', listingId)
        .maybeSingle();

    int current = 0;
    if (row != null && row['view_count'] is num) {
      current = (row['view_count'] as num).toInt();
    }

    await _client
        .from('listings')
        .update({'view_count': current + 1})
        .eq('id', listingId);
  }

  // =========================
  // ПОЛУЧИТЬ ОДНО
  // =========================
  Future<Listing?> getListingById(String id) async {
    final row = await _client.from('listings').select('*').eq('id', id).maybeSingle();
    if (row == null) return null;
    return Listing.fromMap(row);
  }

  // =========================
  // ОБНОВИТЬ (без фото)
  // =========================
  Future<void> updateListing({
    required String listingId,
    required String title,
    required String description,
    required int price,
    required String phone,
    required bool phoneHidden,
    required String city,
    required Map<String, bool> delivery,
    CarSpecs? car,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'price': price,
      'phone': phone,
      'phone_hidden': phoneHidden,
      'city': city,
      'delivery': delivery,
      'car': car?.toMap(),
      'status': 'pending',
      'rejection_reason': null,
      'updated_at': now,
    };

    await _client.from('listings').update(data).eq('id', listingId);
  }
}
