import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/admin_user_cleanup_screen.dart';
import 'package:negaautism_mobile/admin_users_screen.dart';
import 'package:negaautism_mobile/vps_api.dart';

Map<String, dynamic> candidate(String uid) => {
  'uid': uid,
  'full_name': 'aBcDeFgHiJ $uid',
  'email': '$uid@example.invalid',
  'username': uid,
  'reasons': ['Repeated upper/lowercase switching'],
};

void main() {
  testWidgets('undelete restores only the selected pending account', (
    tester,
  ) async {
    var restored = false;
    var writes = 0;
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((request) async {
        if (request.method == 'PATCH') {
          expect(request.url.path, '/api/admin/users');
          expect(jsonDecode(request.body), {'uid': 'pending'});
          writes++;
          restored = true;
          return http.Response('{"success":true}', 200);
        }
        final showPending =
            request.url.queryParameters['include_pending'] == '1';
        return http.Response(
          jsonEncode({
            'success': true,
            'actor_uid': 'manager',
            'items': showPending && !restored
                ? [
                    {
                      ...candidate('pending'),
                      'pending_delete': true,
                      'delete_time': '2026-11-29T12:00:00Z',
                    },
                  ]
                : [],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: AdminUsersScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show pending deletions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undelete'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Undelete'), findsNothing);
    expect(find.text('No matching users.'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('pending accounts appear only after opting in', (tester) async {
    final filters = <String?>[];
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((request) async {
        final filter = request.url.queryParameters['include_pending'];
        filters.add(filter);
        return http.Response(
          jsonEncode({
            'success': true,
            'actor_uid': 'manager',
            'items': filter == '1'
                ? [
                    {
                      ...candidate('pending'),
                      'pending_delete': true,
                      'delete_time': '2026-11-29T12:00:00Z',
                    },
                  ]
                : [],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: AdminUsersScreen(api: api)));
    await tester.pumpAndSettle();
    expect(filters, ['0']);
    expect(find.textContaining('Pending deletion:'), findsNothing);
    await tester.tap(find.text('Show pending deletions'));
    await tester.pumpAndSettle();
    expect(filters, ['0', '1']);
    expect(find.textContaining('Pending deletion: 2026-11-29'), findsOneWidget);
    await tester.tap(find.text('Show pending deletions'));
    await tester.pumpAndSettle();
    expect(filters, ['0', '1', '0']);
    expect(find.textContaining('Pending deletion:'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

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
            '{"success":true,"scheduled":["b"],"failed":[]}',
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
    expect(find.textContaining('Review up to 50'), findsNothing);
    expect(
      find.textContaining('Repeated upper/lowercase switching'),
      findsNothing,
    );
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
    await tester.tap(find.text('Delete'));
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
    expect(find.text('1 deleted.'), findsOneWidget);
    await tester.tap(find.text('Next batch'));
    await tester.pumpAndSettle();
    expect(pages, [null, 'b']);
    expect(find.text('No flagged accounts.'), findsOneWidget);
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
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.textContaining('Refresh before retrying.'), findsOneWidget);
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
