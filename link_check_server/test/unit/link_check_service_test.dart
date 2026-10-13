import 'package:link_check_server/src/link_check/link_check_service.dart';
import 'package:test/test.dart';

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
        expect(result.error, contains('443'));
        expect(result.redirectHops, 0);
      },
    );
  });
}
