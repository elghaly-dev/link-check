/// Tunable limits for the link-check HTTP client and endpoint.
class LinkCheckConfig {
  const LinkCheckConfig._();

  /// Maximum length of the submitted URL string.
  static const int maxUrlLength = 2048;

  /// Wall-clock limit for the entire check (DNS, connect, headers, limited body).
  static const Duration totalTimeout = Duration(seconds: 15);

  /// TCP connect timeout.
  static const Duration connectTimeout = Duration(seconds: 5);

  /// Maximum bytes read from the response body (HEAD may still return a body).
  static const int maxResponseBytes = 64 * 1024;

  /// Maximum redirects followed after re-validating each target URL.
  static const int maxRedirects = 3;

  /// Per-client rate limit (identified by [Session.request.remoteInfo]).
  static const int rateLimitMaxRequests = 20;

  static const Duration rateLimitWindow = Duration(minutes: 1);

  static const String userAgent = 'link-check-serverpod/1.0 (+https://github.com/elghaly-dev/link-check)';
}
