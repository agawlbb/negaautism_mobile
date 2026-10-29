import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negaautism_mobile/home_landing.dart';
import 'package:negaautism_mobile/website_theme.dart';

void main() {
  testWidgets(
    'home actions fit a small phone and remain usable at large text size',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var browsed = false;
      for (final size in [const Size(320, 568), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: websiteTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: HomeLanding(onBrowse: () => browsed = true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Browse providers'));
        await tester.tap(find.text('Browse providers'));
        expect(find.text('Login'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(browsed, isTrue);
    },
  );
}
