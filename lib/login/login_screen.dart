import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_button/sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    // Prevent concurrent sign-in attempts
    if (_isSigningIn) return;

    try {
      setState(() {
        _isSigningIn = true;
      });

      // Initialize GoogleSignIn instance
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);

      // Attempt to sign in
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        // User canceled the sign-in flow
        return;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);

      // You can add navigation here if sign-in is successful
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (error) {
      // Handle and display the error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${error.toString()}')),
        );
      }
    } finally {
      // Reset the signing in state
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SizedBox(
          height: 48,
          child: _isSigningIn
              ? const CircularProgressIndicator() // Show loading indicator
              : SignInButton(
            Buttons.google,
            onPressed: _handleGoogleSignIn,
          ),
        ),
      ),
    );
  }
}