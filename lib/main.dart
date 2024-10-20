import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'login_screen.dart'; // Import the LoginScreen
import 'user_info_service.dart'; // Import the UserInfoService
import 'notifications_screen.dart'; // Import the NotificationsScreen

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
    _user = _auth.currentUser;

    if (_user != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      await _loadUserInfo();
      await _checkAllowedNotifications();
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
    _setUserName();
  }

  Future<void> _setUserName() async {
    final userInfo = await _userInfoService.getUserInfoFromPreferences(); // Load from SharedPreferences
    setState(() {
      _userInfoDisplay = 'Welcome ${userInfo['username']}';
    });
  }

  Future<void> _checkAllowedNotifications() async {
    final notifications = await _userInfoService.getAllowedNotifications();
    if (notifications.isNotEmpty) {
      setState(() {
        _hasAllowedNotifications = true;
      });
    }
  }

  void _signOut() async {
    await _auth.signOut();
    setState(() {
      _user = null;
      _userInfoDisplay = null;
      _hasAllowedNotifications = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('negaautism.org Mobile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'login') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) {
                  setState(() {
                    _user = _auth.currentUser;
                    if (_user != null) {
                      _loadUserInfo(); // Reload user info after login
                      _checkAllowedNotifications(); // Check notifications
                    }
                  });
                });
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
                if (_user != null && _hasAllowedNotifications) // Show notifications link if allowed
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      ).then((_) {
                        setState(() {
                          _user = _auth.currentUser;
                          if (_user != null) {
                            _loadUserInfo(); // Reload user info after login
                            _checkAllowedNotifications(); // Check notifications
                          }
                        });
                      });
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
