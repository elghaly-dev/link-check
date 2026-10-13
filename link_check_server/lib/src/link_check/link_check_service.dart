import 'dart:async';
import 'dart:io';

import 'link_check_config.dart';
import 'link_check_security.dart';

/// Result of an outbound link check (before mapping to protocol types).
class LinkCheckProbeResult {
  LinkCheckProbeResult({
    required this.requestedUrl,
    required this.isHttps,
    required this.responseTimeMs,
    required this.checkedAt,
    this.finalUrl,
    this.statusCode,
    this.isReachable = false,
    this.error,
  });

  final String requestedUrl;
  final String? finalUrl;
  final int? statusCode;
  final int responseTimeMs;
  final bool isHttps;
  final bool isReachable;
  final String? error;
  final DateTime checkedAt;
}

/// Performs timed, size-limited HTTP(S) probes with SSRF safeguards.
class LinkCheckService {
  LinkCheckService({
    LinkCheckSecurity? security,
    HttpClient Function()? httpClientFactory,
  }) : _security = security ?? const LinkCheckSecurity(),
       _httpClientFactory = httpClientFactory ?? (() => HttpClient());

  final LinkCheckSecurity _security;
  final HttpClient Function() _httpClientFactory;

  Future<LinkCheckProbeResult> check(String rawUrl) async {
    final started = DateTime.now();
    Uri uri;
    try {
      uri = _security.validateRequestUrl(rawUrl);
    } on LinkCheckSecurityException catch (e) {
      return LinkCheckProbeResult(
        requestedUrl: rawUrl.trim(),
        isHttps: false,
        responseTimeMs: 0,
        checkedAt: started,
        error: e.message,
      );
    }

    try {
      await _security.assertResolvableHostIsPublic(uri);
    } on LinkCheckSecurityException catch (e) {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        error: e.message,
      );
    }

    final client = _httpClientFactory()
      ..connectionTimeout = LinkCheckConfig.connectTimeout
      ..autoUncompress = true;

    try {
      return await _fetchWithRedirects(
        client: client,
        initialUri: uri,
        started: started,
      ).timeout(
        LinkCheckConfig.totalTimeout,
        onTimeout: () => LinkCheckProbeResult(
          requestedUrl: uri.toString(),
          isHttps: uri.scheme == 'https',
          responseTimeMs: DateTime.now().difference(started).inMilliseconds,
          checkedAt: started,
          error: 'Request timed out.',
        ),
      );
    } on LinkCheckSecurityException catch (e) {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        error: e.message,
      );
    } on SocketException {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        error: 'Could not connect to host.',
      );
    } on HandshakeException {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        error: 'TLS handshake failed.',
      );
    } on HttpException catch (e) {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        error: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<LinkCheckProbeResult> _fetchWithRedirects({
    required HttpClient client,
    required Uri initialUri,
    required DateTime started,
  }) async {
    var current = initialUri;
    HttpClientResponse? response;

    for (var hop = 0; hop <= LinkCheckConfig.maxRedirects; hop++) {
      _security.validateRequestUrl(current.toString());
      await _security.assertResolvableHostIsPublic(current);

      response = await _sendRequest(client, current);
      final status = response.statusCode;

      if (_isRedirect(status) && hop < LinkCheckConfig.maxRedirects) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await _drainLimited(response);
        if (location == null || location.isEmpty) {
          break;
        }
        final next = current.resolve(location);
        current = next;
        continue;
      }

      await _drainLimited(response);
      break;
    }

    final statusCode = response?.statusCode;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    final reachable = statusCode != null && statusCode > 0 && statusCode < 600;

    return LinkCheckProbeResult(
      requestedUrl: initialUri.toString(),
      finalUrl: current.toString(),
      statusCode: statusCode,
      isHttps: current.scheme == 'https',
      responseTimeMs: elapsed,
      checkedAt: started,
      isReachable: reachable,
    );
  }

  Future<HttpClientResponse> _sendRequest(HttpClient client, Uri uri) async {
    HttpClientRequest request;
    try {
      request = await client.headUrl(uri);
    } on HttpException {
      request = await client.getUrl(uri);
    }
    request.headers.set(HttpHeaders.userAgentHeader, LinkCheckConfig.userAgent);
    try {
      return await request.close();
    } on HttpException {
      final getRequest = await client.getUrl(uri);
      getRequest.headers.set(
        HttpHeaders.userAgentHeader,
        LinkCheckConfig.userAgent,
      );
      return getRequest.close();
    }
  }

  bool _isRedirect(int status) =>
      status == HttpStatus.movedPermanently ||
      status == HttpStatus.found ||
      status == HttpStatus.seeOther ||
      status == HttpStatus.temporaryRedirect ||
      status == HttpStatus.permanentRedirect;

  Future<void> _drainLimited(HttpClientResponse response) async {
    var read = 0;
    await for (final chunk in response) {
      read += chunk.length;
      if (read >= LinkCheckConfig.maxResponseBytes) {
        break;
      }
    }
  }
}
