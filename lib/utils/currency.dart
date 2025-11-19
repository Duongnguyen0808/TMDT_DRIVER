import 'package:intl/intl.dart';

final _vnFormat = NumberFormat('#,##0', 'vi_VN');

String formatVND(num value) {
  try {
    return _vnFormat.format(value) + 'đ';
  } catch (_) {
    return value.toString() + 'đ';
  }
}
