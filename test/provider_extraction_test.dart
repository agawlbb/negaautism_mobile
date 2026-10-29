import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negaautism_mobile/provider_extraction_service.dart';
import 'package:negaautism_mobile/provider_suggestions_screen.dart';
import 'package:negaautism_mobile/provider_service.dart';

ProviderDirectory directory() => ProviderDirectory.fromJson({
  'providers': [],
  'categories': [
    {'id': 1, 'category_name': 'Therapy'},
  ],
  'counties': [
    {'id': 2, 'county_name': 'Multiple'},
  ],
});
Map<String, dynamic> result() => {
  'name': 'Suggested clinic',
  'description': 'The clinic offers therapy.',
  'phone': null,
  'website': null,
  'category_id': 1,
  'county_id': null,
  'supporting_address': '123 Test Street',
  'review_notes': ['County needs administrator review.'],
  'sources': [
    {
      'field': 'description',
      'url': 'https://example.com/contact',
      'excerpt': 'Therapy services',
    },
  ],
};

void main() {
  test(
    'reconnect sends same request ID and resumes without starting again',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        final data =
            jsonDecode(await socket.first as String) as Map<String, dynamic>;
        requests.add(data);
        if (requests.length == 1) {
          socket.add(jsonEncode({'type': 'accepted'}));
          await socket.close();
        } else {
          socket.add(jsonEncode({'type': 'result', 'result': result()}));
          await socket.close();
        }
      });
      addTearDown(() => server.close(force: true));
      final service = ProviderExtractionService(
        endpoint: Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );
      addTearDown(service.close);
      var refreshes = 0;
      final suggestions = await service.extract(
        url: 'https://example.com',
        directory: directory(),
        token: () async => 'fresh-${++refreshes}',
        progress: (_) {},
      );
      expect(suggestions.fields['name'], 'Suggested clinic');
      expect(requests.length, 2);
      expect(requests[0]['resume_only'], false);
      expect(requests[1]['resume_only'], true);
      expect(requests[0]['request_id'], requests[1]['request_id']);
      expect(requests[0]['idToken'], isNot(requests[1]['idToken']));
      expect(refreshes, 3);
    },
  );

  test('permission failure stops before connecting', () async {
    final service = ProviderExtractionService();
    addTearDown(service.close);
    await expectLater(
      service.extract(
        url: 'https://example.com',
        directory: directory(),
        token: () async =>
            throw const ProviderExtractionException('Permission removed'),
        progress: (_) {},
      ),
      throwsA(isA<ProviderExtractionException>()),
    );
  });

  testWidgets(
    'populated fields stay unchecked; notes and sources are separate',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ProviderReviewResult? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.push<ProviderReviewResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderSuggestionsScreen(
                        suggestions: ProviderSuggestions.fromJson(result()),
                        directory: directory(),
                        current: const {'name': 'Administrator name'},
                      ),
                    ),
                  );
                },
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      final nameCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Provider name'),
      );
      final descriptionCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Description'),
      );
      expect(nameCheckbox.value, false);
      expect(descriptionCheckbox.value, true);
      expect(find.text('Administrator review notes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Apply changes to provider form'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply changes to provider form'));
      await tester.pumpAndSettle();
      expect(selected!.fields['name'], 'Administrator name');
      expect(selected!.fields['description'], 'The clinic offers therapy.');
      expect(selected!.fields.containsKey('review_notes'), false);
      expect(selected!.fields.containsKey('sources'), false);
    },
  );
}
