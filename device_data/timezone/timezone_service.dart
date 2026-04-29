import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:idara_esign/core/services/logger_service.dart';

abstract class ITimezoneService {
  Future<String?> getTimezone();
}

class TimezoneService implements ITimezoneService {
  const TimezoneService();

  @override
  Future<String?> getTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      return timezone.identifier;
    } catch (e) {
      AppLog.e('Failed to get timezone: $e');
      return null;
    }
  }
}
