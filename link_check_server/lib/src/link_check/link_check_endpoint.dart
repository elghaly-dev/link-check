import '../generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'link_check_rate_limiter.dart';
import 'link_check_service.dart';

/// Server-side link checker with SSRF protections, timeouts, and rate limits.
class LinkCheckEndpoint extends Endpoint {
  LinkCheckEndpoint({
    LinkCheckService? service,
    LinkCheckRateLimiter? rateLimiter,
  }) : _service = service ?? LinkCheckService(),
       _rateLimiter = rateLimiter ?? LinkCheckRateLimiter();

  final LinkCheckService _service;
  final LinkCheckRateLimiter _rateLimiter;

  /// Checks [url] and returns status, timing, and HTTPS information.
  Future<LinkCheckResult> check(Session session, String url) async {
    final clientKey = _clientKey(session);
    if (!_rateLimiter.tryAcquire(clientKey)) {
      return LinkCheckResult(
        requestedUrl: url.trim(),
        finalUrl: null,
        redirectHops: 0,
        statusCode: null,
        responseTimeMs: 0,
        isHttps: false,
        isReachable: false,
        error: 'Rate limit exceeded. Try again later.',
        checkedAt: DateTime.now(),
      );
    }

    final probe = await _service.check(url);
    return LinkCheckResult(
      requestedUrl: probe.requestedUrl,
      finalUrl: probe.finalUrl,
      redirectHops: probe.redirectHops,
      statusCode: probe.statusCode,
      responseTimeMs: probe.responseTimeMs,
      isHttps: probe.isHttps,
      isReachable: probe.isReachable,
      error: probe.error,
      checkedAt: probe.checkedAt,
    );
  }

  String _clientKey(Session session) {
    final request = session.request;
    if (request != null) {
      return request.remoteInfo;
    }
    return session.sessionId.toString();
  }
}
