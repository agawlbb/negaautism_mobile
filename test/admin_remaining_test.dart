import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/admin_users_screen.dart';
import 'package:negaautism_mobile/admin_pdf_screen.dart';
import 'package:negaautism_mobile/admin_screen.dart';
import 'package:negaautism_mobile/document_export.dart';
import 'package:negaautism_mobile/provider_service.dart';
import 'package:negaautism_mobile/vps_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'document export validates bytes and filename before opening native UI',
    () async {
      var calls = 0;
      const channel = MethodChannel('org.negaautism.mobileapp/documents');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'savePdf');
            expect(
              (call.arguments as Map)['filename'],
              'provider-1-directory.pdf',
            );
            return false;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final pdf = Uint8List.fromList('%PDF-1.4 synthetic'.codeUnits);
      expect(
        await DocumentExport.savePdf(pdf, 'provider-1-directory.pdf'),
        false,
      );
      await expectLater(
        DocumentExport.savePdf(pdf, '../private.pdf'),
        throwsFormatException,
      );
      await expectLater(
        DocumentExport.savePdf(
          Uint8List.fromList('bad'.codeUnits),
          'provider.pdf',
        ),
        throwsFormatException,
      );
      expect(calls, 1);
    },
  );
  testWidgets('user-only manager has a usable admin menu', (tester) async {
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'success': true,
            'permissions': {'admin': true, 'manage_users': true},
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AdminScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Providers'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets(
    'user permission edits confirm before sending and retain input after failure',
    (tester) async {
      var writes = 0;
      final api = VpsApi(
        token: () async => 'synthetic',
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            writes++;
            final body = jsonDecode(r.body) as Map;
            expect(body['uid'], 'target');
            expect(body['username'], 'Updated name');
            expect((body['permissions'] as Map)['manage_providers'], false);
            expect(body.containsKey('email'), false);
            return http.Response(
              '{"success":false,"message":"Synthetic save failure"}',
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'actor_uid': 'actor',
              'items': [
                {
                  'uid': 'target',
                  'username': 'Example',
                  'full_name': 'Example Person',
                  'email': 'test@example.invalid',
                  'user_type': 'parent',
                  'specialty': '',
                  'clinic': '',
                  'verified': 0,
                  'has_profile': true,
                  'permissions': {
                    'manage_users': false,
                    'manage_providers': true,
                    'manage_categories': false,
                    'moderator': false,
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: AdminUsersScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Example'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Updated name');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Manage providers and reviews'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Manage providers and reviews'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage providers and reviews'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save user'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save user'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Change user permissions?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      await tester.scrollUntilVisible(
        find.text('Synthetic save failure'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic save failure'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Username'),
        -300,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Updated name',
      );
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets('PDF booklet preview is invalidated when filters change', (
    tester,
  ) async {
    var exports = 0;
    final providerService = ProviderService(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'success': true,
            'providers': [],
            'categories': [
              {'id': 1, 'category_name': 'Therapy'},
            ],
            'counties': [
              {'id': 1, 'county_name': 'Example county'},
            ],
          }),
          200,
        ),
      ),
    );
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(
            '{"success":true,"items":[{"id":1,"name":"Clinic"}]}',
            200,
          );
        }
        final body = jsonDecode(r.body) as Map;
        if (body['mode'] == 'preview') {
          return http.Response('{"success":true,"count":2,"limit":50}', 200);
        }
        expect(body['mode'], 'booklet');
        expect(body['approved'], '0');
        return http.Response(
          jsonEncode({
            'success': true,
            'pdf_base64': base64Encode('%PDF-1.4 synthetic'.codeUnits),
            'filename': 'provider-directory-booklet.pdf',
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPdfScreen(
          api: api,
          providers: providerService,
          export: (bytes, name) async {
            exports++;
            expect(name, 'provider-directory-booklet.pdf');
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Booklet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview matching providers'));
    await tester.pumpAndSettle();
    expect(find.text('2 matching providers.'), findsOneWidget);
    await tester.tap(find.text('Approved').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unapproved').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save booklet PDF'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Preview matching providers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save booklet PDF'));
    await tester.pumpAndSettle();
    expect(exports, 1);
    await tester.pumpWidget(const SizedBox());
    api.close();
    providerService.close();
  });
}
