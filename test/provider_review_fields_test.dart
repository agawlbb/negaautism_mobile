import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negaautism_mobile/provider_extraction_service.dart';
import 'package:negaautism_mobile/provider_service.dart';
import 'package:negaautism_mobile/provider_suggestions_screen.dart';

ProviderDirectory directory() => ProviderDirectory.fromJson({
  'providers': [],
  'categories': [
    {'id': 1, 'category_name': 'Therapy'},
  ],
  'counties': [
    {'id': 2, 'county_name': 'Multiple'},
  ],
});

ProviderSuggestions suggestions(String website) =>
    ProviderSuggestions.fromJson({
      'name': 'Suggested name',
      'description': 'Suggested description',
      'website': website,
      'phone': null,
      'category_id': null,
      'county_id': null,
      'review_notes': ['Private note'],
      'sources': [],
    });

void largeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('small-screen review validates omitted choices before any save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderSuggestionsScreen(
          suggestions: suggestions('https://justpeople.org'),
          directory: directory(),
          current: const {},
          onAdd: (_) async {
            saves++;
            return 'Added';
          },
        ),
      ),
    );
    await tester.tap(find.text('Add provider'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('Choose a county'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('review-county_id:null')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('County'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multiple').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final example in [
    ('justpeople.org', 'https://justpeople.org', true),
    ('justpeople.org', 'https://justpeople.org/', true),
    ('http://justpeople.org', 'https://justpeople.org/', true),
    ('https://justpeople.org', 'http://justpeople.org', false),
    ('justpeople.org', 'https://other.org', false),
    ('justpeople.org/about', 'https://justpeople.org/contact', false),
    ('justpeople.org?a=1', 'https://justpeople.org?a=2', false),
    ('justpeople.org#services', 'https://justpeople.org', false),
  ]) {
    testWidgets('website selection ${example.$1} -> ${example.$2}', (
      tester,
    ) async {
      largeScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderSuggestionsScreen(
            suggestions: suggestions(example.$2),
            directory: directory(),
            current: {'website': example.$1},
          ),
        ),
      );
      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Website'),
      );
      expect(checkbox.value, example.$3);
      final editor = tester.widget<TextFormField>(
        find.byKey(const ValueKey('review-website')),
      );
      expect(editor.controller!.text, example.$3 ? example.$2 : example.$1);
    });
  }

  testWidgets(
    'all fields editable without AI values; apply keeps edits and clears',
    (tester) async {
      largeScreen(tester);
      ProviderReviewResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<ProviderReviewResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderSuggestionsScreen(
                        suggestions: suggestions('https://justpeople.org'),
                        directory: directory(),
                        current: const {
                          'name': 'Original name',
                          'website': 'justpeople.org',
                          'phone': '555-0100',
                        },
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
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Provider name'),
            )
            .value,
        false,
      );
      await tester.enterText(
        find.byKey(const ValueKey('review-name')),
        'Edited name',
      );
      await tester.enterText(
        find.byKey(const ValueKey('review-description')),
        'Edited description',
      );
      await tester.enterText(find.byKey(const ValueKey('review-phone')), '');
      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Therapy').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('County'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multiple').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply changes to provider form'));
      await tester.pumpAndSettle();
      expect(result!.fields, {
        'name': 'Edited name',
        'description': 'Edited description',
        'website': 'https://justpeople.org',
        'phone': '',
        'category_id': 1,
        'county_id': 2,
      });
    },
  );
}
