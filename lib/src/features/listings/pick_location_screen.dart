import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  LatLng _picked = const LatLng(55.751244, 37.618423); // Москва по умолчанию
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Проверка разрешений
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      // В эмуляторе может быть выключена “геопозиция” — тогда останется Москва
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        _picked = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      // если что-то пошло не так — просто оставляем Москву
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбрать место'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _picked),
            child: const Text('Готово'),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: _picked,
                initialZoom: 11,
                onTap: (tapPosition, point) {
                  setState(() => _picked = point);
                },
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
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _picked),
            icon: const Icon(Icons.check),
            label: const Text('Выбрать это место'),
          ),
        ),
      ),
    );
  }
}
