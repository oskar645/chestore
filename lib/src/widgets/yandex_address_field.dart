import 'dart:async';
import 'package:flutter/material.dart';

import 'package:chestore2/src/services/yandex_suggest_service.dart';

class YandexAddressField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final void Function(String value)? onSelected;

  const YandexAddressField({
    super.key,
    required this.controller,
    this.label = 'Адрес',
    this.onSelected,
  });

  @override
  State<YandexAddressField> createState() => _YandexAddressFieldState();
}

class _YandexAddressFieldState extends State<YandexAddressField> {
  final _service = YandexSuggestService();
  Timer? _debounce;
  bool _loading = false;
  List<String> _items = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _load(value);
    });
  }

  Future<void> _load(String value) async {
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _service.suggest(q);
      if (!mounted) return;
      setState(() {
        _items = res;
      });
    } catch (e) {
      // Можно показать SnackBar, если хочешь
      if (!mounted) return;
      setState(() {
        _items = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(String v) {
    widget.controller.text = v;
    if (widget.onSelected != null) {
      widget.onSelected!(v);
    }
    setState(() {
      _items = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
            isDense: true,
            suffixIcon:
                _loading ? const SizedBox(width: 20, height: 20, child: Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )) : null,
          ),
          onChanged: _onChanged,
        ),
        if (_items.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final v = _items[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    v,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _select(v),
                );
              },
            ),
          ),
      ],
    );
  }
}
