import 'dart:io';

import 'package:link_check_server/src/link_check/link_check_rate_limiter.dart';
import 'package:link_check_server/src/link_check/link_check_security.dart';
import 'package:test/test.dart';

void main() {
  group('LinkCheckSecurity', () {
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

    test('rejects non-http schemes', () {
      expect(
        () => security.validateRequestUrl('file:///etc/passwd'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

    test('rejects embedded credentials', () {
      expect(
        () => security.validateRequestUrl('http://user:pass@example.com'),
        throwsA(isA<LinkCheckSecurityException>()),
      );
    });

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
        () => security.validateRequestUrl('http://169.254.169.254/latest/meta-data'),
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
  });

  group('LinkCheckRateLimiter', () {
    test('allows requests under the limit', () {
      final limiter = LinkCheckRateLimiter(maxRequests: 2, window: const Duration(minutes: 1));
      expect(limiter.tryAcquire('client-a'), isTrue);
      expect(limiter.tryAcquire('client-a'), isTrue);
      expect(limiter.tryAcquire('client-a'), isFalse);
      expect(limiter.tryAcquire('client-b'), isTrue);
    });
  });
}
