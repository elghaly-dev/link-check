import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_check_client/link_check_client.dart';
import 'package:link_check_flutter/screens/link_check_result_view.dart';

void main() {
  testWidgets('shows success metrics for a reachable URL', (tester) async {
    final result = LinkCheckResult(
      requestedUrl: 'https://example.com',
      finalUrl: 'https://example.com/',
      statusCode: 200,
      responseTimeMs: 142,
      isHttps: true,
      isReachable: true,
      checkedAt: DateTime.utc(2026, 10, 13, 12, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkCheckResultView(result: result),
        ),
      ),
    );

    expect(find.textContaining('200 OK'), findsOneWidget);
    expect(find.text('142 ms'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
  });

  testWidgets('shows validation error from result payload', (tester) async {
    final result = LinkCheckResult(
      requestedUrl: 'http://127.0.0.1/',
      statusCode: null,
      responseTimeMs: 0,
      isHttps: false,
      isReachable: false,
      error: 'Target address is not allowed.',
      checkedAt: DateTime.utc(2026, 10, 13, 12, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkCheckResultView(result: result),
        ),
      ),
    );

    expect(find.text('Target address is not allowed.'), findsOneWidget);
    expect(find.textContaining('blocked or failed'), findsOneWidget);
  });
}
