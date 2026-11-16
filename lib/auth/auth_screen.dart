import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// import 'phone_auth_screen.dart';
import '../core/services/api_service.dart';
import '../core/services/google_auth_service.dart';
import '../core/services/google_web_button_stub.dart'
if (dart.library.js_interop) '../core/services/google_web_button_web.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _teal = Color(0xFF00C897);
  static const Color _gold = Color(0xFFF5C211);      // website golden
  static const Color _goldSoft = Color(0xFFF3DE9A);  // light golden border
  static const Color _goldDark = Color(0xFFB58900);  // label / icon / cursor

  final _formKey = GlobalKey<FormState>();

  bool isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isSendingReset = false;
  bool _obscurePassword = true;
  bool _argsRead = false;
  String selectedRole = 'resident';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Web only: the Google button emits ID tokens through this stream.
  StreamSubscription<String>? _googleSub;

  // Landing page "Join as Resident/Vendor" opens this screen with
  // arguments {'signup': true} -> show the sign-up form directly.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['signup'] == true) {
      isLogin = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _googleSub = GoogleAuthService.instance.webIdTokens().listen(
        _completeGoogleLogin,
        onError: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _googleSub?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Golden input style (website colours): soft gold border, bright gold on focus
  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      floatingLabelStyle: const TextStyle(color: _goldDark),
      prefixIconColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.focused) ? _goldDark : Colors.grey,
      ),
      border: border(_goldSoft),
      enabledBorder: border(_goldSoft),
      focusedBorder: border(_gold, 2),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();

    if (isLogin) {
      final result = await ApiService.loginUser(
        email,
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _navigateAfterLogin(result['user'] as Map<String, dynamic>);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Login failed. Please check your email and password.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      final result = await ApiService.registerUser(
        name: _nameController.text.trim(),
        email: email,
        password: _passwordController.text.trim(),
        role: selectedRole,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Account created successfully! Please log in.'),
            backgroundColor: _teal,
          ),
        );
        setState(() => isLogin = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registration failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // MOBILE: open the native Google picker, then finish via the shared path.
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    String? idToken;
    try {
      idToken = await GoogleAuthService.instance.signInAndGetIdToken();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (idToken == null) {
      // User closed the account picker - not an error.
      if (mounted) setState(() => _isGoogleLoading = false);
      return;
    }

    await _completeGoogleLogin(idToken);
  }

  // SHARED (mobile + web): send the ID token to the backend.
  // A role is sent only on the sign-up screen; on the login screen an unknown
  // user gets `needsRole` back and is asked to pick Resident/Vendor.
  Future<void> _completeGoogleLogin(String idToken) async {
    if (mounted) setState(() => _isGoogleLoading = true);

    final result = await ApiService.googleAuth(
      idToken: idToken,
      role: isLogin ? null : selectedRole,
    );

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (result['success'] == true) {
      _navigateAfterLogin(result['user'] as Map<String, dynamic>);
    } else if (result['needsRole'] == true) {
      setState(() => isLogin = false); // reveal the Resident/Vendor picker
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose Resident or Vendor above, then tap Continue with Google again.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Google sign-in failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _navigateAfterLogin(Map<String, dynamic> user) {
    final String role = user['role'] ?? 'resident';

    if (role == 'vendor') {
      final String status = (user['status'] ?? 'pending').toString().toLowerCase();
      final bool paperworkSubmitted = user['paperwork_submitted'] ?? user['paperworkSubmitted'] ?? false;
      final bool vendorCompleted = user['vendorCompleted'] ?? false;

      if (status == 'approved') {
        if (!vendorCompleted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/register-shop', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/vendor-dashboard', (route) => false);
        }
      } else if (paperworkSubmitted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/verification-pending', (route) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/merchant-verification', (route) => false);
      }
    } else if (role == 'admin') {
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/marketplace', (route) => false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[\w.\-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first')),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    final result = await ApiService.forgotPassword(email);
    if (!mounted) return;
    setState(() => _isSendingReset = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Request failed. Please try again.'),
        backgroundColor: result['success'] == true ? _teal : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool anyLoading = _isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business_center, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Resident Connect",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLogin ? "Login to continue" : "Create your account",
                    style: const TextStyle(color: Color(0xFF5D7285), fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  if (!isLogin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _RoleOption(
                            label: 'Resident',
                            icon: Icons.home_outlined,
                            selected: selectedRole == 'resident',
                            onTap: () => setState(() => selectedRole = 'resident'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleOption(
                            label: 'Vendor',
                            icon: Icons.storefront_outlined,
                            selected: selectedRole == 'vendor',
                            onTap: () => setState(() => selectedRole = 'vendor'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      cursorColor: _goldDark,
                      decoration: _decoration(
                        selectedRole == 'vendor' ? 'Store / Owner Name' : 'Full Name',
                        Icons.person_outline,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    cursorColor: _goldDark,
                    decoration: _decoration('Email', Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[\w.\-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    cursorColor: _goldDark,
                    decoration: _decoration(
                      'Password',
                      Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),

                  if (isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (anyLoading || _isSendingReset) ? null : _handleForgotPassword,
                        child: Text(
                          _isSendingReset ? 'Sending...' : 'Forgot password?',
                          style: const TextStyle(color: _teal),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: anyLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                        isLogin ? "Login" : "Create Account",
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('or', style: TextStyle(color: Colors.grey.shade500)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google sign-in: Google's own rendered button on web,
                  // native account picker button on mobile.
                  if (kIsWeb)
                    SizedBox(
                      height: 44,
                      child: Center(child: buildGoogleWebButton()),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: anyLoading ? null : _handleGoogleSignIn,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A2B47)),
                        )
                            : Image.network(
                          'https://developers.google.com/identity/images/g-logo.png',
                          height: 20,
                          width: 20,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.login, size: 20, color: Color(0xFF1A2B47)),
                        ),
                        label: Text(
                          _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                          style: const TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE9EEF2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  // Only the teal "Sign up" / "Login" word is clickable
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: const TextStyle(color: Color(0xFF5D7285)),
                      ),
                      GestureDetector(
                        onTap: anyLoading ? null : () => setState(() => isLogin = !isLogin),
                        child: Text(
                          isLogin ? "Sign up" : "Login",
                          style: const TextStyle(color: _teal, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00C897).withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? const Color(0xFF00C897) : const Color(0xFFE9EEF2),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? const Color(0xFF00C897) : const Color(0xFF5D7285), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF00C897) : const Color(0xFF5D7285),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}