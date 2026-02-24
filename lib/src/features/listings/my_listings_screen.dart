import 'package:cached_network_image/cached_network_image.dart';
import 'package:chestore2/src/features/favorites/favorites_screen.dart';
import 'package:chestore2/src/features/listings/add_listing_screen.dart';
import 'package:chestore2/src/features/listings/edit_listing_screen.dart';
import 'package:chestore2/src/features/listings/listing_detail_screen.dart';
import 'package:chestore2/src/models/listing.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/listings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ru', timeago.RuMessages());

    final auth = context.read<AuthService>();
    final svc = context.read<ListingsService>();
    final uid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои объявления'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Избранное',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddListingScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Listing>>(
        stream: svc.streamMyListings(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('У вас пока нет объявлений'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _MyListingTile(listing: items[i]),
          );
        },
      ),
    );
  }
}

class _MyListingTile extends StatelessWidget {
  final Listing listing;
  const _MyListingTile({required this.listing});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ListingsService>();
    final photo = listing.photoUrls.isNotEmpty ? listing.photoUrls.first : null;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listingId: listing.id),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 92,
                height: 92,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: photo == null
                    ? const Icon(Icons.image_not_supported_outlined)
                    : CachedNetworkImage(
                        imageUrl: photo,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${listing.price} ₽',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('Просмотров: ${listing.viewCount}'),
                  const SizedBox(height: 4),
                  Text(
                    'Статус: ${listing.status}',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),

            // ✏️ Редактировать (без фото)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Редактировать',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditListingScreen(listingId: listing.id),
                  ),
                );
              },
            ),

            // 🗑️ Удалить
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Удалить',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить объявление?'),
                    content: const Text('Оно исчезнет из ленты и вашего профиля.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                await svc.deleteListing(listing: listing);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Удалено')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
