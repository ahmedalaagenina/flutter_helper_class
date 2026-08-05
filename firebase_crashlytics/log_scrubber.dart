/// Removes credentials from text that is about to leave the device.
///
/// ## Why this exists
///
/// GPSWOX authenticates by **query parameter**, so every request URL in the app
/// carries a `user_api_hash`. A `DioException.toString()` includes that URL, so
/// reporting one verbatim ships a permanent fleet credential to Crashlytics —
/// standing access to a customer's whole fleet, including the command endpoints
/// that can cut an engine. See CLAUDE.md §0.3.
///
/// ## ⛔ What this must never become
///
/// This scrubs a **copy of a string, for reporting**. It must never be wired
/// into a Dio interceptor's `filter`/`onRequest` to mask the request itself.
///
/// That was tried once and shipped: masking wrote to `options.queryParameters`,
/// which runs *before* Dio dispatches, so it did not redact the log — it
/// rewrote the real request. Every call went out as
/// `user_api_hash=***REDACTED***`, GPSWOX answered `401 Wrong credentials.`,
/// and the app force-logged-out after every successful login, with logs that
/// looked correct because the masked value was genuinely what was sent.
///
/// Scrub a copy. Never `options`.
abstract final class LogScrubber {
  static const String redacted = '***';

  /// Query parameters whose value is a credential.
  ///
  /// Matched up to the next separator rather than to `&` alone, because these
  /// strings arrive from `toString()` and are as often prose as they are URLs.
  static final RegExp _sensitiveParam = RegExp(
    r'\b(user_api_hash|password|auth_token|auth_id|token|ott)'
    r'\s*[=:]\s*'
    r'[^&\s,;"}\]]*',
    caseSensitive: false,
  );

  /// A bcrypt hash on its own, for the paths where it is not a query parameter
  /// — a log line that interpolated it, or a JSON body echoing it back.
  ///
  /// Both plain and percent-encoded, since a URL renders `$` as `%24`.
  static final RegExp _bcryptHash = RegExp(
    r'\$2[aby]\$\d{2}\$[./A-Za-z0-9]{20,}'
    r'|%242[aby]%24\d{2}%24[./A-Za-z0-9%]{20,}',
  );

  /// Returns [text] with every credential replaced.
  ///
  /// Deliberately over-eager: a redacted word that was harmless costs nothing,
  /// a leaked hash costs a customer's fleet.
  static String scrub(String text) => text
      .replaceAllMapped(
        _sensitiveParam,
        (match) => '${match.group(1)}=$redacted',
      )
      .replaceAll(_bcryptHash, redacted);

  /// True when [text] still contains something that looks like a credential.
  ///
  /// For asserting in tests, not for branching at runtime — [scrub] is not
  /// conditional.
  static bool looksSensitive(String text) =>
      _bcryptHash.hasMatch(text) ||
      RegExp(
        r'\b(user_api_hash|password)\s*[=:]\s*[^&\s,;"}\]$]',
        caseSensitive: false,
      ).hasMatch(text.replaceAll('=$redacted', '='));
}
