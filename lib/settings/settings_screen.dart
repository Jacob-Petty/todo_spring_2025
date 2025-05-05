import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // Import to access MyApp.of(context)

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isDarkMode = brightness == Brightness.dark;
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });

    final themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    MyApp.of(context)?.setThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        title: const Text('Settings'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.background),
              child: Text(
                'Options',
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Theme.of(context).colorScheme.onBackground),
              title: Text('Home', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onBackground),
              title: Text('Calendar', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/calendar');
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.onBackground),
              title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
            title: Text('Profile', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            onTap: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();

                final dateJoined = userDoc.exists && userDoc.data() != null
                    ? (userDoc.data()!['createdAt'] as Timestamp?)?.toDate()
                    : null;

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Profile Information'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: ${user.email ?? 'N/A'}'),
                        Text(
                          'Date Joined: ${dateJoined != null ? DateFormat.yMMMd().format(dateJoined) : 'N/A'}',
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: Icon(Icons.brightness_6, color: Theme.of(context).colorScheme.onSurface),
            title: Text('Dark Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: _toggleTheme,
              activeColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.onSurface),
            title: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }
}

