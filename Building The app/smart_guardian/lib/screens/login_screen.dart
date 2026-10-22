import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import 'patient_home_screen.dart';
import 'guardian_home_screen.dart';
import 'help_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  static const Color _background = Color(0xFFEEF5F1);
  static const Color _darkTeal = Color(0xFF123D3D);
  static const Color _green = Color(0xFF08785F);
  static const Color _deepGreen = Color(0xFF126B55);
  static const Color _muted = Color(0xFF607C80);
  static const Color _outline = Color(0xFF557B78);
  static const Color _paleGreen = Color(0xFFD1EAE0);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => auth.selectedRole == UserRole.patient
              ? const PatientHomeScreen()
              : const GuardianHomeScreen(),
        ),
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _muted,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: _muted, size: 25),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.32),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _outline, width: 1.35),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _green, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFC24B4B), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFC24B4B), width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Container(
          color: _background,
          child: Scaffold(
            backgroundColor: _background,
            appBar: AppBar(
              backgroundColor: _background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 54,
              titleSpacing: 18,
              title: const Text(
                'Smart Guardian',
                style: TextStyle(
                  color: _darkTeal,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    tooltip: 'Help',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: _darkTeal,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 690;
                final veryCompact = constraints.maxHeight < 610;
                final horizontalPadding = screenWidth < 360 ? 14.0 : 20.0;

                // Scale the complete form down when needed, rather than making
                // the user scroll on common phone screen sizes.
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    2,
                    horizontalPadding,
                    8,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: (constraints.maxWidth - horizontalPadding * 2)
                            .clamp(250.0, 520.0)
                            .toDouble(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: veryCompact ? 0 : (compact ? 2 : 5)),
                              SizedBox(
                                height: veryCompact ? 76 : (compact ? 88 : 100),
                                child: Center(
                                  child: SizedBox(
                                    width: veryCompact ? 78 : (compact ? 88 : 98),
                                    height: veryCompact ? 76 : (compact ? 88 : 100),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: veryCompact ? 76 : (compact ? 86 : 98),
                                          color: const Color(0xFF32977C),
                                        ),
                                        Positioned(
                                          top: veryCompact ? 15 : (compact ? 18 : 21),
                                          child: Icon(
                                            Icons.person,
                                            size: veryCompact ? 27 : (compact ? 31 : 35),
                                            color: const Color(0xFF08785F),
                                          ),
                                        ),
                                        Positioned(
                                          top: veryCompact ? 37 : (compact ? 42 : 47),
                                          child: Icon(
                                            Icons.favorite,
                                            size: veryCompact ? 24 : (compact ? 27 : 30),
                                            color: Colors.amber.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 4 : 7),
                              Text(
                                'Your health, your\npeace of mind',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _darkTeal,
                                  fontSize: veryCompact ? 23 : (compact ? 25 : 28),
                                  height: 1.08,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: compact ? 5 : 8),
                              Text(
                                'Sign in to stay connected and cared for.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: veryCompact ? 12 : (compact ? 13 : 14),
                                  height: 1.25,
                                ),
                              ),
                              SizedBox(height: veryCompact ? 14 : (compact ? 17 : 24)),
                              Text(
                                'I am signing in as',
                                style: TextStyle(
                                  color: _darkTeal,
                                  fontSize: compact ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: compact ? 6 : 9),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: _outline, width: 1.6),
                                  borderRadius: BorderRadius.circular(36),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: SegmentedButton<UserRole>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment<UserRole>(
                                      value: UserRole.patient,
                                      label: Text('Patient'),
                                      icon: Icon(Icons.person_outline_rounded),
                                    ),
                                    ButtonSegment<UserRole>(
                                      value: UserRole.guardian,
                                      label: Text('Guardian'),
                                      icon: Icon(Icons.shield_outlined),
                                    ),
                                  ],
                                  selected: {auth.selectedRole},
                                  onSelectionChanged: (selection) =>
                                      auth.setRole(selection.first),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: compact ? 8 : 11,
                                      ),
                                    ),
                                    foregroundColor: WidgetStateProperty.resolveWith(
                                      (states) => states.contains(WidgetState.selected)
                                          ? _deepGreen
                                          : _muted,
                                    ),
                                    backgroundColor: WidgetStateProperty.resolveWith(
                                      (states) => states.contains(WidgetState.selected)
                                          ? _paleGreen
                                          : Colors.white.withValues(alpha: 0.18),
                                    ),
                                    textStyle: WidgetStateProperty.all(
                                      TextStyle(
                                        fontSize: compact ? 13 : 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    side: WidgetStateProperty.all(BorderSide.none),
                                    shape: WidgetStateProperty.all(
                                      const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 12 : 17),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Text(
                                  'Email address',
                                  style: TextStyle(
                                    color: _deepGreen,
                                    fontSize: compact ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: Validators.email,
                                decoration: _fieldDecoration(
                                  hint: 'Enter your email',
                                  icon: Icons.mail_outline_rounded,
                                ).copyWith(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: compact ? 12 : 15,
                                  ),
                                  isDense: true,
                                ),
                              ),
                              SizedBox(height: compact ? 9 : 13),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Text(
                                  'Password',
                                  style: TextStyle(
                                    color: _deepGreen,
                                    fontSize: compact ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) {
                                  if (!auth.isLoading) _handleLogin(auth);
                                },
                                validator: Validators.password,
                                decoration: _fieldDecoration(
                                  hint: 'Enter your password',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: _muted,
                                    ),
                                  ),
                                ).copyWith(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: compact ? 12 : 15,
                                  ),
                                  isDense: true,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ForgotPasswordScreen(
                                        initialEmail: _emailController.text.trim(),
                                      ),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _green,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: compact ? 2 : 5,
                                    ),
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: compact ? 12 : 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 6 : 10),
                              SizedBox(
                                height: compact ? 46 : 52,
                                child: FilledButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => _handleLogin(auth),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _deepGreen,
                                    disabledBackgroundColor:
                                        _deepGreen.withValues(alpha: 0.55),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(36),
                                    ),
                                    textStyle: TextStyle(
                                      fontSize: compact ? 16 : 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Sign in'),
                                ),
                              ),
                              SizedBox(height: compact ? 11 : 17),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(color: _outline, thickness: 1.2),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 9),
                                    child: Text(
                                      'New to Smart Guardian?',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: screenWidth < 360 ? 11 : 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(color: _outline, thickness: 1.2),
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              SizedBox(
                                height: compact ? 44 : 49,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _deepGreen,
                                    side: const BorderSide(
                                      color: _deepGreen,
                                      width: 1.6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(36),
                                    ),
                                    textStyle: TextStyle(
                                      fontSize: compact ? 14 : 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Create an account'),
                                ),
                              ),
                              SizedBox(height: compact ? 9 : 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: _green,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Your information is kept secure.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: compact ? 11 : 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
