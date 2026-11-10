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
  testWidgets('administrator queue retains import notes after approval', (
    tester,
  ) async {
    var approved = false;
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((request) async {
        if (request.method == 'PATCH') {
          expect(jsonDecode(request.body), {'approved': true});
          approved = true;
          return http.Response('{"success":true}', 200);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'items': [
              {
                'id': 7,
                'name': 'Imported clinic',
                'approved': approved ? 1 : 0,
                'admin_notes': 'Check the service area with the source.',
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminQueueScreen(kind: 'providers', api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrator notes'), findsOneWidget);
    expect(
      find.text('Check the service area with the source.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(approved, isTrue);
    expect(find.byTooltip('Unapprove'), findsOneWidget);
    expect(
      find.text('Check the service area with the source.'),
      findsOneWidget,
    );
  });

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
