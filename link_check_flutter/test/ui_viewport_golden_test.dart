import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_check_flutter/main.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LinkCheckApp());
    await tester.pumpAndSettle();
  }

  testWidgets('390px home layout golden', (tester) async {
    await pumpHome(tester, 390);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/link_check_home_390.png'),
    );
  });

  testWidgets('1280px home layout golden', (tester) async {
    await pumpHome(tester, 1280);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/link_check_home_1280.png'),
    );
  });
}
