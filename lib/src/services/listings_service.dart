// lib/src/services/listings_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ ДОБАВИЛИ

import 'package:chestore2/src/models/car_specs.dart';
import 'package:chestore2/src/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ListingsService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

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

      // только approved
      items = items.where((x) => x.status == 'approved').toList();

      // категория
      if (category != 'Все') {
        items = items.where((x) => x.category == category).toList();
      }

      // поиск
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
  // СОЗДАТЬ -> pending
  // =========================
  Future<void> createListing({
    required String ownerId,
    required String ownerEmail,
    required String ownerName,
    required String title,
    required String description,
    required String category,
    required String subcategory, // ✅ ДОБАВИЛИ
    required int price,
    required String phone,
    required bool phoneHidden,
    required String city,
    required Map<String, bool> delivery,
    required List<File> photos,

    // авто
    CarSpecs? car,

    // новые поля
    String? dealType,
    String? realEstateType,
    String? clothesType,
  }) async {
    final listingId = _uuid.v4();

    // 1) загрузка фото в Supabase Storage (bucket "listings")
    final urls = <String>[];
    
    // ✅ На веб-версии работает по-другому
    if (!kIsWeb) {
      // МОБИЛЬНАЯ версия
      for (var i = 0; i < photos.length; i++) {
        final file = photos[i];
        final ext = file.path.split('.').last;

        // bucket: listings, путь: <listingId>/<index>.<ext>
        final path = '$listingId/$i.$ext';

        final bytes = await file.readAsBytes();

        await _client.storage.from('listings').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );

        final publicUrl = _client.storage.from('listings').getPublicUrl(path);
        urls.add(publicUrl);
      }
    } else {
      // ВЕБ версия - пока пропускаем загрузку фото
      // На производстве нужно использовать Uint8List вместо File
      urls.add('https://via.placeholder.com/400'); // Плейсхолдер
    }

    // 2) создаём запись в таблице listings
    final now = DateTime.now().toUtc();

    final data = <String, dynamic>{
      'id': listingId,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'owner_name': ownerName,
      'title': title,
      'description': description,
      'category': category,
      'subcategory': subcategory, // ✅ ДОБАВИЛИ
      'price': price,
      'phone': phone,
      'phone_hidden': phoneHidden,
      'city': city,
      'delivery': delivery, // jsonb
      'photo_urls': urls, // text[]
      'car': car?.toMap(), // jsonb nullable
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
    await _client.from('listings').delete().eq('id', listing.id);
  }

  // =========================
  // +1 просмотр (простая версия)
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
  // ПОЛУЧИТЬ ОДНО ОБЪЯВЛЕНИЕ (для detail/edit)
  // =========================
  Future<Listing?> getListingById(String id) async {
    final row = await _client.from('listings').select('*').eq('id', id).maybeSingle();
    if (row == null) return null;
    return Listing.fromMap(row);
  }

  // =========================
  // ОБНОВИТЬ ОБЪЯВЛЕНИЕ (снова на модерацию)
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