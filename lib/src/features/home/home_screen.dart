import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:chestore2/src/constants/categories.dart';
import 'package:chestore2/src/data/auto_catalog.dart';
import 'package:chestore2/src/features/listings/add_listing_screen.dart';
import 'package:chestore2/src/features/listings/listing_detail_screen.dart';
import 'package:chestore2/src/features/notifications/notifications_screen.dart';
import 'package:chestore2/src/models/listing.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/favorites_service.dart';
import 'package:chestore2/src/services/listings_service.dart';
import 'package:chestore2/src/services/notifications_service.dart';
import 'package:chestore2/src/services/reviews_service.dart';
import 'package:chestore2/src/widgets/listing_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'Все';
  String _search = '';
  final _searchCtrl = TextEditingController();

  // ✅ Avito-like location
  String _location = ''; // "Москва", "Чеченская Республика" и т.д.
  bool _preferLocationFirst = false; // "Сначала из ..."
  int? _radiusKm; // 1/2/3/5/10 или null
  String _autoBrand = '';
  String _autoModel = '';
  String _autoCondition = '';
  int? _autoMileageTo;
  bool _onlyUncrashed = false;

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

  Future<void> _openFilters() async {
    final res = await Navigator.of(context).push<_HomeFilters>(
      MaterialPageRoute(
        builder: (_) => _FiltersScreen(
          initialCategory: _category,
          initialLocation: _location,
          initialPreferFirst: _preferLocationFirst,
          initialRadiusKm: _radiusKm,
          initialAutoBrand: _autoBrand,
          initialAutoModel: _autoModel,
          initialAutoCondition: _autoCondition,
          initialAutoMileageTo: _autoMileageTo,
          initialOnlyUncrashed: _onlyUncrashed,
        ),
      ),
    );

    if (!mounted || res == null) return;

    setState(() {
      _category = res.category;
      _location = res.location;
      _preferLocationFirst = res.preferFirst;
      _radiusKm = res.radiusKm;
      _autoBrand = res.autoBrand;
      _autoModel = res.autoModel;
      _autoCondition = res.autoCondition;
      _autoMileageTo = res.autoMileageTo;
      _onlyUncrashed = res.onlyUncrashed;
    });
  }

  List<Listing> _applyLocationPriority(List<Listing> items) {
    if (!_preferLocationFirst) return items;

    final q = _location.trim().toLowerCase();
    if (q.isEmpty) return items;

    // ✅ как ты просил: сперва “в моём городе/регионе”, потом остальные
    final first = <Listing>[];
    final rest = <Listing>[];

    for (final x in items) {
      final city = x.city.trim().toLowerCase();
      if (city.isNotEmpty && (city == q || city.contains(q) || q.contains(city))) {
        first.add(x);
      } else {
        rest.add(x);
      }
    }

    return [...first, ...rest];
  }

  bool _isAutoCategory(String category) {
    final c = category.trim().toLowerCase();
    return c == 'авто' || c.contains('авто') || c.contains('рђрвс');
  }

  bool _looksUncrashed(Listing x) {
    final carCond = (x.car?.condition ?? '').toLowerCase();
    final text = '${x.title} ${x.description}'.toLowerCase();
    final source = '$carCond $text';

    final positive = source.contains('не бит') ||
        source.contains('без дтп') ||
        source.contains('не крашен') ||
        source.contains('родной окрас');
    final negative = source.contains('бит') ||
        source.contains('дтп') ||
        source.contains('крашен') ||
        source.contains('после авар');
    return positive && !negative;
  }

  List<Listing> _applyAdvancedFilters(List<Listing> items) {
    Iterable<Listing> out = items;

    final hasAutoFilters = _autoBrand.isNotEmpty ||
        _autoModel.isNotEmpty ||
        _autoCondition.isNotEmpty ||
        _autoMileageTo != null ||
        _onlyUncrashed;

    if (hasAutoFilters && _isAutoCategory(_category)) {
      out = out.where((x) {
        if (!_isAutoCategory(x.category)) return false;
        final car = x.car;
        if (car == null) return false;

        if (_autoBrand.isNotEmpty && car.brand != _autoBrand) return false;
        if (_autoModel.isNotEmpty && car.model != _autoModel) return false;
        if (_autoCondition.isNotEmpty && car.condition != _autoCondition) return false;
        if (_autoMileageTo != null && car.mileageKm > _autoMileageTo!) return false;
        if (_onlyUncrashed && !_looksUncrashed(x)) return false;
        return true;
      });
    }

    return out.toList();
  }

  @override
  Widget build(BuildContext context) {
    final listings = context.read<ListingsService>();
    final favs = context.read<FavoritesService>();
    final reviews = context.read<ReviewsService>();
    final notifications = context.read<NotificationsService>();
    final user = context.read<AuthService>().currentUser!;

    // ✅ hint как в Avito: “Поиск в <город>”
    final hint = _location.trim().isEmpty ? 'Поиск по названию' : 'Поиск в $_location';

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('CheStore'),
        actions: [
          StreamBuilder<int>(
            stream: notifications.streamUnreadBadgeCount(user.uid),
            builder: (context, snap) {
              final unread = snap.data ?? 0;
              final icon = IconButton(
                tooltip: 'Уведомления',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
                icon: Icon(
                  unread > 0
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  color: unread > 0 ? Colors.red : null,
                ),
              );

              if (unread <= 0) return icon;

              return Badge(
                backgroundColor: Colors.red,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: icon,
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddListingScreen()),
            ),
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryRow(selected: _category, onSelect: _selectCategory),

          // ✅ Поиск как раньше, но с круглыми углами и фильтром справа
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),

                // ✅ справа фильтр как Avito
                suffixIcon: IconButton(
                  tooltip: 'Фильтры',
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune),
                ),

                hintText: hint,
                isDense: true,

                // ✅ круглые углы
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.6,
                  ),
                ),
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

                    var items = snap.data!;
                    if (items.isEmpty) {
                      return const Center(child: Text('Пока нет объявлений'));
                    }

                    // ✅ “Мой регион сначала” (НЕ фильтр, только порядок)
                    items = _applyLocationPriority(items);
                    items = _applyAdvancedFilters(items);

                    if (items.isEmpty) {
                      return const Center(child: Text('Ничего не найдено по фильтрам'));
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

                        return ListingCard(
                          listing: item,
                          isFav: favIds.contains(item.id),
                          reviews: reviews,
                          onToggleFav: (makeFav) async {
                            try {
                              await favs.toggleFavorite(
                                uid: user.uid,
                                listingId: item.id,
                                makeFavorite: makeFav,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            }
                          },
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

// =====================
// Filters (Avito-like)
// =====================

class _HomeFilters {
  final String category;
  final String location; // город/регион строкой
  final bool preferFirst; // “Сначала из …”
  final int? radiusKm;
  final String autoBrand;
  final String autoModel;
  final String autoCondition;
  final int? autoMileageTo;
  final bool onlyUncrashed;

  const _HomeFilters({
    required this.category,
    required this.location,
    required this.preferFirst,
    required this.radiusKm,
    required this.autoBrand,
    required this.autoModel,
    required this.autoCondition,
    required this.autoMileageTo,
    required this.onlyUncrashed,
  });
}

class _FiltersScreen extends StatefulWidget {
  final String initialCategory;
  final String initialLocation;
  final bool initialPreferFirst;
  final int? initialRadiusKm;
  final String initialAutoBrand;
  final String initialAutoModel;
  final String initialAutoCondition;
  final int? initialAutoMileageTo;
  final bool initialOnlyUncrashed;

  const _FiltersScreen({
    required this.initialCategory,
    required this.initialLocation,
    required this.initialPreferFirst,
    required this.initialRadiusKm,
    required this.initialAutoBrand,
    required this.initialAutoModel,
    required this.initialAutoCondition,
    required this.initialAutoMileageTo,
    required this.initialOnlyUncrashed,
  });

  @override
  State<_FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<_FiltersScreen> {
  late String _category = widget.initialCategory;
  late String _location = widget.initialLocation;
  late bool _preferFirst = widget.initialPreferFirst;
  late int? _radiusKm = widget.initialRadiusKm;
  late String _autoBrand = widget.initialAutoBrand;
  late String _autoModel = widget.initialAutoModel;
  late String _autoCondition = widget.initialAutoCondition;
  late int? _autoMileageTo = widget.initialAutoMileageTo;
  late bool _onlyUncrashed = widget.initialOnlyUncrashed;

  final TextEditingController _mileageCtrl = TextEditingController();

  bool get _isAutoCategory {
    final c = _category.trim().toLowerCase();
    return c == 'авто' || c.contains('авто') || c.contains('рђрвс');
  }

  static const List<String> _carConditions = <String>[
    'Отличное',
    'Хорошее',
    'Требует ремонта',
    'После ДТП',
    'Не битый',
  ];

  @override
  void initState() {
    super.initState();
    _mileageCtrl.text = _autoMileageTo?.toString() ?? '';
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = kCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Фильтры'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _category = 'Все';
                _location = '';
                _preferFirst = false;
                _radiusKm = null;
                _autoBrand = '';
                _autoModel = '';
                _autoCondition = '';
                _autoMileageTo = null;
                _onlyUncrashed = false;
                _mileageCtrl.clear();
              });
            },
            child: const Text('Сбросить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'Категория',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cats.map((c) {
              final selected = _category == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          if (_isAutoCategory) ...[
            DropdownButtonFormField<String>(
              value: _autoBrand.isEmpty ? null : _autoBrand,
              items: kAutoBrandsPopular
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _autoBrand = v ?? '';
                  _autoModel = '';
                });
              },
              decoration: const InputDecoration(
                labelText: 'Марка',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _autoModel.isEmpty ? null : _autoModel,
              items: (_autoBrand.isEmpty
                      ? const <String>[]
                      : (kAutoModels[_autoBrand] ?? const <String>[]))
                  .where((m) => !m.toLowerCase().contains('другая'))
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _autoModel = v ?? ''),
              decoration: const InputDecoration(
                labelText: 'Модель',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _autoCondition.isEmpty ? null : _autoCondition,
              items: _carConditions
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (v) => setState(() => _autoCondition = v ?? ''),
              decoration: const InputDecoration(
                labelText: 'Состояние',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mileageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Пробег до (км)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {
                  _autoMileageTo = int.tryParse(v.trim());
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _onlyUncrashed,
              onChanged: (v) => setState(() => _onlyUncrashed = v),
              title: const Text('Только не битые'),
            ),
            const SizedBox(height: 8),
          ],

          // ✅ “Где искать” как Avito
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: const Icon(Icons.place_outlined),
            title: const Text('Где искать'),
            subtitle: Text(_location.trim().isEmpty ? 'Не выбрано' : _location),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final res = await Navigator.of(context).push<_WhereResult>(
                MaterialPageRoute(
                  builder: (_) => _WhereToSearchScreen(
                    initialLocation: _location,
                    initialPreferFirst: _preferFirst,
                    initialRadiusKm: _radiusKm,
                  ),
                ),
              );

              if (!mounted || res == null) return;

              setState(() {
                _location = res.location;
                _preferFirst = res.preferFirst;
                _radiusKm = res.radiusKm;
              });
            },
          ),

          const SizedBox(height: 16),

          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                _HomeFilters(
                  category: _category,
                  location: _location.trim(),
                  preferFirst: _preferFirst,
                  radiusKm: _radiusKm,
                  autoBrand: _autoBrand,
                  autoModel: _autoModel,
                  autoCondition: _autoCondition,
                  autoMileageTo: _autoMileageTo,
                  onlyUncrashed: _onlyUncrashed,
                ),
              );
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }
}

// =====================
// “Где искать” (Avito)
// =====================

class _WhereResult {
  final String location;
  final bool preferFirst;
  final int? radiusKm;

  const _WhereResult({
    required this.location,
    required this.preferFirst,
    required this.radiusKm,
  });
}

class _WhereToSearchScreen extends StatefulWidget {
  final String initialLocation;
  final bool initialPreferFirst;
  final int? initialRadiusKm;

  const _WhereToSearchScreen({
    required this.initialLocation,
    required this.initialPreferFirst,
    required this.initialRadiusKm,
  });

  @override
  State<_WhereToSearchScreen> createState() => _WhereToSearchScreenState();
}

class _WhereToSearchScreenState extends State<_WhereToSearchScreen> {
  late final TextEditingController _locCtrl =
      TextEditingController(text: widget.initialLocation);

  late bool _preferFirst = widget.initialPreferFirst;
  late int? _radiusKm = widget.initialRadiusKm;

  @override
  void dispose() {
    _locCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationText = _locCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Где искать'),
        actions: [
          TextButton(
            onPressed: () {
              _locCtrl.clear();
              setState(() {
                _preferFirst = false;
                _radiusKm = null;
              });
            },
            child: const Text('Сбросить'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Город или регион', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _locCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Например: Москва',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 14),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _preferFirst,
            onChanged: (v) => setState(() => _preferFirst = v),
            title: Text(
              locationText.isEmpty
                  ? 'Сначала из выбранного региона'
                  : 'Сначала из $locationText',
            ),
          ),

          const SizedBox(height: 12),

          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            title: const Text('Радиус'),
            subtitle: Text(_radiusKm == null ? 'Не выбран' : '$_radiusKm км'),
            trailing: const Icon(Icons.chevron_right),
            enabled: locationText.isNotEmpty,
            onTap: locationText.isEmpty
                ? null
                : () async {
                    final r = await Navigator.of(context).push<int?>(
                      MaterialPageRoute(
                        builder: (_) => _RadiusPickerScreen(
                          title: locationText,
                          initialRadiusKm: _radiusKm,
                        ),
                      ),
                    );

                    if (!mounted) return;
                    setState(() => _radiusKm = r);
                  },
          ),

          const SizedBox(height: 18),

          SafeArea(
            top: false,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _WhereResult(
                    location: _locCtrl.text.trim(),
                    preferFirst: _preferFirst,
                    radiusKm: _radiusKm,
                  ),
                );
              },
              child: const Text('Применить'),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// Radius (Avito-like)
// =====================

class _RadiusPickerScreen extends StatefulWidget {
  final String title;
  final int? initialRadiusKm;

  const _RadiusPickerScreen({
    required this.title,
    required this.initialRadiusKm,
  });

  @override
  State<_RadiusPickerScreen> createState() => _RadiusPickerScreenState();
}

class _RadiusPickerScreenState extends State<_RadiusPickerScreen> {
  static const _options = <int>[1, 2, 3, 5, 10];

  int? _radiusKm;
  LatLng _center = const LatLng(55.751244, 37.618423); // дефолт Москва

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initialRadiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _radiusKm;

    return Scaffold(
      appBar: AppBar(title: const Text('Радиус поиска')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.title,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
            ),
          ),

          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 12,
                onTap: (tapPos, p) => setState(() => _center = p),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.chestore2',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_pin, size: 44),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ✅ кнопки радиуса как Avito
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _options.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          final isSel = selected == null;
                          return ChoiceChip(
                            label: const Text('Не выбран'),
                            selected: isSel,
                            onSelected: (_) => setState(() => _radiusKm = null),
                          );
                        }

                        final km = _options[i - 1];
                        final isSel = selected == km;
                        return ChoiceChip(
                          label: Text('$km км'),
                          selected: isSel,
                          onSelected: (_) => setState(() => _radiusKm = km),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _radiusKm),
                    child: const Text('Применить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



