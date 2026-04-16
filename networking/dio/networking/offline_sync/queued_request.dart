import 'dart:convert';

/// Represents a queued offline request that will be replayed
/// when connectivity is restored.
///
/// Stored as JSON in Hive — no code generation required.
class QueuedRequest {
  /// Unique identifier (UUID).
  final String id;

  /// HTTP method (POST, PUT, DELETE, PATCH).
  final String method;

  /// Request path (e.g., `/api/tasks`).
  final String path;

  /// Base URL (e.g., `https://api.example.com`).
  final String? baseUrl;

  /// Request body data (must be JSON-serializable).
  final Map<String, dynamic>? data;

  /// Query parameters.
  final Map<String, dynamic>? queryParameters;

  /// Request headers.
  final Map<String, String>? headers;

  /// When the request was queued.
  final DateTime createdAt;

  /// Current number of retry attempts.
  final int retryCount;

  /// Maximum allowed retry attempts.
  final int maxRetries;

  const QueuedRequest({
    required this.id,
    required this.method,
    required this.path,
    this.baseUrl,
    this.data,
    this.queryParameters,
    this.headers,
    required this.createdAt,
    this.retryCount = 0,
    this.maxRetries = 5,
  });

  /// Creates a copy with an incremented retry count.
  QueuedRequest incrementedRetry() {
    return QueuedRequest(
      id: id,
      method: method,
      path: path,
      baseUrl: baseUrl,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      createdAt: createdAt,
      retryCount: retryCount + 1,
      maxRetries: maxRetries,
    );
  }

  /// Whether this request has exceeded its max retries.
  bool get isExpired => retryCount >= maxRetries;

  /// Serializes to a JSON-compatible map for Hive storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'path': path,
      'baseUrl': baseUrl,
      'data': data,
      'queryParameters': queryParameters,
      'headers': headers,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'maxRetries': maxRetries,
    };
  }

  /// Deserializes from a JSON map (from Hive storage).
  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      baseUrl: json['baseUrl'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      queryParameters: json['queryParameters'] != null
          ? Map<String, dynamic>.from(json['queryParameters'] as Map)
          : null,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 5,
    );
  }

  /// Serializes to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from a JSON string.
  factory QueuedRequest.fromJsonString(String jsonString) {
    return QueuedRequest.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  @override
  String toString() =>
      'PendingRequest(id: $id, method: $method, path: $path, '
      'retryCount: $retryCount/$maxRetries, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedRequest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
