import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_check_flutter/copy/public_copy.dart';
import 'package:link_check_flutter/main.dart';

void main() {
  test('contact line matches HOUSE_RULES.md exactly', () {
    expect(
      PublicCopy.contactLine,
      'Email first: support@elghaly.dev. Calls only by appointment.',
    );
  });

  testWidgets('home page shows required public footer copy', (tester) async {
    await tester.pumpWidget(const LinkCheckApp());
    await tester.pumpAndSettle();

    expect(find.text(PublicCopy.footerAttribution), findsOneWidget);
    expect(find.text(PublicCopy.contactLine), findsOneWidget);
  });

  testWidgets('visible text avoids banned words', (tester) async {
    await tester.pumpWidget(const LinkCheckApp());
    await tester.pumpAndSettle();

    final visible = _collectVisibleStrings(tester);
    final banned = RegExp(
      r'\b(live|profit|guarantee|audit|launched)\b',
      caseSensitive: false,
    );

    for (final line in visible) {
      expect(
        banned.hasMatch(line),
        isFalse,
        reason: 'Banned word in visible text: "$line"',
      );
    }
  });

  test('public web assets avoid banned words', () {
    final root = Directory.current.path.endsWith('link_check_flutter')
        ? Directory.current
        : Directory('link_check_flutter');
    final paths = [
      File('${root.path}/web/index.html'),
      File('${root.path}/web/manifest.json'),
    ];
    final banned = RegExp(
      r'\b(live|profit|guarantee|audit|launched)\b',
      caseSensitive: false,
    );

    for (final file in paths) {
      expect(file.existsSync(), isTrue, reason: file.path);
      final text = file.readAsStringSync();
      expect(
        banned.hasMatch(text),
        isFalse,
        reason: 'Banned word in ${file.path}',
      );
    }

    expect(
      File('${root.path}/web/index.html').readAsStringSync(),
      contains('elghaly'),
    );
  });
}

List<String> _collectVisibleStrings(WidgetTester tester) {
  final out = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget;
    if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
      out.add(widget.data!);
    }
  }
  return out;
}
