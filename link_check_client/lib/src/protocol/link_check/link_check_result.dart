/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class LinkCheckResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  LinkCheckResult._({
    required this.requestedUrl,
    this.finalUrl,
    this.statusCode,
    required this.responseTimeMs,
    required this.isHttps,
    required this.isReachable,
    this.error,
    required this.checkedAt,
  });

  factory LinkCheckResult({
    required String requestedUrl,
    String? finalUrl,
    int? statusCode,
    required int responseTimeMs,
    required bool isHttps,
    required bool isReachable,
    String? error,
    required DateTime checkedAt,
  }) = _LinkCheckResultImpl;

  factory LinkCheckResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return LinkCheckResult(
      requestedUrl: jsonSerialization['requestedUrl'] as String,
      finalUrl: jsonSerialization['finalUrl'] as String?,
      statusCode: jsonSerialization['statusCode'] as int?,
      responseTimeMs: jsonSerialization['responseTimeMs'] as int,
      isHttps: _isc.BoolJsonExtension.fromJson(jsonSerialization['isHttps']),
      isReachable: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['isReachable'],
      ),
      error: jsonSerialization['error'] as String?,
      checkedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['checkedAt'],
      ),
    );
  }

  /// URL submitted by the client.
  String requestedUrl;

  /// Final URL after redirects, when available.
  String? finalUrl;

  /// HTTP status code from the origin, when a response was received.
  int? statusCode;

  /// Round-trip time in milliseconds.
  int responseTimeMs;

  /// Whether the checked URL uses HTTPS (after redirects).
  bool isHttps;

  /// True when an HTTP response with a valid status code was received.
  bool isReachable;

  /// Validation or network error message, when the check did not succeed.
  String? error;

  /// Server timestamp when the check completed.
  DateTime checkedAt;

  /// Returns a shallow copy of this [LinkCheckResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  LinkCheckResult copyWith({
    String? requestedUrl,
    String? finalUrl,
    int? statusCode,
    int? responseTimeMs,
    bool? isHttps,
    bool? isReachable,
    String? error,
    DateTime? checkedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'LinkCheckResult',
      'requestedUrl': requestedUrl,
      if (finalUrl != null) 'finalUrl': finalUrl,
      if (statusCode != null) 'statusCode': statusCode,
      'responseTimeMs': responseTimeMs,
      'isHttps': isHttps,
      'isReachable': isReachable,
      if (error != null) 'error': error,
      'checkedAt': checkedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'LinkCheckResult',
      'requestedUrl': requestedUrl,
      if (finalUrl != null) 'finalUrl': finalUrl,
      if (statusCode != null) 'statusCode': statusCode,
      'responseTimeMs': responseTimeMs,
      'isHttps': isHttps,
      'isReachable': isReachable,
      if (error != null) 'error': error,
      'checkedAt': checkedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _LinkCheckResultImpl extends LinkCheckResult {
  _LinkCheckResultImpl({
    required String requestedUrl,
    String? finalUrl,
    int? statusCode,
    required int responseTimeMs,
    required bool isHttps,
    required bool isReachable,
    String? error,
    required DateTime checkedAt,
  }) : super._(
         requestedUrl: requestedUrl,
         finalUrl: finalUrl,
         statusCode: statusCode,
         responseTimeMs: responseTimeMs,
         isHttps: isHttps,
         isReachable: isReachable,
         error: error,
         checkedAt: checkedAt,
       );

  /// Returns a shallow copy of this [LinkCheckResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  LinkCheckResult copyWith({
    String? requestedUrl,
    Object? finalUrl = _Undefined,
    Object? statusCode = _Undefined,
    int? responseTimeMs,
    bool? isHttps,
    bool? isReachable,
    Object? error = _Undefined,
    DateTime? checkedAt,
  }) {
    return LinkCheckResult(
      requestedUrl: requestedUrl ?? this.requestedUrl,
      finalUrl: finalUrl is String? ? finalUrl : this.finalUrl,
      statusCode: statusCode is int? ? statusCode : this.statusCode,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      isHttps: isHttps ?? this.isHttps,
      isReachable: isReachable ?? this.isReachable,
      error: error is String? ? error : this.error,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}
