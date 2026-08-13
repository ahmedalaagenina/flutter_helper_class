
abstract final class WireFormat {
  /// `yyyy-MM-dd`
  static String date(DateTime value) =>
      '${_pad(value.year, 4)}-${_pad(value.month)}-${_pad(value.day)}';

  /// `HH:mm`, 24-hour.
  static String time(DateTime value) =>
      '${_pad(value.hour)}:${_pad(value.minute)}';

  /// `yyyy-MM-dd HH:mm:ss`
  static String timestamp(DateTime value) =>
      '${date(value)} ${time(value)}:${_pad(value.second)}';

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');
}
