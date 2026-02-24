import 'package:intl/intl.dart';

String formatPrice(int value) {
  final f = NumberFormat('#,###', 'ru_RU');
  return f.format(value).replaceAll(',', ' ');
}
