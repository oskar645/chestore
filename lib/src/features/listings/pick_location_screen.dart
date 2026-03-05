// lib/src/features/listings/pick_location_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:chestore2/src/services/yandex_suggest_service.dart';

/// Этот экран ВОЗВРАЩАЕТ просто String:
/// Navigator.push<String>(..., MaterialPageRoute(builder: (_) => const PickLocationScreen()))
/// и потом в add_listing_screen.dart ты делаешь:
/// if (res != null) _city.text = res;
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final _yandex = YandexSuggestService();

// 0 = Поиск, 1 = Карта
  int _tab = 0;

// —-— поиск —---
  final TextEditingController _qCtrl = TextEditingController();
  Timer? _debounce;
  bool _loadingSuggest = false;
  String? _suggestError;
  List<String> _suggestions = const [];

// —-— карта —---
  LatLng _picked = const LatLng(55.751244, 37.618423); // Москва по умолчанию
  bool _loadingGeo = true;

  @override
  void initState() {
    super.initState();
    _initGeo();
    _qCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _qCtrl.removeListener(_onQueryChanged);
    _qCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initGeo() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        _picked = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
// если что-то пошло не так — остаётся Москва
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  void _onQueryChanged() {
    final text = _qCtrl.text.trim();
// простой debounce, чтобы не долбить Яндекс каждую букву
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadYandexSuggestions(text);
    });
  }

  Future<void> _loadYandexSuggestions(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _suggestError = null;
        _loadingSuggest = false;
      });
      return;
    }

    setState(() {
      _loadingSuggest = true;
      _suggestError = null;
    });

    try {
      final res = await _yandex.suggest(q);
      if (!mounted) return;
      setState(() {
        _suggestions = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestError = 'Ошибка Яндекс-подсказки: $e';
        _suggestions = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _loadingSuggest = false);
    }
  }

// красивый текст по точке (для карты)
  Future<String> _labelFromLatLng(LatLng p) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isEmpty) return 'Выбранная точка';

      final pm = placemarks.first;

      final parts = <String>[
        if ((pm.locality ?? '').trim().isNotEmpty) pm.locality!.trim(),
        if ((pm.subLocality ?? '').trim().isNotEmpty) pm.subLocality!.trim(),
        if ((pm.administrativeArea ?? '').trim().isNotEmpty)
          pm.administrativeArea!.trim(),
      ];

      final text = parts.where((e) => e.isNotEmpty).join(', ');
      return text.isEmpty ? 'Выбранная точка' : text;
    } catch (_) {
      return 'Выбранная точка';
    }
  }

// Выбор подсказки → просто закрываем экран и возвращаем строку
  void _onSuggestionTap(String value) {
    final label = value.trim();
    if (label.isEmpty) return;
    Navigator.of(context).pop(label);
  }

// Выбор точки на карте → делаем подпись и возвращаем строку
  Future<void> _onMapChoose() async {
    final label = await _labelFromLatLng(_picked);
    if (!mounted) return;
    Navigator.of(context).pop(label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Место'),
        actions: [
// "Готово" работает только на вкладке "Карта"
          TextButton(
            onPressed: _tab == 1 ? _onMapChoose : null,
            child: const Text('Готово'),
          ),
        ],
      ),
      body: _loadingGeo
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Поиск'),
                        icon: Icon(Icons.search),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Карта'),
                        icon: Icon(Icons.map_outlined),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                Expanded(
                  child: _tab == 0 ? _buildSearch(context) : _buildMap(context),
                ),
              ],
            ),
// нижняя кнопка нужна только для карты – при поиске убираем, чтобы не путать
      bottomNavigationBar: _tab == 1
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _onMapChoose,
                  icon: const Icon(Icons.check),
                  label: const Text('Выбрать это место'),
                ),
              ),
            )
          : null,
    );
  }

// —------— вкладка "Поиск" —--------
  Widget _buildSearch(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _qCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Начните писать: Грозный, Москва, Шуани…',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (_loadingSuggest)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Expanded(
          child: _suggestError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _suggestError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              : (_suggestions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Нет подсказок.\nПопробуйте уточнить запрос.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final v = _suggestions[i];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            v,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _onSuggestionTap(v),
                        );
                      },
                    )),
        ),
      ],
    );
  }

// —------— вкладка "Карта" —--------
  Widget _buildMap(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _picked,
        initialZoom: 11,
        onTap: (_, point) => setState(() => _picked = point),
      ),
      children: [
        TileLayer(
          urlTemplate:
              '[#alias|tile.openstreetmap.org/{z}/{x}/{y...|https://tile.openstreetmap.org/{z}/{x}/{y}.png]',
          userAgentPackageName: 'com.example.chestore2',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _picked,
              width: 44,
              height: 44,
              child: const Icon(Icons.location_pin, size: 44),
            ),
          ],
        ),
      ],
    );
  }
}
