import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // Import the LoginScreen

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
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser; // Check if the user is already logged in
  }

  void _signOut() async {
    await _auth.signOut();
    setState(() {
      _user = null;
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
                    _user = _auth.currentUser; // Refresh after login
                  });
                });
              } else if (value == 'logout') {
                _confirmSignOut(context); // Show the confirmation dialog
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: _user == null ? 'login' : 'logout',
                  child: Text(_user == null ? 'Login' : 'Logout'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Center(
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
                    _user = _auth.currentUser; // Refresh after login
                  });
                });
              },
              child: Text('Login'), // Display login button
            ),
          ],
        )
            : Text('Welcome, ${_user?.email}'),
      ),
    );
  }
}
