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
    required this.redirectHops,
    this.finalUrl,
    this.statusCode,
    this.isReachable = false,
    this.error,
  });

  final String requestedUrl;
  final String? finalUrl;
  final int redirectHops;
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
    Future<ConnectionTask<Socket>> Function(InternetAddress address, int port)?
    socketConnector,
  }) : _security = security ?? const LinkCheckSecurity(),
       _httpClientFactory = httpClientFactory ?? (() => HttpClient()),
       _socketConnector = socketConnector ?? Socket.startConnect;

  final LinkCheckSecurity _security;
  final HttpClient Function() _httpClientFactory;
  final Future<ConnectionTask<Socket>> Function(
    InternetAddress address,
    int port,
  )
  _socketConnector;

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
        redirectHops: 0,
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
        redirectHops: 0,
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
          redirectHops: 0,
          error: 'Request timed out.',
        ),
      );
    } on LinkCheckSecurityException catch (e) {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        redirectHops: 0,
        error: e.message,
      );
    } on SocketException {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        redirectHops: 0,
        error: 'Could not connect to host.',
      );
    } on HandshakeException {
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        redirectHops: 0,
        error: 'TLS handshake failed.',
      );
    } on HttpException {
      // Never forward the upstream/library message: it can echo URLs or hosts.
      return LinkCheckProbeResult(
        requestedUrl: uri.toString(),
        isHttps: uri.scheme == 'https',
        responseTimeMs: DateTime.now().difference(started).inMilliseconds,
        checkedAt: started,
        redirectHops: 0,
        error: 'The request failed.',
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
    var redirectHops = 0;

    for (var hop = 0; hop <= LinkCheckConfig.maxRedirects; hop++) {
      current = _security.validateRequestUrl(current.toString());
      final connectAddress = await _security.resolveConnectAddress(current);

      response = await _sendRequest(client, current, connectAddress);
      final status = response.statusCode;

      if (_isRedirect(status)) {
        if (hop >= LinkCheckConfig.maxRedirects) {
          await _drainLimited(response);
          return LinkCheckProbeResult(
            requestedUrl: initialUri.toString(),
            finalUrl: current.toString(),
            redirectHops: redirectHops,
            statusCode: status,
            isHttps: current.scheme == 'https',
            responseTimeMs: DateTime.now().difference(started).inMilliseconds,
            checkedAt: started,
            isReachable: false,
            error: 'Too many redirects.',
          );
        }

        final location = response.headers.value(HttpHeaders.locationHeader);
        await _drainLimited(response);
        if (location == null || location.isEmpty) {
          break;
        }
        current = current.resolve(location);
        redirectHops++;
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
      redirectHops: redirectHops,
      statusCode: statusCode,
      isHttps: current.scheme == 'https',
      responseTimeMs: elapsed,
      checkedAt: started,
      isReachable: reachable,
    );
  }

  Future<HttpClientResponse> _sendRequest(
    HttpClient client,
    Uri uri,
    InternetAddress connectAddress,
  ) async {
    client.connectionFactory = (url, proxyHost, proxyPort) {
      final port = url.hasPort ? url.port : (url.scheme == 'https' ? 443 : 80);
      return _socketConnector(connectAddress, port);
    };

    HttpClientRequest request;
    try {
      request = await client.headUrl(uri);
    } on HttpException {
      request = await client.getUrl(uri);
    }
    request.headers.set(HttpHeaders.userAgentHeader, LinkCheckConfig.userAgent);
    request.followRedirects = false;
    try {
      return await request.close();
    } on HttpException {
      final getRequest = await client.getUrl(uri);
      getRequest.headers.set(
        HttpHeaders.userAgentHeader,
        LinkCheckConfig.userAgent,
      );
      getRequest.followRedirects = false;
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
