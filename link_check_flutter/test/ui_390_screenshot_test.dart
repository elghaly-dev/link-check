import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_check_client/link_check_client.dart';
import 'package:link_check_flutter/screens/link_check_result_view.dart';
void main() {
  testWidgets('390px result layout golden', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = LinkCheckResult(
      requestedUrl: 'https://example.com/start',
      finalUrl: 'https://example.com/final',
      redirectHops: 2,
      statusCode: 200,
      responseTimeMs: 142,
      isHttps: true,
      isReachable: true,
      checkedAt: DateTime.utc(2026, 10, 13, 12, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LinkCheckResultView(result: result),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(LinkCheckResultView),
      matchesGoldenFile('goldens/link_check_result_390.png'),
    );
  });

}
