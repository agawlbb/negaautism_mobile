import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart'; // Import the new NotificationService
import 'user_info_service.dart'; // Import UserInfoService to access notifications

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  final UserInfoService _userInfoService = UserInfoService();
  final NotificationService _notificationService = NotificationService(); // Initialize NotificationService
  Map<String, String> _notifications = {};
  Map<String, bool> _notificationToggles = {};
  bool isSubmitting = false;

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

  void _submitNotifications() async {
    setState(() {
      isSubmitting = true;
    });

    // Call the submitNotifications function from NotificationService
    try {
      await _notificationService.submitNotifications(_notificationToggles);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Notifications requested"),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), // Display the error
        ));
      }
    }

    setState(() {
      isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Notifications'),
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
              onPressed: isSubmitting ? null : _submitNotifications,
              child: isSubmitting
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
