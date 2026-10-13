import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given LinkCheck endpoint', (sessionBuilder, endpoints) {
    test(
      'when checking a blocked localhost URL then returns security error',
      () async {
        final result = await endpoints.linkCheck.check(
          sessionBuilder,
          'http://127.0.0.1/',
        );

        expect(result.isReachable, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('not allowed'));
      },
    );

    test(
      'when checking an invalid URL then returns validation error',
      () async {
        final result = await endpoints.linkCheck.check(
          sessionBuilder,
          'not-a-url',
        );

        expect(result.isReachable, isFalse);
        expect(result.error, isNotNull);
      },
    );
  });
}
