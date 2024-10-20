import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'user_info_service.dart'; // Import UserInfoService to access notifications

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final UserInfoService _userInfoService = UserInfoService();
  Map<String, String> _notifications = {};
  Map<String, bool> _notificationToggles = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await _userInfoService.getAllowedNotifications();
    setState(() {
      _notifications = notifications;
      _notificationToggles = {for (var key in notifications.keys) key: false}; // Default to off
      _loadToggleState(); // Load saved toggle states
    });
  }

  Future<void> _loadToggleState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _notificationToggles.forEach((key, _) {
      setState(() {
        _notificationToggles[key] = prefs.getBool('notification_$key') ?? false; // Load saved states
      });
    });
  }

  Future<void> _saveToggleState(String key, bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_$key', value); // Save state in SharedPreferences
  }

  Future<void> _submitNotifications() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? idToken = await user.getIdToken();

        // Prepare the array of requested notifications
        List<int> requestedNotifications = [];
        _notificationToggles.forEach((key, value) {
          if (value) {
            requestedNotifications.add(int.parse(key));
          }
        });

        // Prepare the JSON body
        Map<String, dynamic> requestBody = {
          'auth_token': idToken,
          'fcm_token': 'test', // For now, send the test FCM token
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

        if (response.statusCode == 200) {
          // Handle successful submission
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Notifications updated successfully.'),
          ));
        } else {
          // Handle error
          print('Error submitting notifications: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error submitting notifications.'),
          ));
        }
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error submitting notifications.'),
      ));
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Notifications'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                String key = _notifications.keys.elementAt(index);
                String notificationText = _notifications[key]!;
                return SwitchListTile(
                  title: Text(notificationText),
                  value: _notificationToggles[key] ?? false,
                  onChanged: (bool value) {
                    setState(() {
                      _notificationToggles[key] = value;
                    });
                    _saveToggleState(key, value); // Save the new state
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitNotifications,
              child: _isSubmitting
                  ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
