import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Adds an `Idempotency-Key` header to mutating requests so the server can
/// dedupe duplicate side-effects (double-submits, retries after timeout,
/// offline-queue replays, network races).
///
/// Behavior:
/// - If the caller stashed a key in `options.extra['idempotencyKey']`, that
///   key is used (this is how [ApiCallHandler.handleWrite] preserves the same
///   key across retries and across offline-queue replays).
/// - Otherwise, generates a fresh UUID v4 for any POST/PUT/PATCH/DELETE and
///   stashes it in `extra` so [RetryInterceptor] can reuse it on retry.
/// - GET/HEAD/OPTIONS are skipped (idempotent by definition).
///
/// Combine with server-side dedup: the server keeps a (key → response) cache
/// for ~24h, returns the cached response on collision.
class IdempotencyInterceptor extends Interceptor {
  static const _uuid = Uuid();

  /// Key used in `options.extra` and in the HTTP header.
  static const extraKey = 'idempotencyKey';

  /// HTTP header name. Matches the IETF draft and Stripe/PayPal conventions.
  static const headerName = 'Idempotency-Key';

  /// Methods that need a key.
  static const _mutatingMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method.toUpperCase();
    if (!_mutatingMethods.contains(method)) {
      return handler.next(options);
    }

    // Reuse existing key (set by handleWrite OR replay from queue), else mint.
    final existing = options.extra[extraKey] as String?;
    final key = existing ?? _uuid.v4();
    options.extra[extraKey] = key;
    options.headers[headerName] = key;

    handler.next(options);
  }
}
