import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // Import the LoginScreen
import 'user_info_service.dart'; // Import the UserInfoService
import 'notifications_screen.dart'; // Import the NotificationsScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      _loadUserInfo(); // Load user info from the API or SharedPreferences
      _checkAllowedNotifications(); // Check if there are any allowed notifications
    }
  }

  Future<void> _loadUserInfo() async {
    await _userInfoService.fetchAndStoreUserInfo(); // Fetch and store info
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
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Dismiss the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm sign out
              },
              child: Text('Logout'),
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
        title: Text('negaautism.org Mobile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'login') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
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
                  MaterialPageRoute(builder: (context) => NotificationsScreen()),
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
                  PopupMenuItem(
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Center(
              child: _user == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('You are not logged in.'), // Display the message
                  SizedBox(height: 16), // Add space between the text and button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
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
                    child: Text('Login'), // Display login button
                  ),
                ],
              )
                  : SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
