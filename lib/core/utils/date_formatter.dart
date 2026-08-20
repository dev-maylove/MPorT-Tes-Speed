import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _time = DateFormat('HH:mm:ss');
  static final DateFormat _date = DateFormat('dd MMM yyyy');

  static String formatDateTime(DateTime dt) => _dateTime.format(dt);
  static String formatTime(DateTime dt) => _time.format(dt);
  static String formatDate(DateTime dt) => _date.format(dt);
}
