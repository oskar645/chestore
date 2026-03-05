// lib/src/services/yandex_suggest_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:chestore2/src/secrets/yandex_suggest_key.dart';

/// Сервис для работы с API Геосаджеста Яндекса.
class YandexSuggestService {
  // Базовый URL из документации:
  // https://suggest-maps.yandex.ru/v1/suggest
  static const String _baseUrl = 'https://suggest-maps.yandex.ru/v1/suggest';

  /// Получаем подсказки по строке [text].
  ///
  /// Возвращаем просто список красивых адресов/городов.
  Future<List<String>> suggest(String text) async {
    final q = text.trim();

    // Слишком короткий запрос — не дергаем API
    if (q.length < 2) return const <String>[];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: <String, String>{
      'apikey': kYandexSuggestApiKey,
      'text': q,
      'lang': 'ru_RU',
      // Можно ограничить типы, но это не обязательно
      // 'types': 'locality,street,house',
      'print_address': '1',
      'results': '10',
    });

    try {
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        // Выведем ошибку в консоль, чтобы можно было увидеть в DevTools
        // ignore: avoid_print
        print(
            'YandexSuggest error: ${resp.statusCode} ${resp.body.toString()}');
        return const <String>[];
      }

      final data =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      // В ответе подсказки лежат в массиве "results"
      final List results = (data['results'] as List?) ?? const <dynamic>[];

      final List<String> out = <String>[];

      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;

        String? titleText;

        // Основное название лежит в item["title"]["text"]
        final title = item['title'];
        if (title is Map && title['text'] != null) {
          titleText = title['text'].toString();
        }

        // Если вдруг нет title, можно взять formatted_address
        if ((titleText == null || titleText.trim().isEmpty) &&
            item['address'] is Map &&
            (item['address']['formatted_address'] != null)) {
          titleText = item['address']['formatted_address'].toString();
        }

        if (titleText != null && titleText.trim().isNotEmpty) {
          out.add(titleText.trim());
        }
      }

      // ignore: avoid_print
      print('YandexSuggest: запрос "$q" → ${out.length} вариантов');
      return out;
    } catch (e) {
      // На случай ошибок сети / CORS и т.п.
      // ignore: avoid_print
      print('YandexSuggest exception: $e');
      return const <String>[];
    }
  }
}