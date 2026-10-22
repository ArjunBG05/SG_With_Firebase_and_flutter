import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/register_validators.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone; // full number, e.g. +919000000001
  final String name;
  final String email;
  final String password;

  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  Timer? _timer;
  int _seconds = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    final ok = await auth.verifyOtpAndCreateAccount(
      name: widget.name,
      email: widget.email,
      password: widget.password,
      smsCode: _otpController.text.trim(),
    );
    if (!mounted) return;

    if (ok) {
      _toast('Account created successfully!');
      // Back to Wrapper, which reads the Firebase login and shows the
      // existing Patient / Guardian dashboard.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      if (auth.errorMessage != null) _toast(auth.errorMessage!);
      // OTP already used (e.g. email taken) -> back to the form
      if (auth.registrationNeedsRestart) Navigator.of(context).pop();
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendRegistrationOtp(widget.phone);
    if (!mounted) return;
    if (ok) {
      _startTimer();
      _toast('OTP sent again');
    } else if (auth.errorMessage != null) {
      _toast(auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Enter the 6-digit code sent by SMS to ${widget.phone}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), counterText: ''),
                    validator: RegisterValidators.otp,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _verify,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify & create account'),
                  ),
                  TextButton(
                    onPressed:
                        (_seconds == 0 && !auth.isLoading) ? _resend : null,
                    child: Text(_seconds == 0
                        ? 'Resend OTP'
                        : 'Resend in ${_seconds}s'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}