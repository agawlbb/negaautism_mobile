import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:negaautism_mobile/user_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved profile and notification preferences remain readable', () async {
    SharedPreferences.setMockInitialValues({
      'username': 'fixture-user',
      'email': 'fixture@example.invalid',
      'user_type': 'fixture-type',
      'specialty': 'fixture-specialty',
      'clinic': 'fixture-clinic',
      'allowed_notifications': jsonEncode({'fixture': 'Fixture notification'}),
      'notification_fixture': true,
      'buildVersion': 20100,
    });
    final service = UserInfoService();
    final profile = await service.getUserInfoFromPreferences();
    expect(profile['username'], 'fixture-user');
    expect(profile['email'], 'fixture@example.invalid');
    expect(profile['user_type'], 'fixture-type');
    expect(profile['specialty'], 'fixture-specialty');
    expect(profile['clinic'], 'fixture-clinic');
    expect(await service.getAllowedNotifications(), {'fixture': 'Fixture notification'});
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('notification_fixture'), isTrue);
    expect(preferences.getInt('buildVersion'), 20100);
  });

  test('empty preferences preserve profile defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final service = UserInfoService();
    expect((await service.getUserInfoFromPreferences())['username'], 'unknown user');
    expect(await service.getAllowedNotifications(), isEmpty);
  });
}
