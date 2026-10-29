import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/provider_logo.dart';
import 'package:negaautism_mobile/provider_service.dart';
import 'package:negaautism_mobile/provider_extraction_service.dart';
import 'package:negaautism_mobile/provider_suggestions_screen.dart';

Uint8List png() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

void main() {
  test('logo URLs stay on the hosted logo directory and reject paths or external URLs', () {
    expect(providerLogoUrl('42.png'), 'https://negaautism.org/logos/42.png');
    for (final value in [
      '',
      '../secret.png',
      'https://elsewhere/logo.png',
      'logo.svg',
      'logo.php',
      'a.png?token=x',
    ]) {
      expect(providerLogoUrl(value), isNull);
    }
    final provider = DirectoryProvider.fromJson({
      'id': 1,
      'name': 'Clinic',
      'logo': '42.png',
      'category_id': 1,
      'county_id': 2,
      'category_name': 'Therapy',
      'county_name': 'Multiple',
    });
    expect(provider.logo, '42.png');
  });

  test('selected logo must be a bounded JPG/PNG', () {
    expect(ProviderLogo.fromBytes(png()).filename, 'logo.png');
    expect(
      () => ProviderLogo.fromBytes(Uint8List(500 * 1024 + 1)),
      throwsA(isA<ProviderLogoException>()),
    );
    expect(
      () => ProviderLogo.fromBytes(Uint8List.fromList('<svg/>'.codeUnits)),
      throwsA(isA<ProviderLogoException>()),
    );
  });

  test('logo upload sends one authenticated multipart save without changing text-only JSON saves', () async {
    var writes = 0;
    final service = ProviderService(
      client: MockClient((request) async {
        writes++;
        expect(request.url.query, isEmpty);
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        final body = latin1.decode(request.bodyBytes);
        expect(body, contains('name="idToken"'));
        expect(body, contains('synthetic-token'));
        expect(body, contains('name="logo"; filename="logo.png"'));
        expect(body, contains(latin1.decode(png())));
        expect(body, isNot(contains('review_notes')));
        return http.Response(
          jsonEncode({'success': true, 'message': 'Provider added.'}),
          201,
        );
      }),
    );
    addTearDown(service.close);
    await service.save(
      token: 'synthetic-token',
      name: 'Clinic',
      website: '',
      description: '',
      phone: '',
      categoryId: 1,
      countyId: 2,
      logo: ProviderLogo.fromBytes(png()),
    );
    expect(writes, 1);
  });

  test('malformed optional logo does not discard other extracted fields', () {
    final suggestions = ProviderSuggestions.fromJson({
      'name': 'Clinic',
      'review_notes': [],
      'sources': [],
      'logo_image': {'data_base64': 'not valid base64!'},
    });
    expect(suggestions.fields['name'], 'Clinic');
    expect(suggestions.fields['logo'], isNull);
    expect(suggestions.notes.single, contains('logo could not be read'));
  });

  testWidgets(
    'native logo selection previews the chosen image and handles cancel',
    (tester) async {
      ProviderLogo? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderLogoInput(
              logo: null,
              pick: () async => ProviderLogo.fromBytes(png()),
              onChanged: (logo) => selected = logo,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Upload logo'));
      await tester.pumpAndSettle();
      expect(selected!.filename, 'logo.png');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderLogoInput(
              logo: selected,
              pick: () async => null,
              onChanged: (logo) => selected = logo,
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Upload logo'));
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
    },
  );

  testWidgets(
    'review keeps a chosen logo and can explicitly accept the website logo',
    (tester) async {
      final existing = ProviderLogo.fromBytes(png());
      final suggested = ProviderLogo.fromBytes(
        png(),
        sourceUrl: 'https://example.com/logo.png',
      );
      ProviderLogo? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderSuggestionsScreen(
            suggestions: ProviderSuggestions.fromJson({
              'logo_url': 'https://example.com/logo.png',
              'review_notes': [],
              'sources': [],
            })..fields['logo'] = suggested,
            directory: ProviderDirectory.fromJson({
              'providers': [],
              'categories': [
                {'id': 1, 'category_name': 'Therapy'},
              ],
              'counties': [
                {'id': 2, 'county_name': 'Multiple'},
              ],
            }),
            current: {
              'name': 'Clinic',
              'category_id': 1,
              'county_id': 2,
              'logo': existing,
            },
            onAdd: (fields) async {
              saved = fields['logo'] as ProviderLogo?;
              throw const ProviderApiException('Synthetic failure');
            },
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
      await tester.pumpAndSettle();
      expect(saved, same(existing));
      await tester.scrollUntilVisible(
        find.text('Use suggested website logo'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Use suggested website logo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
      await tester.pumpAndSettle();
      expect(saved, same(suggested));
    },
  );
}
