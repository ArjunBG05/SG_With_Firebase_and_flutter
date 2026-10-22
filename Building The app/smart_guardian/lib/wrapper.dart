
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/patient_home_screen.dart';
import 'screens/guardian_home_screen.dart';

// ------------------------------------------------
// WRAPPER CLASS
// ------------------------------------------------
// Decides which screen the user should see:
// Login, Email Verification, Patient Dashboard,
// Guardian Dashboard, or a Recovery/Error screen.
class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  // ------------------------------------------------
  // GET USER ROLE FROM FIRESTORE
  // ------------------------------------------------
  // Reads users/{uid} and returns the user's role.
  // Expected values: "patient" or "guardian".
  // Returns null if the profile does not exist.
  Future<String?> _getUserRole(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data()?['role'] as String?;
  }

  // ------------------------------------------------
  // BUILD METHOD
  // ------------------------------------------------
  // Flutter calls build() to decide what UI to display.
  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------
    // AUTHENTICATION STATE CHECK
    // ------------------------------------------------
    // Listens for Firebase login/logout and user changes.
    // userChanges() can also emit updates after reloading
    // the Firebase user, such as checking email verification.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),

      builder: (context, authSnapshot) {
        // ------------------------------------------------
        // 1. WAITING FOR FIREBASE AUTHENTICATION
        // ------------------------------------------------
        // Show a spinner while Firebase checks the session.
        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ------------------------------------------------
        // 2. AUTHENTICATION STREAM ERROR
        // ------------------------------------------------
        // Show an error screen instead of waiting forever.
        if (authSnapshot.hasError) {
          return const _RecoveryScreen(
            message:
                'Could not check your login status. '
                'Please sign in again.',
          );
        }

        // ------------------------------------------------
        // 3. USER NOT LOGGED IN
        // ------------------------------------------------
        // No Firebase user means the login screen is shown.
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // Firebase user exists, so get the current user.
        final user = authSnapshot.data!;

        // ------------------------------------------------
        // 4. EMAIL VERIFICATION CHECK
        // ------------------------------------------------
        // An unverified user must verify their email first.
        // Show the verification screen, not an endless spinner.
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }

        // ------------------------------------------------
        // 5. GET USER ROLE FROM FIRESTORE
        // ------------------------------------------------
        // Only verified, logged-in users reach this section.
        // Fetch their role to choose the correct dashboard.
        return FutureBuilder<String?>(
          future: _getUserRole(user.uid),

          builder: (context, roleSnapshot) {
            // ------------------------------------------------
            // 5A. WAITING FOR FIRESTORE PROFILE
            // ------------------------------------------------
            if (roleSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // ------------------------------------------------
            // 5B. FIRESTORE ERROR
            // ------------------------------------------------
            // For example, permission denied or network failure.
            if (roleSnapshot.hasError) {
              return _RecoveryScreen(
                message:
                    'Could not load your Firestore profile.\n\n'
                    'Details: ${roleSnapshot.error}',
              );
            }

            // Get the role returned by Firestore.
            final role = roleSnapshot.data;

            // ------------------------------------------------
            // 6. PATIENT DASHBOARD
            // ------------------------------------------------
            if (role == 'patient') {
              return const PatientHomeScreen();
            }

            // ------------------------------------------------
            // 7. GUARDIAN DASHBOARD
            // ------------------------------------------------
            if (role == 'guardian') {
              return const GuardianHomeScreen();
            }

            // ------------------------------------------------
            // 8. PROFILE MISSING OR INVALID ROLE
            // ------------------------------------------------
            // Expected role values are "patient" or "guardian".
            // Display a useful message instead of a spinner.
            return _RecoveryScreen(
              message: role == null
                  ? 'Your user profile was not found, or its role '
                      'is missing.\n\n'
                      'Check Firestore: users/${user.uid}\n'
                      'The role must be "patient" or "guardian".'
                  : 'Invalid user role: $role\n\n'
                      'Expected "patient" or "guardian".',
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------
// RECOVERY / ERROR SCREEN
// ------------------------------------------------
// Displays an explanation when the wrapper cannot decide
// which dashboard to open. Provides a way to return to login.
class _RecoveryScreen extends StatelessWidget {
  final String message;

  const _RecoveryScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Guardian'),
      ),

      // ------------------------------------------------
      // ERROR MESSAGE AND LOGOUT BUTTON
      // ------------------------------------------------
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.red,
              ),
              const SizedBox(height: 16),

              const Text(
                'Unable to open your dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Shows the actual reason for the problem.
              SelectableText(
                message,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Signs the user out and returns to LoginScreen.
              FilledButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
