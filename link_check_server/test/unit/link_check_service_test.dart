import 'dart:async';
import 'dart:io';

import 'package:link_check_server/src/link_check/link_check_security.dart';
import 'package:link_check_server/src/link_check/link_check_service.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Offline fakes: no sockets are opened, no DNS is queried.
// ---------------------------------------------------------------------------

class _FakeHeaders implements HttpHeaders {
  _FakeHeaders([Map<String, String> values = const {}])
    : _values = {for (final e in values.entries) e.key.toLowerCase(): e.value};

  final Map<String, String> _values;
  final List<String> setNames = [];

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    setNames.add(name.toLowerCase());
    _values[name.toLowerCase()] = '$value';
  }

  @override
  String? value(String name) => _values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this._status, [Map<String, String> headers = const {}])
    : _headers = _FakeHeaders(headers);

  final int _status;
  final _FakeHeaders _headers;

  @override
  int get statusCode => _status;

  @override
  HttpHeaders get headers => _headers;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this._response);

  final HttpClientResponse _response;
  final _FakeHeaders requestHeaders = _FakeHeaders();
  bool? followRedirectsValue;

  @override
  HttpHeaders get headers => requestHeaders;

  @override
  set followRedirects(bool value) => followRedirectsValue = value;

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Responder = HttpClientResponse Function(Uri uri);

/// Stand-in for [HttpClient]. When [useConnectionFactory] is true it calls the
/// service's `connectionFactory` for every request, exactly like the real
/// client does before any bytes are sent.
class _FakeClient implements HttpClient {
  _FakeClient(this.responder, {this.connectWhen});

  final _Responder responder;
  final bool Function(Uri uri)? connectWhen;
  final List<Uri> requested = [];
  final List<_FakeRequest> requests = [];
  Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? _factory;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? f,
  ) => _factory = f;

  @override
  set connectionTimeout(Duration? value) {}

  @override
  set autoUncompress(bool value) {}

  Future<HttpClientRequest> _open(Uri uri) async {
    requested.add(uri);
    if (connectWhen?.call(uri) ?? false) {
      await _factory!(uri, null, null);
    }
    final request = _FakeRequest(responder(uri));
    requests.add(request);
    return request;
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _open(url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HttpClientResponse _redirect(String location) =>
    _FakeResponse(302, {'location': location});

LinkCheckSecurity _securityWith(Map<String, List<String>> dns) =>
    LinkCheckSecurity(
      lookup: (host) async {
        final answer = dns[host];
        if (answer == null) {
          throw const SocketException('no such host');
        }
        return answer.map(InternetAddress.new).toList();
      },
    );

void main() {
  group('LinkCheckService', () {
    test(
      'returns validation error without opening network for file URLs',
      () async {
        final service = LinkCheckService(
          httpClientFactory: () => throw StateError('HTTP should not be used'),
        );

        final result = await service.check('file:///etc/passwd');
        expect(result.error, isNotNull);
        expect(result.isReachable, isFalse);
        expect(result.redirectHops, 0);
      },
    );

    test(
      'returns validation error for disallowed ports without HTTP',
      () async {
        final service = LinkCheckService(
          httpClientFactory: () => throw StateError('HTTP should not be used'),
        );

        final result = await service.check('http://example.com:8080/');
        expect(result.error, 'Use port 80 or 443.');
        expect(result.redirectHops, 0);
      },
    );
  });

  group('LinkCheckService — redirects re-checked on every hop (SSRF #5)', () {
    test(
      'redirect to a private IP literal is rejected and never requested',
      () async {
        final client = _FakeClient(
          (uri) => _redirect('http://192.168.0.10/admin'),
        );
        final service = LinkCheckService(httpClientFactory: () => client);

        final result = await service.check('http://1.1.1.1/start');

        expect(result.isReachable, isFalse);
        expect(result.error, 'Target address is not allowed.');
        expect(client.requested.map((u) => u.host), ['1.1.1.1']);
      },
    );

    test('redirect to the cloud metadata address is rejected', () async {
      final client = _FakeClient(
        (uri) => _redirect('http://169.254.169.254/latest/meta-data'),
      );
      final service = LinkCheckService(httpClientFactory: () => client);

      final result = await service.check('http://1.1.1.1/');

      expect(result.error, 'Target address is not allowed.');
      expect(client.requested, hasLength(1));
    });

    test(
      'redirect to a hostname that resolves to a private IP is rejected',
      () async {
        final client = _FakeClient((uri) => _redirect('https://rebind.test/x'));
        final service = LinkCheckService(
          security: _securityWith({
            'rebind.test': ['10.9.8.7'],
          }),
          httpClientFactory: () => client,
        );

        final result = await service.check('http://1.1.1.1/');

        expect(result.error, 'Target resolves to a disallowed address.');
        expect(client.requested, hasLength(1));
      },
    );

    test('redirect to a disallowed port or scheme is rejected', () async {
      for (final location in [
        'http://8.8.8.8:8080/',
        'ftp://8.8.8.8/',
        'file:///etc/passwd',
      ]) {
        final client = _FakeClient((uri) => _redirect(location));
        final service = LinkCheckService(httpClientFactory: () => client);

        final result = await service.check('http://1.1.1.1/');

        expect(result.isReachable, isFalse, reason: location);
        expect(client.requested, hasLength(1), reason: location);
      }
    });

    test('relative redirects are followed and re-validated', () async {
      final client = _FakeClient(
        (uri) => uri.path == '/start' ? _redirect('/next') : _FakeResponse(200),
      );
      final service = LinkCheckService(httpClientFactory: () => client);

      final result = await service.check('http://1.1.1.1/start');

      expect(result.isReachable, isTrue);
      expect(result.redirectHops, 1);
      expect(result.finalUrl, 'http://1.1.1.1/next');
    });

    test('follows exactly 5 redirects, then succeeds', () async {
      final client = _FakeClient(
        (uri) => uri.path.length < 6
            ? _redirect('${uri.path}x')
            : _FakeResponse(200),
      );
      final service = LinkCheckService(httpClientFactory: () => client);

      final result = await service.check('http://1.1.1.1/');

      expect(result.isReachable, isTrue);
      expect(result.redirectHops, 5);
      expect(client.requested, hasLength(6));
    });

    test('stops with "Too many redirects." after 5 hops', () async {
      final client = _FakeClient(
        (uri) => _redirect(
          uri.host == '1.1.1.1' ? 'http://8.8.8.8/' : 'http://1.1.1.1/',
        ),
      );
      final service = LinkCheckService(httpClientFactory: () => client);

      final result = await service.check('http://1.1.1.1/');

      expect(result.isReachable, isFalse);
      expect(result.error, 'Too many redirects.');
      expect(result.redirectHops, 5);
      expect(client.requested, hasLength(6), reason: '1 request + 5 redirects');
    });

    test('redirects are never auto-followed by the HTTP client', () async {
      final client = _FakeClient((uri) => _FakeResponse(200));
      final service = LinkCheckService(httpClientFactory: () => client);

      await service.check('http://1.1.1.1/');

      expect(client.requests.single.followRedirectsValue, isFalse);
    });
  });

  group('LinkCheckService — DNS pinning (SSRF #4)', () {
    test(
      'connects to the checked public IP, not to a blocked sibling',
      () async {
        final connected = <String>[];
        final client = _FakeClient(
          (uri) => _FakeResponse(200),
          connectWhen: (_) => true,
        );
        final service = LinkCheckService(
          security: _securityWith({
            'pin.test': ['10.0.0.7', '93.184.216.34'],
          }),
          httpClientFactory: () => client,
          socketConnector: (address, port) async {
            connected.add('${address.address}:$port');
            throw const SocketException('stop before any real network use');
          },
        );

        final result = await service.check('https://pin.test/');

        expect(connected, ['93.184.216.34:443']);
        expect(result.error, 'Could not connect to host.');
      },
    );

    test(
      'a host that rebinds to a private IP before connect is rejected, no socket opened',
      () async {
        var lookups = 0;
        final connected = <String>[];
        final client = _FakeClient(
          (uri) => _FakeResponse(200),
          connectWhen: (_) => true,
        );
        final service = LinkCheckService(
          security: LinkCheckSecurity(
            lookup: (host) async {
              lookups++;
              return [
                InternetAddress(lookups == 1 ? '93.184.216.34' : '10.0.0.7'),
              ];
            },
          ),
          httpClientFactory: () => client,
          socketConnector: (address, port) async {
            connected.add(address.address);
            throw const SocketException('unexpected');
          },
        );

        final result = await service.check('http://rebind.test/');

        expect(lookups, 2, reason: 'pre-check lookup + one lookup for the hop');
        expect(connected, isEmpty);
        expect(client.requested, isEmpty);
        expect(result.error, 'Target resolves to a disallowed address.');
      },
    );

    test(
      'a redirect hop is resolved again and pinned to its own checked IP',
      () async {
        final connected = <String>[];
        final client = _FakeClient(
          (uri) => _redirect('http://second.test/'),
          // Only the second hop reaches the (fake) socket layer.
          connectWhen: (uri) => uri.host == 'second.test',
        );
        final service = LinkCheckService(
          security: _securityWith({
            'first.test': ['93.184.216.34'],
            'second.test': ['10.1.1.1', '8.8.4.4'],
          }),
          httpClientFactory: () => client,
          socketConnector: (address, port) async {
            connected.add('${address.address}:$port');
            throw const SocketException('stop before any real network use');
          },
        );

        final result = await service.check('http://first.test/');

        expect(client.requested.map((u) => u.host), [
          'first.test',
          'second.test',
        ]);
        expect(connected, ['8.8.4.4:80']);
        expect(result.error, 'Could not connect to host.');
      },
    );
  });

  group('LinkCheckService — headers and error text (SSRF #7)', () {
    test('only User-Agent is set on the outbound request', () async {
      final client = _FakeClient((uri) => _FakeResponse(200));
      final service = LinkCheckService(httpClientFactory: () => client);

      final result = await service.check('http://1.1.1.1/');

      expect(result.isReachable, isTrue);
      final headers = client.requests.single.requestHeaders;
      expect(headers.setNames, ['user-agent']);
      expect(headers.value('cookie'), isNull);
      expect(headers.value('authorization'), isNull);
    });

    test(
      'errors never contain internal IPs, cookies, or upstream text',
      () async {
        const secrets = ['10.0.0.5', '192.168.1.9', 'sid=abc123', 'Bearer'];
        final failures = <Object>[
          HttpException('boom 10.0.0.5 Cookie: sid=abc123'),
          SocketException(
            'Connection refused',
            address: InternetAddress('192.168.1.9'),
          ),
          HandshakeException('cert for 10.0.0.5 Bearer token'),
        ];
        for (final failure in failures) {
          final client = _FakeClient((uri) => throw failure);
          final service = LinkCheckService(httpClientFactory: () => client);

          final result = await service.check('http://1.1.1.1/');

          expect(result.isReachable, isFalse);
          final error = result.error ?? '';
          expect(error, isNotEmpty);
          for (final secret in secrets) {
            expect(
              error,
              isNot(contains(secret)),
              reason: '$failure -> $error',
            );
          }
        }
      },
    );

    test(
      'validation errors for internal targets do not echo the address',
      () async {
        final service = LinkCheckService(
          httpClientFactory: () => throw StateError('HTTP should not be used'),
        );
        for (final url in [
          'http://10.20.30.40/',
          'http://192.168.77.88/',
          'http://[fc00::1234]/',
          'http://172.16.99.99/',
        ]) {
          final result = await service.check(url);
          expect(result.isReachable, isFalse, reason: url);
          final error = result.error ?? '';
          expect(error, isNotEmpty, reason: url);
          for (final fragment in [
            '10.20.30.40',
            '192.168.77.88',
            'fc00',
            '172.16.99.99',
          ]) {
            expect(error, isNot(contains(fragment)), reason: '$url -> $error');
          }
        }
      },
    );
  });
}
