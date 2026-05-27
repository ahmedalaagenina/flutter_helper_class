/// Pluggable strategy that pulls a user-facing message out of a server
/// error payload. Swap implementations to match your backend without
/// touching [ApiFailureHandler].
///
/// Wire it once at app boot:
/// ```dart
/// ApiFailureHandler.messageExtractor = LaravelMessageExtractor();
/// ```
abstract class ServerMessageExtractor {
  const ServerMessageExtractor();

  /// Returns a non-empty user-facing message, or `null` if none can be
  /// extracted (caller will fall back to a localized default).
  String? extract(dynamic responseData);
}

/// Default extractor. Handles three common shapes:
/// 1. `{ 'message': 'foo' }`
/// 2. `{ 'error': 'foo' }` or `{ 'error': { 'message': 'foo' } }`
/// 3. `{ 'errors': { 'field': ['msg1', 'msg2'], … } }` — Laravel-style.
///    Joins all field errors with `\n` instead of dropping all but the first.
class DefaultServerMessageExtractor extends ServerMessageExtractor {
  const DefaultServerMessageExtractor();

  @override
  String? extract(dynamic data) {
    if (data is! Map) return null;
    try {
      // errors: { field: [msg, ...] }
      final errors = data['errors'];
      if (errors is Map) {
        final all = <String>[];
        for (final value in errors.values) {
          if (value is List) {
            for (final v in value) {
              final s = v?.toString();
              if (s != null && s.isNotEmpty) all.add(s);
            }
          } else if (value is String && value.isNotEmpty) {
            all.add(value);
          }
        }
        if (all.isNotEmpty) return all.join('\n');
      }

      // message: 'foo'
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;

      // error: 'foo' or error: { message: 'foo' }
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
      if (error is Map) {
        final msg = error['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return null;
  }
}
