import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:chestore2/src/services/yandex_suggest_service.dart';

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final _yandex = YandexSuggestService();
  final TextEditingController _qCtrl = TextEditingController();

  int _tab = 0;
  Timer? _debounce;
  bool _loadingSuggest = false;
  String? _suggestError;
  List<String> _suggestions = const [];

  LatLng _picked = const LatLng(55.751244, 37.618423);
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
      // Keep the default point if location lookup fails.
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  void _onQueryChanged() {
    final text = _qCtrl.text.trim();
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

  void _onSuggestionTap(String value) {
    final label = value.trim();
    if (label.isEmpty) return;
    Navigator.of(context).maybePop(label);
  }

  Future<void> _onMapChoose() async {
    if (!mounted) return;
    Navigator.of(context).maybePop(_picked);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Место'),
          actions: [
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
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _qCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Начните писать: Грозный, Москва, Шонни…',
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
                        final value = _suggestions[i];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            value,
                            maxLines: 3,
                            overflow: TextOverflow.fade,
                          ),
                          onTap: () => _onSuggestionTap(value),
                        );
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildMap(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _picked,
        initialZoom: 11,
        onTap: (_, point) => setState(() => _picked = point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
