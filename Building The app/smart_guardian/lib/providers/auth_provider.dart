import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_role.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  UserRole _selectedRole = UserRole.patient;
  bool _isLoading = false;
  String? _errorMessage;

  UserRole get selectedRole => _selectedRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (email.trim().isEmpty || password.isEmpty) {
        _errorMessage = 'Please enter both email and password';
        return false;
      }

      // 1. Firebase email/password login
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        _errorMessage = 'Login failed. Please try again.';
        return false;
      }

      // Refresh Firebase user information
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        _errorMessage = 'Login failed. Please try again.';
        return false;
      }

      // 2. Require email verification
      if (!refreshedUser.emailVerified) {
        await FirebaseAuth.instance.signOut();

        _errorMessage =
            'Please verify your email before logging in. Check your inbox.';

        return false;
      }

      // 3. Get user's Firestore profile
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshedUser.uid)
          .get();

      // 4. Profile must exist
      if (!profileDoc.exists) {
        await FirebaseAuth.instance.signOut();

        _errorMessage =
            'User profile not found. Please contact the administrator.';

        return false;
      }

      // 5. Read actual role from Firestore
      final data = profileDoc.data();
      final role = data?['role'];

      if (role != 'patient' && role != 'guardian') {
        await FirebaseAuth.instance.signOut();

        _errorMessage =
            'Invalid user role. Please contact the administrator.';

        return false;
      }

      final userRole =
          role == 'patient' ? UserRole.patient : UserRole.guardian;

      // 6. Compare selected UI role with actual Firestore role
      if (userRole != _selectedRole) {
        await FirebaseAuth.instance.signOut();

        _errorMessage =
            'This account is registered as ${userRole.label}. '
            'Please select ${userRole.label} and try again.';

        return false;
      }

      // 7. Login successful
      _selectedRole = userRole;

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('LOGIN ERROR: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          _errorMessage = 'Invalid email or password';
          break;

        case 'invalid-email':
          _errorMessage = 'Invalid email address';
          break;

        case 'user-disabled':
          _errorMessage = 'This account has been disabled';
          break;

        case 'too-many-requests':
          _errorMessage =
              'Too many attempts. Please try again later.';
          break;

        default:
          _errorMessage = e.message ?? 'Login failed';
      }

      return false;
    } on FirebaseException catch (e) {
      debugPrint(
        'FIRESTORE LOGIN ERROR: ${e.code} - ${e.message}',
      );

      _errorMessage =
          'Could not read your user profile. Please try again.';

      return false;
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      _errorMessage =
          'Something went wrong. Please try again.';

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // CREATE ACCOUNT USING EMAIL VERIFICATION
  // ============================================================

  Future<bool> createAccount({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    User? user;

    try {
      // 1. Create Firebase Authentication account
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      user = credential.user;

      if (user == null) {
        _errorMessage =
            'Could not create your account. Please try again.';
        return false;
      }

      // 2. Store user's name in Firebase Auth
      await user.updateDisplayName(name.trim());


      // 3. Create Firestore profile FIRST
      final profile = UserProfile(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        role: _selectedRole.name,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profile.toMap());

      // 4. NOW send verification email
      debugPrint('>>> BEFORE sendEmailVerification');

      await user.sendEmailVerification();

      debugPrint('>>> AFTER sendEmailVerification');


      // 5. Sign out until email is verified
      await FirebaseAuth.instance.signOut();

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'CREATE ACCOUNT ERROR: ${e.code} - ${e.message}',
      );

      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage =
              'This email is already registered. Please log in.';

          break;

        case 'invalid-email':
          _errorMessage =
              'Please enter a valid email address.';

          break;

        case 'weak-password':
          _errorMessage =
              'Password is too weak. Use at least 8 characters.';

          break;

        case 'operation-not-allowed':
          _errorMessage =
              'Email/password authentication is not enabled in Firebase.';

          break;

        case 'network-request-failed':
          _errorMessage =
              'No internet connection. Please try again.';

          break;

        case 'too-many-requests':
          _errorMessage =
              'Too many attempts. Please try again later.';

          break;

        default:
          _errorMessage =
              e.message ?? 'Could not create account.';
      }

      return false;
    } on FirebaseException catch (e) {
      debugPrint(
        'FIRESTORE CREATE ACCOUNT ERROR: ${e.code} - ${e.message}',
      );

      // If Firebase Auth account was created but Firestore failed,
      // remove the incomplete account.
      if (user != null) {
        try {
          await user.delete();
        } catch (_) {}
      }

      _errorMessage =
          'Account could not be saved. Please try again.';

      return false;
    } catch (e) {
      debugPrint('CREATE ACCOUNT ERROR: $e');

      _errorMessage =
          'Something went wrong. Please try again.';

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // RESEND EMAIL VERIFICATION
  // ============================================================

  Future<bool> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _errorMessage = 'Please create your account again.';
        return false;
      }

      await user.sendEmailVerification();

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage =
          e.message ?? 'Could not send verification email.';
      return false;
    }
  }


  
// ============================================================
// REFRESH EMAIL VERIFICATION STATUS
// ============================================================

Future<bool> refreshEmailVerification() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _errorMessage = 'Please create your account again.';
      return false;
    }

    await user.reload();

    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser?.emailVerified == true) {
      _errorMessage = null;
      return true;
    }

    _errorMessage =
        'Email is not verified yet. Please check your inbox.';
    return false;
  } on FirebaseAuthException catch (e) {
    _errorMessage =
        e.message ?? 'Could not check email verification.';
    return false;
  } catch (e) {
    _errorMessage = 'Something went wrong. Please try again.';
    return false;
  }
}


  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyAuthError(e);
      return false;
    } catch (_) {
      _errorMessage =
          'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';

      case 'user-not-found':
        return 'No account exists with this email.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'No internet connection.';

      default:
        return e.message ?? 'Something went wrong.';
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    _errorMessage = null;
    _isLoading = false;

    notifyListeners();
  }
}