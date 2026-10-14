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
