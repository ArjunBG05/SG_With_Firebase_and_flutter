import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/patient_home_screen.dart';
import 'screens/guardian_home_screen.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, authSnapshot) {
        // Firebase checking authentication
        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is NOT logged in
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        // ------------------------------------------------
        // EMAIL VERIFICATION CHECK
        // ------------------------------------------------

        if (!user.emailVerified) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        // ------------------------------------------------
        // GET ROLE FROM FIRESTORE
        // ------------------------------------------------

        return FutureBuilder<String?>(
          future: _getUserRole(user.uid),

          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final role = roleSnapshot.data;

            // Profile may not exist yet while a new account is being created.
            if (role == null) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Patient
            if (role == 'patient') {
              return const PatientHomeScreen();
            }

            // Guardian
            if (role == 'guardian') {
              return const GuardianHomeScreen();
            }

            // Unknown role
            FirebaseAuth.instance.signOut();

            return const LoginScreen();
          },
        );
      },
    );
  }
}