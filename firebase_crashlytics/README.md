# Crash Reporter

Firebase Crashlytics wiring that **cannot leak a credential**, and that makes
reports readable instead of `DioException [bad response]: null`.

Self-contained and app-agnostic: it imports nothing from your app, so the folder
can be copied into any Flutter project as-is.

## Quick start

```dart
import 'package:my_app/core/crash/crash_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await CrashReporter.initialize();

  runApp(const MyApp());
}
```

That's the whole integration. Every framework error and every unhandled async
error is now reported, scrubbed, and **off in debug** — local crashes are
already visible in the console, and uploading them pollutes the release signal.

Add your API's own credential name once, and Dio's describer if you use Dio:

```dart
LogScrubber.instance = LogScrubber(
  extraSensitiveKeys: {'user_api_hash'},   // whatever your API calls it
);

await CrashReporter.initialize(
  config: const CrashReporterConfig(describers: [describeDioError]),
);
```

## Prerequisites

- `firebase_crashlytics` in `pubspec.yaml`, and `Firebase.initializeApp` awaited
  **before** `CrashReporter.initialize`
- `dio` only if you keep `dio_error_describer.dart` — delete that one file
  otherwise
- Crashlytics does not report from a debug build by default here. To exercise the
  pipeline itself, pass `collectionEnabled: true` and force a crash

## Files

| File | Responsibility |
|---|---|
| `crash_reporting.dart` | Barrel export — the only import you need |
| `crash_reporter.dart` | Handler installation, recording, breadcrumbs, custom keys |
| `crash_reporter_config.dart` | Every knob, with defaults |
| `log_scrubber.dart` | The redaction rules. Pure Dart, no Flutter, unit-testable |
| `crash_description.dart` | `CrashDescription` + the `ErrorDescriber` typedef |
| `dio_error_describer.dart` | Optional: readable `DioException` lines. Delete if unused |

`dio_error_describer.dart` is deliberately **not** exported from the barrel — it
is the only file that needs `dio`.

## Why the scrubbing is unconditional

An error's `toString()` is written for a developer reading a console, not for a
report leaving a user's phone. It routinely carries the request that failed, and
an API that authenticates by **query parameter** puts a credential in every URL:
one exception uploaded verbatim can ship standing access to a customer's account
to your crash dashboard.

Whether a given HTTP client's `toString()` includes the URI *today* is a detail
of its current version, not a guarantee. So nothing reaches Crashlytics without
passing through the scrubber — including describer output, `reason` strings,
breadcrumbs and custom-key values.

### ⛔ Never wire `LogScrubber` into the request path

It scrubs a **copy of a string, for reporting**. It must never go into a Dio
`Interceptor.onRequest`, a client `filter`, or anything that builds a request.

That was tried once and shipped: the masking wrote to
`options.queryParameters`, which runs *before* the client dispatches, so it did
not redact the log — it rewrote the real request. Every call went out with
`token=***`, the server answered `401 Wrong credentials`, and the app
force-logged-out after every successful login, with logs that looked correct
because the masked value was genuinely what had been sent.

Scrub a copy. Never the request.

## What gets redacted

**By key** — matched as a *substring*, case-insensitively, so `token` also
covers `access_token`, `X-Auth-Token` and `csrf_token`. Quoting and separators
are preserved, so JSON stays JSON:

| Input | Output |
|---|---|
| `?user_api_hash=$2y$10$abc…&lang=en` | `?user_api_hash=***&lang=en` |
| `{"password": "hunter2"}` | `{"password":"***"}` |
| `authorization: Bearer eyJhbGci…` | `authorization:***` |
| `X-Api-Key: abc123` | `X-Api-Key:***` |

Defaults: `password`, `passwd`, `pwd`, `passphrase`, `passcode`, `secret`,
`token`, `apikey`/`api_key`/`api-key`, `authorization`, `auth`, `bearer`,
`credential`, `private_key`, `signature`, `sessionid`/`session_id`, `cookie`,
`otp`, `ott`, `pincode`, `cvv`, `cvc`, `ssn`, `card_number`.

Bare `key` and `id` are **deliberately absent**: Flutter's own error messages are
full of `key: [<'home'>]`, and redacting those costs more debugging than it
saves.

**By shape** — regardless of the key it sat under: bcrypt hashes (plain and
percent-encoded), JWTs, `https://user:pass@host`, PEM private-key blocks, and
Google / AWS / GitHub / Slack key formats.

**Opt-in** — personal data, off by default:

```dart
LogScrubber.instance = LogScrubber(
  extraSensitiveKeys: LogScrubber.piiKeys,          // email, phone, iqama, …
  extraValuePatterns: LogScrubber.piiValuePatterns, // email + card shapes
);
```

`creditCardNumber` is loose by design and will also eat long numeric ids and
epoch millis — opt in only when card data can really reach your logs.

## Configuration

| Field | Default | Notes |
|---|---|---|
| `describers` | `[]` | Per-error formatters, first non-null wins |
| `scrubber` | `LogScrubber.instance` | Resolved per call, so assigning the static later still works |
| `collectionEnabled` | `!kDebugMode` | `true` only to test the pipeline itself |
| `catchFlutterErrors` | `true` | `FlutterError.onError`; any existing handler still runs |
| `catchPlatformErrors` | `true` | `PlatformDispatcher.onError` — async gaps, bloc handlers |
| `flutterErrorsAreFatal` | `true` | Matches FlutterFire's own recommendation |
| `shouldReport` | `null` | Drop noise: `(e, _) => e is! SocketException` |
| `logger` | `null` | Where reports go when *not* uploaded, and where internal failures surface |

```dart
await CrashReporter.initialize(
  config: CrashReporterConfig(
    describers: const [describeDioError],
    shouldReport: (error, stack) => error is! SocketException,
    logger: AppLog.e,
  ),
);
```

## API

```dart
CrashReporter.record(error, stack, reason: 'sync failed', fatal: false);
CrashReporter.log('opened vehicle detail');            // breadcrumb
CrashReporter.setCustomKey('screen', 'MapPage');       // sticks to later reports
CrashReporter.setUserIdentifier(user.id);              // opaque id, never an email
CrashReporter.setCollectionEnabled(consented);         // consent prompt / privacy toggle
CrashReporter.recordFlutterError(details);             // from a custom ErrorWidget.builder
```

`setCustomKey` drops the value entirely when the *key* is sensitive
(`api_key`, `authorization`, …) rather than trying to scrub it.

## Making reports readable

Dio's default `toString()` is `DioException [bad response]: null` — the endpoint,
method and status all live on `requestOptions` and none of them survive. A
describer puts them back:

```
DioException: badResponse · GET /api/get_devices · HTTP 401 · Http status error [401]
```

Write your own for any error type whose `toString()` hides what you need:

```dart
CrashDescription? describeCacheError(Object error) {
  if (error is! CacheMissException) return null;
  return CrashDescription('CacheMiss', 'box=${error.box} key=${error.key}');
}
```

⛔ Build the message from the **parts** you want, never from a whole request
object: a URI is a credential, a path is not. The scrub that follows is a second
line of defence, not the first. Response bodies are left out of the Dio describer
for the same reason — they echo back whatever was sent, plus whatever the account
owns.

## Testing the guarantee

`LogScrubber` is pure Dart — no Flutter, no Firebase — so the rules are testable
directly, and `CrashReporter.describe` returns the exact text that would be
uploaded:

```dart
test('a failed request never carries the credential', () {
  final error = DioException(
    requestOptions: RequestOptions(path: '/get_devices?user_api_hash=$2y$10$abc'),
    response: Response(statusCode: 401, requestOptions: RequestOptions(path: '/')),
  );

  final reported = CrashReporter.describe(error);

  expect(reported, contains('/get_devices'));           // still actionable
  expect(reported, isNot(contains(r'$2y$10$')));        // credential gone
  expect(LogScrubber.instance.looksSensitive(reported), isFalse);
});
```

`looksSensitive` is for assertions like this one, not for branching at runtime —
`scrub` is not conditional. It is defined as "scrubbing this would change it",
and `scrub` is idempotent, so already-scrubbed text reads as clean.

## Notes and limits

- **Handlers install once.** Calling `initialize` again swaps the config without
  stacking hooks. Nothing is installed while disabled, deliberately: claiming
  `PlatformDispatcher.onError` and returning `true` marks the error handled and
  stops the default handler printing it, which would make a debug run quieter
  than one with no crash reporting at all.
- **Background isolates** are not covered by `PlatformDispatcher.onError`. In a
  spawned isolate, add `Isolate.current.addErrorListener` and forward to
  `CrashReporter.record`.
- **Reporting never crashes the app.** A failure inside `recordError` — an
  uninitialized Firebase, a plugin missing on this platform — is swallowed and
  sent to `logger`.
- **Keep `redacted` boring.** The default `***` is free of `&`, whitespace,
  quotes and closing brackets. A replacement containing those breaks `scrub`'s
  idempotency and makes `looksSensitive` flag its own output.
- **Grouping still works.** Reports arrive as a stand-in error whose message
  starts with the original type name (`DioException: …`); Crashlytics groups by
  stack trace, so nothing is lost.

## Migrating from an app-specific copy

`LogScrubber` became an instance class so its rules can be configured. The
statics move as follows:

| Before | After |
|---|---|
| `LogScrubber.scrub(text)` | `LogScrubber.instance.scrub(text)` |
| `LogScrubber.looksSensitive(text)` | `LogScrubber.instance.looksSensitive(text)` |
| `LogScrubber.redacted` | `LogScrubber.instance.redacted` |
| hard-coded `user_api_hash` rule | `LogScrubber(extraSensitiveKeys: {'user_api_hash'})` |
| hard-coded `DioException` branch | `describers: [describeDioError]` |
