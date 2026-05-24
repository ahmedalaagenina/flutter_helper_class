import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Dio interceptor that prevents duplicate in-flight mutating requests.
///
/// Tracks active requests by a canonical signature derived from
/// method + full URI + serialized payload. If an identical request
/// fires while the original is still in-flight, the duplicate is
/// immediately rejected with [DioExceptionType.cancel] and a sentinel
/// message that downstream layers can identify and silently drop.
class DuplicateRequestInterceptor extends Interceptor {
  /// Registry of signatures for requests currently in-flight.
  final Set<String> _inFlightRequests = {};

  /// Key used to stash the computed signature in [RequestOptions.extra]
  /// so it can be retrieved on response/error for cleanup.
  static const _signatureKey = '_dup_req_signature';

  /// Sentinel message used to identify rejected duplicate requests.
  static const duplicateMessage = 'DUPLICATE_REQUEST_IGNORED';

  /// Methods that are safe to repeat — never intercepted.
  static const _safeMethods = {'GET', 'HEAD', 'OPTIONS'};

  // ──────────────────────────────────────────────────────────────────────
  // Interceptor overrides
  // ──────────────────────────────────────────────────────────────────────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Safe methods are idempotent — always allow through.
    if (_safeMethods.contains(options.method.toUpperCase())) {
      return handler.next(options);
    }

    // FormData (file uploads) cannot be reliably serialized.
    if (options.data is FormData) {
      return handler.next(options);
    }

    final signature = _generateSignature(options);

    if (_inFlightRequests.contains(signature)) {
      // Duplicate detected — reject immediately.
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: duplicateMessage,
        ),
      );
    }

    // First occurrence — register and proceed.
    _inFlightRequests.add(signature);
    options.extra[_signatureKey] = signature;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _removeSignature(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If this is our own rejection, do NOT remove anything — no signature
    // was ever added for this rejected request.
    if (err.message == duplicateMessage) {
      return handler.next(err);
    }

    _removeSignature(err.requestOptions);
    handler.next(err);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Signature helpers
  // ──────────────────────────────────────────────────────────────────────

  /// Removes the stashed signature from the in-flight registry.
  void _removeSignature(RequestOptions options) {
    final signature = options.extra[_signatureKey] as String?;
    if (signature != null) {
      _inFlightRequests.remove(signature);
    }
  }

  /// Builds a deterministic string key from method, full URI, and payload.
  String _generateSignature(RequestOptions options) {
    final method = options.method.toUpperCase();
    final uri = options.uri.toString();
    final payload = _serializePayload(options.data);
    return '$method:$uri:$payload';
  }

  /// Serialises the request payload into a stable, order-independent string.
  String _serializePayload(dynamic data) {
    try {
      if (data == null) return '';

      if (data is Map<String, dynamic>) {
        return jsonEncode(_canonicalizeMap(data));
      }

      if (data is List) {
        return jsonEncode(_canonicalizeList(data));
      }

      if (data is String) {
        // Attempt to decode JSON strings so key order doesn't matter.
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            return jsonEncode(_canonicalizeMap(decoded));
          }
          if (decoded is List) {
            return jsonEncode(_canonicalizeList(decoded));
          }
        } catch (_) {
          // Not JSON — use as-is.
        }
        return data;
      }

      return data.toString();
    } catch (_) {
      return data.toString();
    }
  }

  /// Returns a [SplayTreeMap] with alphabetically sorted keys.
  /// Nested maps and lists are canonicalized recursively.
  Map<String, dynamic> _canonicalizeMap(Map<String, dynamic> map) {
    final sorted = SplayTreeMap<String, dynamic>();
    for (final entry in map.entries) {
      sorted[entry.key] = _canonicalizeValue(entry.value);
    }
    return sorted;
  }

  /// Recursively canonicalizes a single value.
  dynamic _canonicalizeValue(dynamic value) {
    if (value is Map<String, dynamic>) return _canonicalizeMap(value);
    if (value is List) return _canonicalizeList(value);
    return value;
  }

  /// Canonicalizes each element of a list recursively.
  List<dynamic> _canonicalizeList(List<dynamic> list) {
    return list.map(_canonicalizeValue).toList();
  }
}
