import 'package:cached_network_image/cached_network_image.dart';
import 'package:chestore2/src/features/inbox/chat_screen.dart';
import 'package:chestore2/src/features/listings/edit_listing_screen.dart';
import 'package:chestore2/src/features/listings/photo_viewer_screen.dart';
import 'package:chestore2/src/features/reviews/seller_reviews_screen.dart';
import 'package:chestore2/src/models/listing.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/chat_service.dart';
import 'package:chestore2/src/services/favorites_service.dart';
import 'package:chestore2/src/services/listings_service.dart';
import 'package:chestore2/src/utils/price_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart'; // ✅ ДОБАВИЛИ
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  bool _viewCounted = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ru', timeago.RuMessages());
  }

  SupabaseClient get _sb => Supabase.instance.client;

  String _deliveryLabel(String key) {
    switch (key) {
      case 'cdek':
        return 'СДЭК';
      case 'ozon':
        return 'Ozon';
      case 'pek':
        return 'ПЭК';
      case 'pickup':
        return 'Самовывоз';
      default:
        return key;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'На модерации';
      case 'approved':
        return 'Одобрено';
      case 'rejected':
        return 'Отклонено';
      default:
        return status.isEmpty ? 'Одобрено' : status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'approved':
        return Icons.verified;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.info_outline;
    }
  }

  // -----------------------------
  // ADMIN CHECK (Supabase)
  // Таблица: admin_users (uid/id, is_admin)
  // -----------------------------
  Stream<bool> _streamIsAdmin(String uid) {
    // Если у тебя колонка называется не uid, а id — замени тут.
    return _sb
        .from('admin_users')
        .stream(primaryKey: ['uid'])
        .eq('uid', uid)
        .map((rows) {
      if (rows.isEmpty) return false;
      final r = rows.first;
      return (r['is_admin'] == true) || (r['isAdmin'] == true);
    });
  }

  // -----------------------------
  // SELLER PROFILE (Supabase)
  // Таблица: users (id, display_name, name)
  // -----------------------------
  Stream<Map<String, dynamic>> _streamSellerProfile(String sellerId) {
    return _sb
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', sellerId)
        .map((rows) => rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : <String, dynamic>{});
  }

  // -----------------------------
  // REVIEWS (Supabase)
  // Таблица: reviews (seller_id, rating)
  // -----------------------------
  Stream<List<Map<String, dynamic>>> _streamSellerReviews(String sellerId) {
    return _sb
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .map((rows) => rows.map((e) => Map<String, dynamic>.from(e)).toList());
  }

  // -----------------------------
  // LISTING STREAM (Supabase)
  // Таблица: listings (id = listingId)
  // -----------------------------
  Stream<Map<String, dynamic>?> _streamListingRow(String listingId) {
    return _sb
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('id', listingId)
        .map((rows) => rows.isEmpty ? null : Map<String, dynamic>.from(rows.first));
  }

  Future<void> _openReportDialog({
    required String listingId,
    required String listingOwnerId,
  }) async {
    final me = context.read<AuthService>().currentUser!;

    final reasons = <String>[
      'Запрещённый товар',
      'Мошенничество',
      'Спам / реклама',
      'Оскорбления',
      'Фейк / обман',
      'Другое',
    ];

    String reason = reasons.first;
    final c = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пожаловаться'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: reason,
              items: reasons.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => reason = v ?? reason,
              decoration: const InputDecoration(labelText: 'Причина'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Комментарий (не обязательно)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // Таблица reports: listing_id, listing_owner_id, reporter_id, reason, comment, status, created_at
      await _sb.from('reports').insert({
        'listing_id': listingId,
        'listing_owner_id': listingOwnerId,
        'reporter_id': me.uid,
        'reason': reason,
        'comment': c.text.trim(),
        'status': 'open',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  // ✅ ПОДЕЛИТЬСЯ ОБЪЯВЛЕНИЕМ
  Future<void> _shareAnnouncement(String listingId, String title) async {
    // Ссылка на объявление (для deep linking)
    // Можешь использовать твой домен или Firebase Dynamic Links
    final shareLink = 'https://chestore.app/listing/$listingId';
    
    final message = '''🛍️ *$title*

Посмотри это объявление в CheStore!

$shareLink

#CheStore''';

    try {
      await Share.share(
        message,
        subject: title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthService>().currentUser!;
    final favs = context.read<FavoritesService>();
    final chats = context.read<ChatService>();
    final listingsSvc = context.read<ListingsService>();

    return StreamBuilder<bool>(
      stream: _streamIsAdmin(me.uid),
      builder: (context, adminSnap) {
        final isAdmin = adminSnap.data == true;

        return StreamBuilder<Map<String, dynamic>?>(
          stream: _streamListingRow(widget.listingId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final row = snap.data;
            if (row == null) {
              return Scaffold(appBar: AppBar(), body: const Center(child: Text('Объявление удалено')));
            }

            // ⚠️ Тут важно: Listing должен уметь создаваться из Map.
            // Если у тебя Listing пока только fromDoc — добавь factory Listing.fromMap(map) в модель.
            final listing = Listing.fromMap(row);

            final status = (row['status'] ?? 'approved').toString();
            final rejectionReason = (row['rejection_reason'] ?? row['rejectionReason'] ?? '').toString().trim();

            final isOwner = listing.ownerId == me.uid;
            final canSee = (status == 'approved') || isOwner || isAdmin;
            if (!canSee) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Объявление на модерации или недоступно')),
              );
            }

            final canContact = (status == 'approved') || isOwner || isAdmin;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_viewCounted) return;
              if (status != 'approved') return;
              if (listing.ownerId == me.uid) return;
              _viewCounted = true;
              listingsSvc.incrementView(listing.id);
            });

            final deliveryNames = listing.delivery.entries
                .where((e) => e.value == true)
                .map((e) => _deliveryLabel(e.key))
                .toList();

            return StreamBuilder<Set<String>>(
              stream: favs.streamFavoriteIds(me.uid),
              builder: (context, favSnap) {
                final isFav = (favSnap.data ?? <String>{}).contains(listing.id);

                return StreamBuilder<Map<String, dynamic>>(
                  stream: _streamSellerProfile(listing.ownerId),
                  builder: (context, sellerSnap) {
                    final u = sellerSnap.data ?? const <String, dynamic>{};
                    final dn = (u['display_name'] ?? u['displayName'] ?? u['name'] ?? '').toString().trim();
                    final sellerName = dn.isNotEmpty ? dn : listing.ownerEmail;

                    final myName = (me.displayName?.trim().isNotEmpty ?? false)
                        ? me.displayName!.trim()
                        : (me.email ?? 'Пользователь');

                    return Scaffold(
                      appBar: AppBar(
                        centerTitle: false,
                        title: Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        actions: [
                          IconButton(
                            onPressed: () => favs.toggleFavorite(
                              uid: me.uid,
                              listingId: listing.id,
                              makeFavorite: !isFav,
                            ),
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => EditListingScreen(listingId: listing.id)),
                                );
                              } else if (v == 'report') {
                                await _openReportDialog(
                                  listingId: listing.id,
                                  listingOwnerId: listing.ownerId,
                                );
                              } else if (v == 'share') {
                                // ✅ ПОДЕЛИТЬСЯ
                                await _shareAnnouncement(listing.id, listing.title);
                              }
                            },
                            itemBuilder: (ctx) => [
                              // ✅ ПОДЕЛИТЬСЯ (видно всем)
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Поделиться'),
                                  ],
                                ),
                              ),
                              if (isOwner)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Редактировать'),
                                    ],
                                  ),
                                ),
                              if (!isOwner)
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Пожаловаться'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (status != 'approved')
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: _statusColor(context, status).withOpacity(0.12),
                                border: Border.all(color: _statusColor(context, status).withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_statusIcon(status), color: _statusColor(context, status)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_statusTitle(status)}${status == 'pending' ? ' — проверяем объявление' : ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (status == 'rejected' && rejectionReason.isNotEmpty && (isOwner || isAdmin)) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.red.withOpacity(0.08),
                                border: Border.all(color: Colors.red.withOpacity(0.25)),
                              ),
                              child: Text(
                                'Причина отклонения: $rejectionReason',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          _Photos(photoUrls: listing.photoUrls),
                          const SizedBox(height: 12),

                          Text(
                            '${formatPrice(listing.price)} ₽',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          ),

                          const SizedBox(height: 8),

                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _streamSellerReviews(listing.ownerId),
                            builder: (context, rSnap) {
                              final rows = rSnap.data ?? const <Map<String, dynamic>>[];
                              double sum = 0;
                              int cnt = 0;

                              for (final x in rows) {
                                final r = x['rating'];
                                if (r is num) {
                                  sum += r.toDouble();
                                  cnt++;
                                }
                              }

                              final avg = (cnt == 0) ? 0.0 : (sum / cnt);

                              return Row(
                                children: [
                                  const Icon(Icons.star, size: 18, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 6),
                                  Text('($cnt)', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.rate_review_outlined, color: Theme.of(context).colorScheme.primary),
                            title: const Text('Отзывы о продавце'),
                            subtitle: const Text('Посмотреть и оставить отзыв'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SellerReviewsScreen(
                                    sellerId: listing.ownerId,
                                    sellerName: sellerName,
                                    listingId: listing.id,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 6),

                          Text(
                            '${listing.city.trim().isEmpty ? 'Город не указан' : listing.city} • '
                            '${timeago.format(listing.createdAt, locale: 'ru')}',
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          ),

                          const SizedBox(height: 8),
                          Text('Просмотров: ${listing.viewCount}'),

                          const SizedBox(height: 10),

                          if (deliveryNames.isNotEmpty)
                            Text('Доставка: ${deliveryNames.join(', ')}')
                          else
                            Text('Доставка: не указано', style: TextStyle(color: Theme.of(context).colorScheme.outline)),

                          const Divider(height: 28),
                          Text(listing.description),

                          // авто параметры
                          if (listing.car != null) ...[
                            const Divider(height: 28),
                            const Text('Параметры авто', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            _kv('Марка', listing.car!.brand),
                            _kv('Модель', listing.car!.model),
                            if (listing.car!.generation.trim().isNotEmpty) _kv('Поколение', listing.car!.generation),
                            _kv('Год', '${listing.car!.year}'),
                            _kv('Пробег', '${listing.car!.mileageKm} км'),
                            _kv('Кузов', listing.car!.bodyType),
                            _kv('Топливо', listing.car!.fuel),
                            _kv('Двигатель', '${listing.car!.engineVolume.toStringAsFixed(1)} л'),
                            _kv('Мощность', '${listing.car!.powerHp} л.с.'),
                            _kv('Коробка', listing.car!.transmission),
                            _kv('Привод', listing.car!.drive),
                            _kv('Состояние', listing.car!.condition),
                            _kv('Цвет', listing.car!.color),
                            if (listing.car!.owners != null) _kv('Владельцев', '${listing.car!.owners}'),
                            if (listing.car!.isCleared != null) _kv('Растаможен', listing.car!.isCleared! ? 'Да' : 'Нет'),
                            if ((listing.car!.vin ?? '').trim().isNotEmpty) _kv('VIN', listing.car!.vin!.trim()),
                            if ((listing.car!.note ?? '').trim().isNotEmpty) _kv('Примечание', listing.car!.note!.trim()),
                          ],

                          const Divider(height: 28),

                          Text('Продавец: $sellerName'),
                          const SizedBox(height: 8),

                          Text(listing.phoneHidden ? 'Телефон: скрыт' : 'Телефон: ${listing.phone}'),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: (!canContact || listing.phone.trim().isEmpty)
                                      ? null
                                      : () async {
                                          final uri = Uri(scheme: 'tel', path: listing.phone);
                                          await launchUrl(uri);
                                        },
                                  icon: const Icon(Icons.call),
                                  label: Text(status == 'approved' ? 'Позвонить' : 'Недоступно'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: (!canContact || listing.ownerId == me.uid)
                                      ? null
                                      : () async {
                                          final chatId = await chats.getOrCreateChat(
                                            listingId: listing.id,
                                            listingTitle: listing.title,
                                            buyerId: me.uid,
                                            buyerEmail: myName,
                                            sellerId: listing.ownerId,
                                            sellerEmail: sellerName,
                                          );

                                          if (!context.mounted) return;

                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)),
                                          );
                                        },
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: Text(status == 'approved' ? 'Написать' : 'Недоступно'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          if (listing.ownerId == me.uid)
                            Text(
                              status == 'approved'
                                  ? 'Это ваше объявление. Сообщения доступны покупателям.'
                                  : 'Это ваше объявление. Сейчас оно: ${_statusTitle(status)}.',
                              style: TextStyle(color: Theme.of(context).colorScheme.outline),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

class _Photos extends StatelessWidget {
  final List<String> photoUrls;
  const _Photos({required this.photoUrls});

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: PageView.builder(
          itemCount: photoUrls.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PhotoViewerScreen(photoUrls: photoUrls, initialIndex: i),
                ),
              );
            },
            child: CachedNetworkImage(
              imageUrl: photoUrls[i],
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (_, __) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, size: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}