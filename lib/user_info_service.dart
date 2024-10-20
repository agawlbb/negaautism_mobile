import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserInfoService {
  // Fetches user info from the API and stores it in SharedPreferences
  Future<void> fetchAndStoreUserInfo() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final User? user = _auth.currentUser;

    if (user != null) {
      try {
        String? idToken = await user.getIdToken();
        if (idToken != null) {
          // Make API call
          final response = await http.post(
            Uri.parse('https://negaautism.org/api/get_user_info.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'idToken': idToken},
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(response.body);
            if (!data.containsKey('error')) {
              // Save the user info in SharedPreferences
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('username', data['username']);
              await prefs.setString('email', data['email']);
              await prefs.setString('user_type', data['user_type']);
              await prefs.setString('specialty', data['specialty'] ?? '');
              await prefs.setString('clinic', data['clinic'] ?? '');

              // Save allowed_notifications as a JSON string
              Map<String, String> notifications = Map<String, String>.from(data['allowed_notifications']);
              await prefs.setString('allowed_notifications', jsonEncode(notifications));
            } else {
              print('Error fetching user info: ${data['error']}');
            }
          } else {
            print('Failed to fetch user info: ${response.body}');
          }
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  // Retrieves stored user info from SharedPreferences
  Future<Map<String, String?>> getUserInfoFromPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString('username'),
      'email': prefs.getString('email'),
      'user_type': prefs.getString('user_type'),
      'specialty': prefs.getString('specialty'),
      'clinic': prefs.getString('clinic'),
    };
  }

  // Retrieves allowed notifications from SharedPreferences
  Future<Map<String, String>> getAllowedNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? notificationsString = prefs.getString('allowed_notifications');
    if (notificationsString != null) {
      Map<String, String> notifications = Map<String, String>.from(jsonDecode(notificationsString));
      return notifications;
    }
    return {};
  }
}
