import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime dt) {
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  static String formatShort(DateTime dt) {
    return DateFormat('dd/MM/yy HH:mm').format(dt);
  }

  static String formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy · HH:mm').format(dt);
  }

  static String formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} mnt lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return formatShort(dt);
  }
}
