import 'dart:convert';

import 'vps_api.dart';

import 'package:shared_preferences/shared_preferences.dart';

class UserInfoService {
  final VpsApi? api;
  UserInfoService({this.api});
  // The VPS client validates sign-in and refreshes the token for this request.
  Future<void> fetchAndStoreUserInfo() async {
    final api = this.api ?? VpsApi();
    try {
      final data = await api.request('GET', 'me');
      final preferences = await SharedPreferences.getInstance();
      for (final key in [
        'username',
        'email',
        'user_type',
        'specialty',
        'clinic',
      ]) {
        await preferences.setString(key, data[key] as String? ?? '');
      }
      final notifications = Map<String, String>.from(
        data['allowed_notifications'] as Map,
      );
      await preferences.setString(
        'allowed_notifications',
        jsonEncode(notifications),
      );
    } finally {
      if (this.api == null) api.close();
    }
  }

  Future<Map<String, String?>> getUserInfoFromPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'username':
          prefs.getString('username') ??
          'unknown user', // Default to "unknown user"
      'email': prefs.getString('email') ?? '', // Default to empty string
      'user_type':
          prefs.getString('user_type') ?? '', // Default to empty string
      'specialty':
          prefs.getString('specialty') ?? '', // Default to empty string
      'clinic': prefs.getString('clinic') ?? '', // Default to empty string
    };
  }

  // Retrieves allowed notifications from SharedPreferences
  Future<Map<String, String>> getAllowedNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? notificationsString = prefs.getString('allowed_notifications');
    if (notificationsString != null) {
      Map<String, String> notifications = Map<String, String>.from(
        jsonDecode(notificationsString),
      );
      return notifications;
    }
    return {};
  }
}
