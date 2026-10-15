import 'dart:io';

import 'package:link_check_server/src/link_check/link_check_config.dart';
import 'package:link_check_server/src/link_check/link_check_rate_limiter.dart';
import 'package:link_check_server/src/link_check/link_check_security.dart';
import 'package:test/test.dart';

void main() {
  group('LinkCheckSecurity — scheme and credentials (SSRF #1)', () {
    const security = LinkCheckSecurity();

    test('allows public https URLs', () {
      final uri = security.validateRequestUrl('https://example.com/path');
      expect(uri.host, 'example.com');
      expect(uri.scheme, 'https');
    });

    test('rejects missing scheme', () {
      expect(
        () => security.validateRequestUrl('example.com'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects file scheme', () {
      expect(
        () => security.validateRequestUrl('file:///etc/passwd'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects gopher scheme', () {
      expect(
        () => security.validateRequestUrl('gopher://example.com'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects ftp scheme', () {
      expect(
        () => security.validateRequestUrl('ftp://example.com'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects data scheme', () {
      expect(
        () => security.validateRequestUrl('data:text/plain,hello'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects javascript scheme', () {
      expect(
        () => security.validateRequestUrl('javascript:alert(1)'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects embedded credentials', () {
      expect(
        () => security.validateRequestUrl('http://user:pass@example.com'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });
  });

  group('LinkCheckSecurity — blocked networks (SSRF #2)', () {
    const security = LinkCheckSecurity();

    test('rejects localhost hostnames', () {
      expect(
        () => security.validateRequestUrl('http://localhost:8080'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects loopback IPv4 literals', () {
      expect(
        () => security.validateRequestUrl('http://127.0.0.1/'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects cloud metadata address', () {
      expect(
        () => security.validateRequestUrl(
          'http://169.254.169.254/latest/meta-data',
        ),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('blocks private IPv4 addresses', () {
      expect(security.isBlockedAddress(InternetAddress('10.0.0.1')), isTrue);
      expect(security.isBlockedAddress(InternetAddress('192.168.1.1')), isTrue);
      expect(security.isBlockedAddress(InternetAddress('8.8.8.8')), isFalse);
    });

    test('blocks IPv6 loopback', () {
      expect(security.isBlockedAddress(InternetAddress('::1')), isTrue);
    });

    test('blocks every range listed in SECURITY.md row 2 (edges included)', () {
      const blocked = [
        '127.0.0.1', '127.255.255.254', // 127/8
        '10.0.0.0', '10.255.255.255', // 10/8
        '172.16.0.1', '172.31.255.255', // 172.16/12
        '192.168.0.1', '192.168.255.255', // 192.168/16
        '169.254.0.1', '169.254.169.254', // 169.254/16
        '100.64.0.1', '100.127.255.255', // 100.64/10
        '0.0.0.0', '0.1.2.3', // 0/8
        'fc00::1', 'fdff:ffff::1', // fc00::/7
        'fe80::1', 'febf::1', // fe80::/10
        '::1', // loopback
        '::ffff:10.0.0.1', '::ffff:192.168.1.1', '::ffff:100.64.0.1', // mapped
      ];
      for (final ip in blocked) {
        expect(
          security.isBlockedAddress(InternetAddress(ip)),
          isTrue,
          reason: '$ip should be blocked',
        );
      }
    });

    test('does not block public neighbours just outside blocked ranges', () {
      const allowed = [
        '172.15.255.255', '172.32.0.1', // outside 172.16/12
        '192.167.255.255', '192.169.0.1', // outside 192.168/16
        '100.63.255.255', '100.128.0.1', // outside 100.64/10
        '169.253.255.255', '169.255.0.1', // outside 169.254/16
        '11.0.0.1', '9.255.255.255', // outside 10/8
        '1.1.1.1', '8.8.8.8',
        '2606:4700:4700::1111', // public IPv6
        'fbff::1', 'fe00::1', // outside fc00::/7 and fe80::/10
        '::ffff:8.8.8.8', // mapped public
      ];
      for (final ip in allowed) {
        expect(
          security.isBlockedAddress(InternetAddress(ip)),
          isFalse,
          reason: '$ip should be allowed',
        );
      }
    });

    test('rejects blocked IP literals in URLs, including IPv6', () {
      for (final url in [
        'http://172.16.5.5/',
        'http://100.64.0.1/',
        'http://[fc00::1]/',
        'http://[fe80::1]/',
        'http://[::ffff:10.0.0.1]/',
        'http://192.168.0.10/',
        'http://10.1.2.3/',
      ]) {
        expect(
          () => security.validateRequestUrl(url),
          throwsA(isA<LinkCheckSecurityException>()),
          reason: url,
        );
      }
    });

    test('blocks IPv4-mapped loopback', () {
      expect(
        security.isBlockedAddress(InternetAddress('::ffff:127.0.0.1')),
        isTrue,
      );
    });
  });

  group('LinkCheckSecurity — DNS pinning (SSRF #4)', () {
    const security = LinkCheckSecurity();

    test('resolveConnectAddress accepts public IPv4 literals', () async {
      final address = await security.resolveConnectAddress(
        Uri.parse('https://1.1.1.1/'),
      );
      expect(address.address, '1.1.1.1');
    });

    test(
      'hostname resolves via lookup and returns the first public address',
      () async {
        var calls = 0;
        final pinned = LinkCheckSecurity(
          lookup: (host) async {
            calls++;
            expect(host, 'pin.example.test');
            return [
              InternetAddress('10.0.0.7'),
              InternetAddress('93.184.216.34'),
              InternetAddress('1.1.1.1'),
            ];
          },
        );
        final address = await pinned.resolveConnectAddress(
          Uri.parse('https://pin.example.test/'),
        );
        expect(address.address, '93.184.216.34');
        expect(calls, 1, reason: 'one lookup per resolveConnectAddress call');
      },
    );

    test('hostname resolving only to blocked addresses is rejected', () async {
      final pinned = LinkCheckSecurity(
        lookup: (_) async => [
          InternetAddress('127.0.0.1'),
          InternetAddress('fc00::5'),
          InternetAddress('::ffff:192.168.0.1'),
        ],
      );
      await expectLater(
        pinned.resolveConnectAddress(Uri.parse('http://rebind.example.test/')),
        throwsA(
          isA<LinkCheckSecurityException>().having(
            (e) => e.message,
            'message',
            allOf(isNot(contains('127.0.0.1')), isNot(contains('192.168'))),
          ),
        ),
      );
    });

    test('empty DNS answer is rejected', () async {
      final pinned = LinkCheckSecurity(lookup: (_) async => []);
      await expectLater(
        pinned.resolveConnectAddress(Uri.parse('http://empty.example.test/')),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });
  });

  group('LinkCheckSecurity — host normalization (SSRF #3)', () {
    const security = LinkCheckSecurity();

    test('strips trailing dot from hostnames', () {
      final uri = security.validateRequestUrl('https://example.com./');
      expect(uri.host, 'example.com');
    });

    test('rejects decimal-encoded loopback IPv4', () {
      expect(
        () => security.validateRequestUrl('http://2130706433/'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects octal-encoded loopback IPv4', () {
      expect(
        () => security.validateRequestUrl('http://0177.0.0.1/'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects hex-encoded loopback IPv4', () {
      expect(
        () => security.validateRequestUrl('http://0x7f.0.0.1/'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('accepts punycode hostname form', () {
      final uri = security.validateRequestUrl('https://xn--fiqs8s.icu/');
      expect(uri.host, 'xn--fiqs8s.icu');
    });
  });

  group('LinkCheckSecurity — ports and limits (SSRF #6)', () {
    const security = LinkCheckSecurity();

    test('uses the reworded, UI-safe validation messages', () {
      expect(
        () => security.validateRequestUrl('ftp://example.com'),
        throwsA(
          isA<LinkCheckSecurityException>().having(
            (e) => e.message,
            'message',
            'Use an http or https URL.',
          ),
        ),
      );
      expect(
        () => security.validateRequestUrl('http://example.com:8080/'),
        throwsA(
          isA<LinkCheckSecurityException>().having(
            (e) => e.message,
            'message',
            'Use port 80 or 443.',
          ),
        ),
      );
    });

    test('rejects non-standard ports', () {
      expect(
        () => security.validateRequestUrl('http://example.com:8080/'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('allows implicit https port', () {
      final uri = security.validateRequestUrl('https://example.com/');
      expect(uri.scheme, 'https');
    });

    test('config uses required timeouts and body cap', () {
      expect(LinkCheckConfig.connectTimeout, const Duration(seconds: 3));
      expect(LinkCheckConfig.totalTimeout, const Duration(seconds: 10));
      expect(LinkCheckConfig.maxResponseBytes, 1024 * 1024);
      expect(LinkCheckConfig.maxRedirects, 5);
    });
  });

  group('LinkCheckRateLimiter (SSRF #7)', () {
    test('allows requests under the limit', () {
      final limiter = LinkCheckRateLimiter(
        maxRequests: 2,
        window: const Duration(minutes: 1),
      );
      expect(limiter.tryAcquire('client-a'), isTrue);
      expect(limiter.tryAcquire('client-a'), isTrue);
      expect(limiter.tryAcquire('client-a'), isFalse);
      expect(limiter.tryAcquire('client-b'), isTrue);
    });
  });
}
