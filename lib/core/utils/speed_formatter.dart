import 'package:intl/intl.dart';

class SpeedFormatter {
  static String format(double mbps, {int decimals = 1}) {
    if (mbps < 0) return '--';
    final fmt = NumberFormat('#,##0.${'0' * decimals}');
    return '${fmt.format(mbps)} Mbps';
  }

  static String formatMbps(double? value, {int decimals = 1}) {
    if (value == null) return '--';
    return format(value, decimals: decimals);
  }
}
