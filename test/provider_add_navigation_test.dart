import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/provider_edit_screen.dart';
import 'package:negaautism_mobile/provider_extraction_service.dart';
import 'package:negaautism_mobile/provider_service.dart';

class ManagerToken implements IdTokenResult {
  @override
  String get token => 'synthetic-manager-token';
  @override
  Map<String, dynamic> get claims => {'manage_providers': true};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManagerUser implements User {
  @override
  String get uid => 'synthetic-manager';
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      ManagerToken();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManagerAuth implements FirebaseAuth {
  @override
  User get currentUser => ManagerUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SyntheticExtraction extends ProviderExtractionService {
  final bool missingCounty;
  SyntheticExtraction({this.missingCounty = false});
  @override
  Future<ProviderSuggestions> extract({
    required String url,
    required ProviderDirectory directory,
    required Future<String> Function() token,
    required void Function(String) progress,
  }) async => ProviderSuggestions.fromJson({
    'name': 'Synthetic clinic',
    'description': 'The clinic provides therapy.',
    'website': 'https://example.com/',
    'phone': '706-555-0123',
    'category_id': 1,
    'county_id': missingCounty ? null : 2,
    'supporting_address': '123 Test Street',
    'review_notes': ['Private review note'],
    'sources': [],
  });
}

ProviderDirectory directory() => ProviderDirectory.fromJson({
  'providers': [],
  'categories': [
    {'id': 1, 'category_name': 'Therapy'},
  ],
  'counties': [
    {'id': 2, 'county_name': 'Multiple'},
  ],
});

Future<void> openForm(
  WidgetTester tester,
  ProviderService service, {
  bool missingCounty = false,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Provider directory')),
          body: TextButton(
            onPressed: () => Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => ProviderEditScreen(
                  service: service,
                  directory: directory(),
                  auth: ManagerAuth(),
                  extractionService: SyntheticExtraction(
                    missingCounty: missingCounty,
                  ),
                ),
              ),
            ),
            child: const Text('Open add form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open add form'));
  await tester.pumpAndSettle();
}

Future<void> openReview(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Website (optional)'),
    'https://example.com/',
  );
  await tester.tap(find.text('Fill from website'));
  await tester.pumpAndSettle();
  expect(find.text('Review website suggestions'), findsOneWidget);
}

void main() {
  testWidgets('review add saves selected fields once and closes both screens', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final requests = <Map<String, dynamic>>[];
    final service = ProviderService(
      client: MockClient((request) {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return response.future;
      }),
    );
    addTearDown(service.close);
    await openForm(tester, service);
    await openReview(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
    await tester.pump();
    expect(requests.length, 1);
    expect(find.widgetWithText(ElevatedButton, 'Adding…'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Adding…'),
          )
          .onPressed,
      isNull,
    );
    expect(requests.single['name'], 'Synthetic clinic');
    expect(requests.single['description'], 'The clinic provides therapy.');
    expect(requests.single['idToken'], 'synthetic-manager-token');
    expect(requests.single.containsKey('review_notes'), false);
    expect(requests.single.containsKey('sources'), false);
    expect(requests.single.containsKey('supporting_address'), false);
    response.complete(
      http.Response(
        jsonEncode({'success': true, 'message': 'Provider added.'}),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Provider directory'), findsOneWidget);
    expect(find.byType(ProviderEditScreen), findsNothing);
    expect(requests.length, 1);
  });

  testWidgets('manual add saves and returns directly to directory', (
    tester,
  ) async {
    var writes = 0;
    final service = ProviderService(
      client: MockClient((request) async {
        writes++;
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['name'], 'Manual clinic');
        return http.Response(
          jsonEncode({'success': true, 'message': 'Provider added.'}),
          200,
        );
      }),
    );
    addTearDown(service.close);
    await openForm(tester, service);
    expect(find.textContaining('New providers await approval'), findsNothing);
    expect(find.textContaining('Enter a website below'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Provider name'),
      'Manual clinic',
    );
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Therapy').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('County'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multiple').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Provider directory'), findsOneWidget);
    expect(find.byType(ProviderEditScreen), findsNothing);
  });

  testWidgets(
    'review save failure keeps selections open and does not auto-retry',
    (tester) async {
      var writes = 0;
      final service = ProviderService(
        client: MockClient((_) async {
          writes++;
          throw TimeoutException('Synthetic timeout');
        }),
      );
      addTearDown(service.close);
      await openForm(tester, service);
      await openReview(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Review website suggestions'), findsOneWidget);
      expect(
        find.textContaining('Check the directory before submitting again'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Add provider'),
        findsOneWidget,
      );
    },
  );

  testWidgets('missing county can be completed and saved directly in review', (
    tester,
  ) async {
    var writes = 0;
    final service = ProviderService(
      client: MockClient((request) async {
        writes++;
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['county_id'], 2);
        expect(data['name'], 'Corrected clinic');
        expect(data['phone_number'], '706-555-0199');
        expect(data['description'], 'Edited description.');
        return http.Response(
          jsonEncode({'success': true, 'message': 'Added.'}),
          200,
        );
      }),
    );
    addTearDown(service.close);
    await openForm(tester, service, missingCounty: true);
    await openReview(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Choose a county'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Provider name'),
      'Corrected clinic',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '706-555-0199',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Edited description.',
    );
    await tester.tap(find.text('County'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multiple').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add provider'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Provider directory'), findsOneWidget);
    expect(find.byType(ProviderEditScreen), findsNothing);
    expect(find.text('Review website suggestions'), findsNothing);
  });
}
