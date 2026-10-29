import 'package:negaautism_mobile/admin_taxonomy_screen.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/admin_screen.dart';
import 'package:negaautism_mobile/vps_api.dart';

void main() {
  testWidgets('dashboard shows only server-authorized capabilities', (
    tester,
  ) async {
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'success': true,
            'permissions': {
              'admin': true,
              'manage_providers': false,
              'moderator': true,
            },
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AdminScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Providers'), findsNothing);
    expect(find.text('Reviews'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets('review approval requires confirmation and sends exactly once', (
    tester,
  ) async {
    var writes = 0;
    var approved = false;
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((r) async {
        if (r.method == 'PATCH') {
          writes++;
          expect(r.url.path, '/api/admin/reviews/1/approval');
          expect(jsonDecode(r.body), {'approved': true});
          approved = true;
          return http.Response('{"success":true}', 200);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'items': approved
                ? []
                : [
                    {
                      'id': 1,
                      'provider_name': 'Example clinic',
                      'text': 'Example review',
                      'stars': 4,
                      'approved': 0,
                    },
                  ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminQueueScreen(kind: 'reviews', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('No matching records.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets('taxonomy failed save keeps edited name available', (
    tester,
  ) async {
    var writes = 0;
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((r) async {
        if (r.method == 'PUT') {
          writes++;
          return http.Response(
            '{"success":false,"message":"Save unavailable"}',
            503,
          );
        }
        return http.Response(
          '{"success":true,"items":[{"id":1,"name":"Therapy"}]}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminTaxonomyScreen(kind: 'categories', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Therapy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family support');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Save unavailable'), findsOneWidget);
    expect(find.text('Family support'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
