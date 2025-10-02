import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart'; // Firebase Messaging
import 'login_screen.dart'; // Import the LoginScreen
import 'user_info_service.dart'; // Import the UserInfoService
import 'notifications_screen.dart'; // Import the NotificationsScreen
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manage_events_screen.dart'; // <-- NEW: Manage Events screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserInfoService _userInfoService = UserInfoService();
  User? _user;
  String? _userInfoDisplay;
  bool _hasAllowedNotifications = false;

  @override
  void initState() {
    super.initState();
    _checkAppVersion();
    _user = _auth.currentUser;

    if (_user != null) {
      _loadUserData();
    }

    // Initialize Firebase Messaging for handling foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotificationPopup(message);
    });
  }

  Future<void> _checkAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentBuildVersion = packageInfo.buildNumber;
    prefs.setInt('buildVersion', int.parse(currentBuildVersion));
  }

  // Show a notification popup if the app is in the foreground
  void _showNotificationPopup(RemoteMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message.notification?.title ?? "Notification"),
          content: Text(message.notification?.body ?? "You have a new notification."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadUserData() async {
    try {
      await _loadUserInfo();
      await _checkAllowedNotifications();
      if (mounted) {
        setState(() {}); // Rebuild the widget after data is loaded
      }
    } catch (e) {
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        _setUserName();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not connect to server.')),
          );
        }
      } else {
        // Display the error message instead of rethrowing
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadUserInfo() async {
    await _userInfoService.fetchAndStoreUserInfo(); // Fetch and store info
    await _setUserName();
  }

  Future<void> _setUserName() async {
    final userInfo = await _userInfoService.getUserInfoFromPreferences(); // Load from SharedPreferences
    if (mounted) {
      setState(() {
        _userInfoDisplay = 'Welcome ${userInfo['username']}';
      });
    }
  }

  Future<void> _checkAllowedNotifications() async {
    final notifications = await _userInfoService.getAllowedNotifications();
    if (mounted) {
      setState(() {
        _hasAllowedNotifications = notifications.isNotEmpty;
      });
    }
  }

  void _signOut() async {
    await _auth.signOut();
    if (mounted) {
      setState(() {
        _user = null;
        _userInfoDisplay = null;
        _hasAllowedNotifications = false;
      });
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? shouldSignOut = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Dismiss the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm sign out
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      _signOut();
    }
  }

  void _onLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    ).then((_) async {
      _user = _auth.currentUser;
      if (_user != null) {
        await _loadUserInfo();
        await _checkAllowedNotifications();
        if (mounted) {
          setState(() {}); // Rebuild the widget after login and data fetch
        }
      } else {
        if (mounted) {
          setState(() {}); // User is null, still need to rebuild
        }
      }
    });
  }

  void _openManagerEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageEventsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('negaautism.org Mobile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'login') {
                _onLogin();
              } else if (value == 'logout') {
                _confirmSignOut(context);
              } else if (value == 'notifications') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: _user == null ? 'login' : 'logout',
                  child: Text(_user == null ? 'Login' : 'Logout'),
                ),
                if (_user != null && _hasAllowedNotifications)
                  const PopupMenuItem(
                    value: 'notifications',
                    child: Text('Manage Notifications'),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Aligns to the left
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the text
            child: Text(
              _userInfoDisplay ?? '', // Display user info at the top left
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // Full-width pink "Manager events" button under the welcome line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openManagerEvents, // opens the new screen
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Manager events',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Center(
              child: _user == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('You are not logged in.'), // Display the message
                  const SizedBox(height: 16), // Add space between the text and button
                  ElevatedButton(
                    onPressed: () {
                      _onLogin();
                    },
                    child: const Text('Login'), // Display login button
                  ),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
