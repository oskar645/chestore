import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chestore2/src/secrets/yandex_suggest_key.dart';

class YandexSuggestService {
  static const String _baseUrl = 'https://suggest-maps.yandex.ru/v1/suggest';

  Future<List<String>> suggest(String text) async {
    final query = text.trim();
    if (query.length < 2) return const <String>[];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: <String, String>{
      'apikey': kYandexSuggestApiKey,
      'text': query,
      'lang': 'ru_RU',
      'print_address': '1',
      'results': '10',
    });

    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        return const <String>[];
      }

      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const <dynamic>[];
      final out = <String>[];
      final seen = <String>{};

      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;

        final fullText = _buildFullSuggestion(item);
        if (fullText.isEmpty) continue;

        final normalized = fullText.toLowerCase();
        if (seen.add(normalized)) {
          out.add(fullText);
        }
      }

      return out;
    } catch (_) {
      return const <String>[];
    }
  }

  String _buildFullSuggestion(Map<String, dynamic> item) {
    final title = _readNestedText(item, 'title');
    final subtitle = _readNestedText(item, 'subtitle');
    final formattedAddress = _readFormattedAddress(item);

    final combined = <String>[
      if (title.isNotEmpty) title,
      if (subtitle.isNotEmpty) subtitle,
    ].join(', ').trim();

    if (formattedAddress.isNotEmpty && formattedAddress.length > combined.length) {
      return formattedAddress;
    }

    return combined.isNotEmpty ? combined : formattedAddress;
  }

  String _readNestedText(Map<String, dynamic> item, String key) {
    final block = item[key];
    if (block is Map && block['text'] != null) {
      return block['text'].toString().trim();
    }
    return '';
  }

  String _readFormattedAddress(Map<String, dynamic> item) {
    final address = item['address'];
    if (address is Map && address['formatted_address'] != null) {
      return address['formatted_address'].toString().trim();
    }
    return '';
  }
}
