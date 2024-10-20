import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> submitNotifications(Map<String, bool> notificationToggles) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? idToken = await user.getIdToken();
        String? fcmToken = await _firebaseMessaging.getToken(); // Get the actual FCM token

        // Prepare the array of requested notifications
        List<int> requestedNotifications = [];
        notificationToggles.forEach((key, value) {
          if (value) {
            requestedNotifications.add(int.parse(key));
          }
        });

        // Prepare the JSON body
        Map<String, dynamic> requestBody = {
          'auth_token': idToken,
          'fcm_token': fcmToken, // Send the actual FCM token
          'requested_notifications': requestedNotifications.isNotEmpty
              ? requestedNotifications
              : null, // Optional field, omit if empty
        };

        // Make the API call
        final response = await http.post(
          Uri.parse('https://negaautism.org/api/register_notifications.php'),
          headers: {'Content-Type': 'application/json'}, // Set header to JSON
          body: jsonEncode(requestBody), // Send body as JSON
        );

        if (response.statusCode != 200) {
          throw Exception('Error submitting notifications: ${response.body}');
        }
      } else {
        throw Exception('User is not authenticated.');
      }
    } catch (e) {
      throw Exception('Error submitting notifications: $e');
    }
  }
}
