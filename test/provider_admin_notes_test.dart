import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/admin_screen.dart';
import 'package:negaautism_mobile/provider_edit_screen.dart';
import 'package:negaautism_mobile/provider_service.dart';
import 'package:negaautism_mobile/vps_api.dart';

import 'provider_add_navigation_test.dart' show ManagerAuth, directory;

void main() {
  testWidgets(
    'provider list shows names with yellow pending highlighting only',
    (tester) async {
      final api = VpsApi(
        token: () async => 'synthetic',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'success': true,
              'items': [
                {
                  'id': 7,
                  'name': 'Imported clinic',
                  'approved': 0,
                  'admin_notes': 'Private source',
                },
                {
                  'id': 8,
                  'name': 'Approved clinic',
                  'approved': 1,
                  'admin_notes': 'Other private source',
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminQueueScreen(kind: 'providers', api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Imported clinic'), findsOneWidget);
      expect(find.text('Approved clinic'), findsOneWidget);
      expect(find.textContaining('private source'), findsNothing);
      expect(find.text('Private source'), findsNothing);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.byTooltip('Unapprove'), findsNothing);
      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards[0].color, Colors.yellow.shade100);
      expect(cards[1].color, isNull);
    },
  );

  for (final initiallyApproved in [false, true]) {
    testWidgets(
      'editor toggles approval after confirmation ($initiallyApproved)',
      (tester) async {
        final writes = <bool>[];
        final service = ProviderService(
          client: MockClient((request) async {
            expect(request.method, 'PATCH');
            expect(request.url.path, '/api/admin/providers/7/approval');
            expect(
              request.headers['Authorization'],
              'Bearer synthetic-manager-token',
            );
            writes.add((jsonDecode(request.body) as Map)['approved'] as bool);
            return http.Response('{"success":true}', 200);
          }),
        );
        addTearDown(service.close);
        await tester.pumpWidget(
          MaterialApp(
            home: ProviderEditScreen(
              service: service,
              directory: directory(),
              auth: ManagerAuth(),
              initialAdminNotes: 'Private source',
              initialApproved: initiallyApproved,
              provider: DirectoryProvider.fromJson({
                'id': 7,
                'name': 'Clinic',
                'category_id': 1,
                'county_id': 2,
                'category_name': 'Therapy',
                'county_name': 'Multiple',
              }),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(initiallyApproved ? 'Approved' : 'Unapproved'),
          findsOneWidget,
        );
        final action = initiallyApproved ? 'Unapprove' : 'Approve';
        await tester.tap(find.widgetWithText(OutlinedButton, action));
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await tester.tap(find.widgetWithText(OutlinedButton, action));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, action));
        await tester.pumpAndSettle();
        expect(writes, [!initiallyApproved]);
        expect(
          find.text(initiallyApproved ? 'Unapproved' : 'Approved'),
          findsOneWidget,
        );
      },
    );
  }

  for (final failedLoad in [false, true]) {
    testWidgets(
      'editor loads private notes before saving (failure=$failedLoad)',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var fail = failedLoad;
        final writes = <Map<String, dynamic>>[];
        final service = ProviderService(
          client: MockClient((request) async {
            expect(
              request.headers['Authorization'],
              'Bearer synthetic-manager-token',
            );
            if (request.method == 'GET') {
              expect(request.url.path, '/api/admin/providers/7');
              if (fail) {
                return http.Response(
                  '{"success":false,"message":"Notes unavailable"}',
                  503,
                );
              }
              return http.Response(
                '{"success":true,"item":{"id":7,"admin_notes":"Private import source"}}',
                200,
              );
            }
            writes.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              '{"success":true,"message":"Provider saved."}',
              200,
            );
          }),
        );
        addTearDown(service.close);
        await tester.pumpWidget(
          MaterialApp(
            home: ProviderEditScreen(
              service: service,
              directory: directory(),
              auth: ManagerAuth(),
              provider: DirectoryProvider.fromJson({
                'id': 7,
                'name': 'Imported clinic',
                'category_id': 1,
                'county_id': 2,
                'category_name': 'Therapy',
                'county_name': 'Multiple',
              }),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (failedLoad) {
          expect(
            find.widgetWithText(TextFormField, 'Administrator notes'),
            findsNothing,
          );
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Save provider'),
                )
                .onPressed,
            isNull,
          );
          expect(writes, isEmpty);
          fail = false;
          await tester.tap(find.text('Retry loading administrator notes'));
          await tester.pumpAndSettle();
        }
        final field = find.widgetWithText(TextFormField, 'Administrator notes');
        expect(field, findsOneWidget);
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          'Private import source',
        );
        await tester.enterText(field, 'Reviewed source; verify hours.');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save provider'));
        await tester.pumpAndSettle();
        expect(writes.single['admin_notes'], 'Reviewed source; verify hours.');
        expect(writes.single.containsKey('approved'), isFalse);
      },
    );
  }
}
