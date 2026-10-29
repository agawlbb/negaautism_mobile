import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negaautism_mobile/provider_contact_links.dart';
import 'package:negaautism_mobile/website_theme.dart';

void main() {
  test(
    'website links accept HTTP/HTTPS and reject executable or local schemes',
    () {
      expect(
        providerWebsiteUri(' example.invalid/path?q=1 '),
        Uri.parse('https://example.invalid/path?q=1'),
      );
      expect(
        providerWebsiteUri('http://example.invalid'),
        Uri.parse('http://example.invalid'),
      );
      for (final value in [
        '',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'tel:5550100',
        'https:///',
      ]) {
        expect(providerWebsiteUri(value), isNull);
      }
    },
  );

  test('phone links preserve country code and extension without display formatting', () {
    expect(
      providerPhoneUri('+1 (555) 123-4567')?.toString(),
      'tel:+15551234567',
    );
    expect(
      providerPhoneUri('555-123-4567 ext. 89')?.toString(),
      'tel:5551234567;ext=89',
    );
    expect(
      providerPhoneUri('555-123-4567 x89')?.toString(),
      'tel:5551234567;ext=89',
    );
    expect(providerPhoneUri('Not available'), isNull);
    expect(providerPhoneUri('---'), isNull);
  });

  testWidgets('provider contact taps request the website and phone handlers', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: websiteTheme(),
        home: Scaffold(
          body: ProviderContactLinks(
            website: 'example.invalid',
            phone: '(555) 123-4567',
            launch: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('example.invalid'));
    await tester.tap(find.text('(555) 123-4567'));
    await tester.pumpAndSettle();
    expect(opened, [
      Uri.parse('https://example.invalid'),
      Uri.parse('tel:5551234567'),
    ]);
  });

  for (final throws in [false, true]) {
    testWidgets('missing app handler displays feedback (throws: $throws)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderContactLinks(
              website: 'https://example.invalid',
              phone: '',
              launch: (_) async {
                if (throws) throw Exception('No handler');
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('https://example.invalid'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open the browser.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
