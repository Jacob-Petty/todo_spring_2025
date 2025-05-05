import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home/home_screen.dart';
import 'calendar/calendar_screen.dart';
import 'login/login_screen.dart';
import 'settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TODO Spring 2025',
      themeMode: _themeMode,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.light(
          background: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
        ),
        textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          background: Colors.black,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.sairaCondensedTextTheme(ThemeData.dark().textTheme),
      ),
      initialRoute: FirebaseAuth.instance.currentUser == null ? '/login' : '/home',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
