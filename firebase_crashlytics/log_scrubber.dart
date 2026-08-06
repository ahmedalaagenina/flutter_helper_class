/// Removes credentials from text that is about to leave the device.
///
/// ## Why this exists
///
/// An error's `toString()` is written for a developer reading a console, not
/// for a report leaving a user's phone. It routinely carries the request that
/// failed — URL, headers, body — and any of the three can hold a credential.
/// An API that authenticates by **query parameter** puts one in *every* URL, so
/// a single exception uploaded verbatim can ship standing access to a
/// customer's account to your crash dashboard.
///
/// Whether a given HTTP client's `toString()` includes the URI today is a
/// detail of its current version, not a guarantee. So scrubbing is
/// unconditional: nothing reaches the reporter without passing through here.
///
/// ## ⛔ What this must never become
///
/// This scrubs a **copy of a string, for reporting**. It must never be wired
/// into an HTTP client's request-building path — a Dio `Interceptor.onRequest`,
/// a `filter`, an `HttpClient` wrapper — to mask the request itself.
///
/// That was tried once and shipped: the masking wrote to
/// `options.queryParameters`, which runs *before* the client dispatches, so it
/// did not redact the log — it rewrote the real request. Every call went out
/// with `token=***`, the server answered `401 Wrong credentials`, and the app
/// force-logged-out after every successful login, with logs that looked
/// correct because the masked value was genuinely what had been sent.
///
/// Scrub a copy. Never the request.
///
/// ## Usage
///
/// The defaults cover the credential names and secret shapes common to most
/// APIs, so zero-config works:
///
/// ```dart
/// LogScrubber().scrub('GET /login?token=abc123');  // GET /login?token=***
/// ```
///
/// Add whatever your own API calls its credential — once, at startup:
///
/// ```dart
/// LogScrubber.instance = LogScrubber(
///   extraSensitiveKeys: {'user_api_hash', 'device_secret'},
/// );
/// ```
class LogScrubber {
  /// Builds a scrubber.
  ///
  /// [sensitiveKeys] replaces the default key list; [extraSensitiveKeys] adds
  /// to it. Prefer the latter — the defaults are the reason this is safe out of
  /// the box. Same pairing for [valuePatterns] / [extraValuePatterns].
  factory LogScrubber({
    Set<String> sensitiveKeys = defaultSensitiveKeys,
    Set<String> extraSensitiveKeys = const {},
    List<RegExp>? valuePatterns,
    List<RegExp> extraValuePatterns = const [],
    String redacted = '***',
  }) {
    final keys = {...sensitiveKeys, ...extraSensitiveKeys};
    return LogScrubber._(
      keys: keys,
      patterns: [
        ...valuePatterns ?? defaultValuePatterns,
        ...extraValuePatterns,
      ],
      redacted: redacted,
      assignment: _assignmentPattern(keys),
      keyWord: _keyWordPattern(keys),
    );
  }

  LogScrubber._({
    required this.keys,
    required this.patterns,
    required this.redacted,
    required RegExp assignment,
    required RegExp keyWord,
  }) : _assignment = assignment,
       _keyWord = keyWord;

  /// The scrubber used by `CrashReporter` when its config names none, and by
  /// any call site that just wants "the app's scrubber".
  ///
  /// Assign once in `main()`, before the first report can be filed.
  static LogScrubber instance = LogScrubber();

  /// Key fragments whose value is a credential.
  ///
  /// Matched as a **substring** of the key, so `token` also covers
  /// `access_token`, `X-Auth-Token` and `refreshTokenExpiry`. That is why the
  /// list is short: add the distinctive word, not every compound.
  ///
  /// Deliberately absent: bare `key` and `id`. Flutter's own error messages are
  /// full of `key: [<'home'>]`, and redacting those would cost more debugging
  /// than it saves.
  static const Set<String> defaultSensitiveKeys = {
    'password',
    'passwd',
    'pwd',
    'passphrase',
    'passcode',
    'secret',
    'token',
    'apikey',
    'api_key',
    'api-key',
    'authorization',
    'auth',
    'bearer',
    'credential',
    'privatekey',
    'private_key',
    'private-key',
    'signature',
    'sessionid',
    'session_id',
    'cookie',
    'otp',
    'ott',
    'pincode',
    'pin_code',
    'cvv',
    'cvc',
    'ssn',
    'cardnumber',
    'card_number',
  };

  /// Personal data, not credentials. Opt in when your reports must not carry
  /// identifiers: `LogScrubber(extraSensitiveKeys: LogScrubber.piiKeys)`.
  static const Set<String> piiKeys = {
    'email',
    'phone',
    'mobile',
    'msisdn',
    'address',
    'dob',
    'birth_date',
    'national_id',
    'iqama',
    'passport',
    'latitude',
    'longitude',
  };

  /// A bcrypt hash, for the paths where it is not a key/value pair — a log line
  /// that interpolated one, or a JSON body echoing it back.
  ///
  /// Both plain and percent-encoded, since a URL renders `$` as `%24`.
  static final RegExp bcryptHash = RegExp(
    r'\$2[aby]\$\d{2}\$[./A-Za-z0-9]{20,}'
    r'|%242[aby]%24\d{2}%24[./A-Za-z0-9%]{20,}',
  );

  /// A JWT, anywhere. Catches `Authorization: Bearer …` even when the header
  /// name was mangled on its way into the string.
  static final RegExp jwt = RegExp(
    r'\beyJ[A-Za-z0-9_=-]{6,}\.[A-Za-z0-9_=-]{6,}\.[A-Za-z0-9_=.+/-]{6,}',
  );

  /// `https://user:password@host` — the credential is in the authority, where
  /// no key/value rule would find it.
  static final RegExp urlCredentials = RegExp(r'(?<=://)[^/\s:@]+:[^/\s:@]+(?=@)');

  /// A PEM private key pasted into a message or config dump.
  static final RegExp privateKeyBlock = RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
  );

  /// Vendor keys with a fixed, unmistakable shape.
  ///
  /// No trailing `\b`: a key run together with the next token should still be
  /// redacted, and matching 35 of a longer run costs nothing.
  static final RegExp googleApiKey = RegExp(r'\bAIza[0-9A-Za-z_-]{35}');
  static final RegExp awsAccessKeyId = RegExp(r'\b(?:AKIA|ASIA)[0-9A-Z]{16}');
  static final RegExp githubToken = RegExp(r'\bgh[pousr]_[0-9A-Za-z]{20,}');
  static final RegExp slackToken = RegExp(r'\bxox[abposr]-[0-9A-Za-z-]{10,}');

  /// An email address. PII, not a credential — see [piiValuePatterns].
  static final RegExp emailAddress = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );

  /// 13–19 digits with optional spaces or dashes.
  ///
  /// ⚠️ Loose by design, and it will also eat long numeric ids and epoch
  /// millis. Opt in only when card data really can reach your logs.
  static final RegExp creditCardNumber = RegExp(r'\b(?:\d[ -]?){13,19}\b');

  /// Secret shapes redacted regardless of the key they sat under.
  static final List<RegExp> defaultValuePatterns = [
    bcryptHash,
    jwt,
    urlCredentials,
    privateKeyBlock,
    googleApiKey,
    awsAccessKeyId,
    githubToken,
    slackToken,
  ];

  /// Personal data shapes. Opt in with `extraValuePatterns`.
  static final List<RegExp> piiValuePatterns = [emailAddress, creditCardNumber];

  /// The key fragments this instance treats as sensitive.
  final Set<String> keys;

  /// The value shapes this instance redacts on sight.
  final List<RegExp> patterns;

  /// What a redacted value is replaced with.
  ///
  /// Keep it free of `&`, whitespace, quotes and closing brackets, or [scrub]
  /// stops being idempotent and [looksSensitive] starts reporting its own
  /// output as a leak.
  final String redacted;

  final RegExp _assignment;
  final RegExp _keyWord;

  /// Returns [text] with every credential replaced.
  ///
  /// Deliberately over-eager: a redacted word that was harmless costs a little
  /// debugging, a leaked token costs a customer's account. Idempotent — running
  /// it on already-scrubbed text changes nothing.
  String scrub(String text) {
    var result = text.replaceAllMapped(
      _assignment,
      // Groups rebuild the original punctuation, so JSON stays JSON and a
      // query string stays a query string: `"password":"***"`, `token=***`.
      (match) => '${match[1]}${match[2]}${match[3]}${match[4]}$redacted',
    );
    for (final pattern in patterns) {
      result = result.replaceAll(pattern, redacted);
    }
    return result;
  }

  /// [scrub] that passes `null` through, for optional `reason` strings.
  String? scrubOrNull(String? text) => text == null ? null : scrub(text);

  /// True when [key] names a credential — e.g. `Authorization`, `api_key`.
  bool isSensitiveKey(String key) => _keyWord.hasMatch(key);

  /// Scrubs a map for reporting: sensitive keys lose their value entirely,
  /// everything else is scrubbed as text.
  ///
  /// Use for headers, query maps, or a bag of custom keys.
  Map<String, String> scrubMap(Map<Object?, Object?> map) {
    return {
      for (final entry in map.entries)
        entry.key.toString(): isSensitiveKey(entry.key.toString())
            ? redacted
            : scrub('${entry.value}'),
    };
  }

  /// True when [text] still contains something that looks like a credential.
  ///
  /// For asserting in tests, not for branching at runtime — [scrub] is not
  /// conditional.
  bool looksSensitive(String text) => scrub(text) != text;

  /// `token=`, `"password": "`, `X-Api-Key: Bearer `, `\"secret\":\"` …
  ///
  /// The key is matched as a substring of a larger identifier, the separator
  /// and quoting are captured so they can be put back, and an auth scheme
  /// prefix is swallowed into the redaction — otherwise `authorization: Bearer
  /// eyJ…` would redact the word `Bearer` and leave the token behind.
  static RegExp _assignmentPattern(Set<String> keys) {
    return RegExp(
      // Not mid-word on the left, so `xtoken` is skipped while `x_token`, whose
      // prefix is consumed by the group below, is not.
      r'(?<![A-Za-z0-9])'
      '([A-Za-z0-9_.\\-\\[\\]]*(?:${_alternation(keys)})[A-Za-z0-9_.\\-\\[\\]]*)'
      r'''((?:\\)?["']?)\s*([:=])\s*'''
      r'(?:(?:bearer|basic|token|key)\s+)?'
      r'''((?:\\)?["']?)[^&\s,;"'}\)\]>]+''',
      caseSensitive: false,
    );
  }

  static RegExp _keyWordPattern(Set<String> keys) =>
      RegExp(_alternation(keys), caseSensitive: false);

  static String _alternation(Set<String> keys) =>
      keys.map(RegExp.escape).join('|');
}
