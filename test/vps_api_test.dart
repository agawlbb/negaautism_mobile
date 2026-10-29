import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:negaautism_mobile/vps_api.dart';
import 'package:negaautism_mobile/user_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'refreshes credentials for each call and keeps tokens out of URL/body',
    () async {
      var refreshed = 0;
      final api = VpsApi(
        token: () async => 'fresh-${++refreshed}',
        client: MockClient((r) async {
          expect(r.url.host, 'vps.negaautism.org');
          expect(r.headers['Authorization'], 'Bearer fresh-$refreshed');
          expect(r.url.toString(), isNot(contains('fresh-')));
          expect(r.body, isNot(contains('fresh-')));
          return http.Response('{"success":true}', 200);
        }),
      );
      await api.request('GET', 'me');
      await api.request(
        'PUT',
        'notifications',
        body: {'fcm_token': 'synthetic', 'requested_notifications': []},
      );
      expect(refreshed, 2);
      api.close();
    },
  );
  test('rejects missing sign-in before sending', () async {
    var requests = 0;
    final api = VpsApi(
      token: () async => null,
      client: MockClient((r) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.request('GET', 'me'),
      throwsA(isA<VpsApiException>()),
    );
    expect(requests, 0);
    api.close();
  });
  test(
    'does not retry failed writes or treat application failure as success',
    () async {
      var requests = 0;
      final api = VpsApi(
        token: () async => 'synthetic',
        client: MockClient((r) async {
          requests++;
          return http.Response('{"success":false,"message":"Denied"}', 403);
        }),
      );
      await expectLater(
        api.request('POST', 'events', body: {'name': 'Example'}),
        throwsA(isA<VpsApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(requests, 1);
      api.close();
    },
  );
  test('profile preserves saved preference field formats', () async {
    SharedPreferences.setMockInitialValues({});
    final api = VpsApi(
      token: () async => 'synthetic',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'success': true,
            'username': 'Example',
            'email': 'test@example.invalid',
            'user_type': 'parent',
            'specialty': null,
            'clinic': null,
            'allowed_notifications': {'2': 'New review posted'},
          }),
          200,
        ),
      ),
    );
    final service = UserInfoService(api: api);
    await service.fetchAndStoreUserInfo();
    expect((await service.getUserInfoFromPreferences())['username'], 'Example');
    expect(await service.getAllowedNotifications(), {'2': 'New review posted'});
    api.close();
  });
}
