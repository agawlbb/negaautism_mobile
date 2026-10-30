import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/admin_user_cleanup_screen.dart';
import 'package:negaautism_mobile/vps_api.dart';

Map<String, dynamic> candidate(String uid) => {
  'uid': uid,
  'full_name': 'aBcDeFgHiJ $uid',
  'email': '$uid@example.invalid',
  'username': uid,
  'reasons': ['Repeated upper/lowercase switching'],
};

void main() {
  testWidgets('kept accounts are excluded and deletion requires confirmation', (
    tester,
  ) async {
    final writes = <Map<String, dynamic>>[];
    final pages = <String?>[];
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '{"success":true,"deleted":["b"],"failed":[]}',
            200,
          );
        }
        pages.add(request.url.queryParameters['after']);
        return http.Response(
          jsonEncode({
            'success': true,
            'items': pages.length == 1 ? [candidate('a'), candidate('b')] : [],
            'next_cursor': pages.length == 1 ? 'b' : null,
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminUserCleanupScreen(api: api)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete selected (2)'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete selected (1)'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(find.text('Delete selected (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete accounts'));
    await tester.pumpAndSettle();
    expect(writes, [
      {
        'users': [
          {'uid': 'b', 'full_name': 'aBcDeFgHiJ b'},
        ],
      },
    ]);
    expect(find.text('aBcDeFgHiJ a'), findsOneWidget);
    expect(find.text('aBcDeFgHiJ b'), findsNothing);
    expect(find.text('1 deleted. 0 skipped or not confirmed.'), findsOneWidget);
    await tester.tap(find.text('Next batch'));
    await tester.pumpAndSettle();
    expect(pages, [null, 'b']);
    expect(
      find.text('No more flagged accounts in this review.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('uncertain deletion is not retried and requires refresh', (
    tester,
  ) async {
    var writes = 0, reads = 0;
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          writes++;
          return http.Response(
            '{"success":false,"message":"Connection lost"}',
            503,
          );
        }
        reads++;
        return http.Response(
          jsonEncode({
            'success': true,
            'items': [candidate('a')],
            'next_cursor': null,
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminUserCleanupScreen(api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete selected (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete accounts'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(
      find.textContaining('Some deletions may have completed'),
      findsOneWidget,
    );
    final deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete selected (0)'),
    );
    expect(deleteButton.onPressed, isNull);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await tester.tap(find.text('Refresh batch'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(writes, 1);
    expect(find.text('Delete selected (1)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
