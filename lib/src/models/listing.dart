// lib/src/models/listing.dart
import 'car_specs.dart';

class Listing {
  final String id;

  final String ownerId;
  final String ownerEmail;
  final String ownerName;

  final String title;
  final String description;
  final String category;
  final String subcategory; // ✅ ДОБАВИЛИ
  final int price;

  final String phone;
  final bool phoneHidden;

  final String city;

  final Map<String, dynamic> delivery; // jsonb
  final List<String> photoUrls; // text[]

  final CarSpecs? car; // ✅ удобно как модель (nullable)

  final String? dealType;
  final String? realEstateType;
  final String? clothesType;

  final int viewCount;
  final String status;
  final String rejectionReason;

  final DateTime createdAt;
  final DateTime? updatedAt;

  Listing({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.category,
    required this.subcategory, // ✅ ДОБАВИЛИ
    required this.price,
    required this.phone,
    required this.phoneHidden,
    required this.city,
    required this.delivery,
    required this.photoUrls,
    required this.car,
    required this.dealType,
    required this.realEstateType,
    required this.clothesType,
    required this.viewCount,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _parseDt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static List<String> _parseTextArray(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) return v.map((e) => e.toString()).toList();
    return <String>[];
  }

  static Map<String, dynamic> _parseJson(dynamic v) {
    if (v == null) return <String, dynamic>{};
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  /// ✅ Supabase row -> Listing
  factory Listing.fromMap(Map<String, dynamic> row) {
    final delivery = _parseJson(row['delivery']);
    final photos = _parseTextArray(row['photo_urls']);
    final carRaw = row['car'];

    return Listing(
      id: row['id'].toString(),
      ownerId: (row['owner_id'] ?? '').toString(),
      ownerEmail: (row['owner_email'] ?? '').toString(),
      ownerName: (row['owner_name'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      subcategory: (row['subcategory'] ?? '').toString(), // ✅ ДОБАВИЛИ
      price: (row['price'] is num) ? (row['price'] as num).toInt() : 0,
      phone: (row['phone'] ?? '').toString(),
      phoneHidden: row['phone_hidden'] == true,
      city: (row['city'] ?? '').toString(),
      delivery: delivery,
      photoUrls: photos,
      car: CarSpecs.fromAny(carRaw),
      dealType: row['deal_type']?.toString(),
      realEstateType: row['real_estate_type']?.toString(),
      clothesType: row['clothes_type']?.toString(),
      viewCount: (row['view_count'] is num) ? (row['view_count'] as num).toInt() : 0,
      status: (row['status'] ?? 'approved').toString(),
      rejectionReason: (row['rejection_reason'] ?? '').toString(),
      createdAt: _parseDt(row['created_at']),
      updatedAt: row['updated_at'] == null ? null : _parseDt(row['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'delivery': delivery,
      'photo_urls': photoUrls,
      'car': car?.toMap(),
      'deal_type': dealType,
      'real_estate_type': realEstateType,
      'clothes_type': clothesType,
      'view_count': viewCount,
      'status': status,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}