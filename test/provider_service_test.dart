import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/provider_service.dart';

void main() {
  test(
    'public listing sends filters without credentials and decodes SQL IDs',
    () async {
      final service = ProviderService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'vps.negaautism.org');
          expect(request.url.path, '/api/providers');
          expect(request.url.queryParameters, {
            'county_id': '2',
            'category_id': '3',
          });
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode({
              'success': true,
              'providers': [
                {
                  'id': '1',
                  'name': 'Synthetic provider',
                  'website': null,
                  'description': 'Therapy',
                  'phone_number': null,
                  'category_id': '3',
                  'category_name': 'Therapy',
                  'county_id': '2',
                  'county_name': 'Synthetic county',
                },
              ],
              'categories': [
                {'id': '3', 'category_name': 'Therapy'},
              ],
              'counties': [
                {'id': 2, 'county_name': 'Synthetic county'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final directory = await service.load(countyId: 2, categoryId: 3);
      expect(directory.providers.single.id, 1);
      expect(directory.providers.single.phone, '');
      expect(directory.categories.single.id, 3);
    },
  );

  test('save uses JSON token and only supported editable fields', () async {
    final service = ProviderService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/save_provider.php');
        expect(request.url.query, isEmpty);
        expect(jsonDecode(request.body), {
          'idToken': 'synthetic-token',
          'id': 7,
          'name': 'New name',
          'website': '',
          'description': 'Synthetic description',
          'phone_number': '',
          'category_id': 3,
          'county_id': 2,
        });
        return http.Response(
          '{"success":true,"message":"Provider updated."}',
          200,
        );
      }),
    );
    addTearDown(service.close);
    expect(
      await service.save(
        token: 'synthetic-token',
        id: 7,
        name: ' New name ',
        website: '',
        description: 'Synthetic description',
        phone: '',
        categoryId: 3,
        countyId: 2,
      ),
      'Provider updated.',
    );
  });

  test('create omits ID and reports confirmed addition', () async {
    final service = ProviderService(
      client: MockClient((request) async {
        expect((jsonDecode(request.body) as Map).containsKey('id'), isFalse);
        return http.Response(
          '{"success":true,"message":"Provider added."}',
          201,
        );
      }),
    );
    addTearDown(service.close);
    expect(
      await service.save(
        token: 'synthetic',
        name: 'Name',
        website: '',
        description: '',
        phone: '',
        categoryId: 1,
        countyId: 2,
      ),
      'Provider added.',
    );
  });

  test('missing token prevents any write request', () async {
    final service = ProviderService(
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    addTearDown(service.close);
    await expectLater(
      service.save(
        token: '',
        name: 'Name',
        website: '',
        description: '',
        phone: '',
        categoryId: 1,
        countyId: 2,
      ),
      throwsA(isA<ProviderApiException>()),
    );
  });

  for (final response in [
    http.Response('Forbidden with internal details', 403),
    http.Response('<html>Not deployed</html>', 404),
    http.Response('<html>Server unavailable</html>', 500),
    http.Response('{"success":false,"message":"Invalid category."}', 400),
    http.Response('[]', 200),
  ]) {
    test(
      'handles unavailable, denied or malformed service (${response.statusCode}: ${response.body})',
      () async {
        final service = ProviderService(
          client: MockClient((_) async => response),
        );
        addTearDown(service.close);
        await expectLater(service.load(), throwsA(isA<ProviderApiException>()));
      },
    );
  }
}
