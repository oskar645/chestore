import 'package:cached_network_image/cached_network_image.dart';
import 'package:chestore2/src/constants/categories.dart';
import 'package:chestore2/src/features/listings/add_listing_screen.dart';
import 'package:chestore2/src/features/listings/listing_detail_screen.dart';
import 'package:chestore2/src/models/listing.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/favorites_service.dart';
import 'package:chestore2/src/services/listings_service.dart';
import 'package:chestore2/src/services/reviews_service.dart';
import 'package:chestore2/src/utils/price_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'Все';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectCategory(String c) {
    setState(() {
      _category = c;
      _search = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final listings = context.read<ListingsService>();
    final favs = context.read<FavoritesService>();
    final user = context.read<AuthService>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('CheStore'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddListingScreen()),
            ),
            icon: Icon(
              Icons.add_circle,
              color: Colors.blue,
              size: 28, // ✅ Побольше
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryRow(selected: _category, onSelect: _selectCategory),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по названию',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: favs.streamFavoriteIds(user.uid),
              builder: (context, favSnap) {
                final favIds = favSnap.data ?? <String>{};

                return StreamBuilder<List<Listing>>(
                  stream: listings.streamListings(
                    category: _category,
                    search: _search,
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snap.data!;
                    if (items.isEmpty) {
                      return const Center(child: Text('Пока нет объявлений'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return _ListingGridCard(
                          listing: item,
                          isFav: favIds.contains(item.id),
                          onToggleFav: (makeFav) => favs.toggleFavorite(
                            uid: user.uid,
                            listingId: item.id,
                            makeFavorite: makeFav,
                          ),
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ListingDetailScreen(listingId: item.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = kCategories[i];
          final isSel = c == selected;
          return ChoiceChip(
            label: Text(c),
            selected: isSel,
            onSelected: (_) => onSelect(c),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _ListingGridCard extends StatelessWidget {
  final Listing listing;
  final bool isFav;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggleFav;

  const _ListingGridCard({
    required this.listing,
    required this.isFav,
    required this.onOpen,
    required this.onToggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final photo = listing.photoUrls.isNotEmpty ? listing.photoUrls.first : null;

    final reviews = context.read<ReviewsService>();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: photo == null
                      ? const Center(
                          child: Icon(Icons.image_not_supported_outlined, size: 34),
                        )
                      : CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 34),
                          ),
                        ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.05),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                            onPressed: () => onToggleFav(!isFav),
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Theme.of(context).colorScheme.outline,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // ✅ подкатегория
                    if (listing.subcategory.isNotEmpty)
                      Text(
                        listing.subcategory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),

                    if (listing.subcategory.isNotEmpty) const SizedBox(height: 3),

                    Text(
                      '${formatPrice(listing.price)} ₽',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 4),

                    // ✅ рейтинг продавца из Supabase reviews
                    StreamBuilder<Map<String, dynamic>>(
                      stream: reviews.streamSellerRating(listing.ownerId),
                      builder: (context, rSnap) {
                        final avg = (rSnap.data?['avg'] as num?)?.toDouble() ?? 0.0;
                        final cnt = (rSnap.data?['count'] as num?)?.toInt() ?? 0;

                        return Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '($cnt)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    Text(
                      listing.city.trim().isEmpty ? 'Город не указан' : listing.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}