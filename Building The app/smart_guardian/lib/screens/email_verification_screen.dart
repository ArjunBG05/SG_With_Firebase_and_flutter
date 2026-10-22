import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  Timer? _timer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 30;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _checkVerification() async {
    final auth = context.read<AuthProvider>();
    final verified = await auth.refreshEmailVerification();

    if (!mounted) return;

    if (verified) {
      _showMessage('Email verified! Opening your dashboard...');
    } else {
      _showMessage(
        auth.errorMessage ?? 'Email is not verified yet. Please try again.',
      );
    }
  }

  Future<void> _resendEmail() async {
    if (_secondsRemaining > 0) return;

    final auth = context.read<AuthProvider>();
    final sent = await auth.resendVerificationEmail();

    if (!mounted) return;

    if (sent) {
      _startCountdown();
      _showMessage(
        'Verification email sent. Check your inbox and spam folder.',
      );
    } else {
      _showMessage(
        auth.errorMessage ?? 'Could not resend the verification email.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'your email address';

    final canResend = _secondsRemaining == 0 && !auth.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: auth.isLoading
                ? null
                : () => auth.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 76,
                ),
                const SizedBox(height: 24),
                Text(
                  'Check your inbox',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to:\n$email\n\n'
                  'Open the email and tap the verification link. '
                  'Then return here and check your verification status. '
                  'If you cannot find the email, check your spam folder.',
                  textAlign: TextAlign.center,
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    auth.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed:
                      auth.isLoading ? null : _checkVerification,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('I have verified my email'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: canResend ? _resendEmail : null,
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  label: Text(
                    _secondsRemaining > 0
                        ? 'Resend email in ${_secondsRemaining}s'
                        : 'Resend verification email',
                  ),
                ),
                if (auth.isLoading) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
