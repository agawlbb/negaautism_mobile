import 'package:firebase_messaging/firebase_messaging.dart';

import 'vps_api.dart';

class NotificationService {
  Future<void> submitNotifications(
    Map<String, bool> notificationToggles,
  ) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const VpsApiException('Device notifications are unavailable.');
    }
    final api = VpsApi();
    try {
      await api.request(
        'PUT',
        'notifications',
        body: {
          'fcm_token': token,
          'requested_notifications': [
            for (final item in notificationToggles.entries)
              if (item.value) int.parse(item.key),
          ],
        },
      );
    } finally {
      api.close();
    }
  }
}
