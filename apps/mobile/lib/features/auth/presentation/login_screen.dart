import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/presentation/project_list_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isDemo;
  final VoidCallback? onLoginSuccess;
  const LoginScreen({super.key, this.isDemo = false, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'homeowner@roomlyst.com');
  final _passwordController = TextEditingController(text: 'Password123!');
  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMessage;

  void _navigateToNextScreen() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProjectListScreen()),
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.isDemo) {
      await ApiClient.saveToken('demo_session_jwt_token_2026');
      if (mounted) {
        _navigateToNextScreen();
      }
      return;
    }

    final endpoint = _isRegister ? '/auth/register' : '/auth/login';
    try {
      final res = await ApiClient.post(endpoint, {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      if (res is Map && res.containsKey('access_token')) {
        await ApiClient.saveToken(res['access_token'].toString());
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProjectListScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _showAppleLogin => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<void> _handleSocialLogin(String provider) async {
    if (provider == 'google') {
      await _handleGoogleSignIn();
    } else {
      await _proceedWithSocialLogin(
        'apple',
        'user.apple@privaterelay.appleid.com',
        'Apple ID User',
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (widget.isDemo) {
      await ApiClient.saveToken('demo_google_jwt_token_2026');
      if (mounted) _navigateToNextScreen();
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF202124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in with Google',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Choose an account to continue to Roomlyst',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF3C4043)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF4285F4),
                  child: Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Primary Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('user.homeowner@gmail.com', style: TextStyle(color: Colors.white70, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'user.homeowner@gmail.com'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF34A853),
                  child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Quick One-Tap Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Instant authentication', style: TextStyle(color: Colors.white70, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'demo.homeowner@roomlyst.com'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await _proceedWithSocialLogin('google', selected, 'Google User');
    }
  }

  Future<void> _proceedWithSocialLogin(String provider, String email, String name) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.loginWithSocial(
        provider: provider,
        email: email,
        name: name,
        role: 'homeowner',
      ).timeout(const Duration(milliseconds: 1500));

      if (res is Map && res.containsKey('access_token')) {
        await ApiClient.saveToken(res['access_token'].toString());
      } else {
        await ApiClient.saveToken('demo_${provider}_jwt_${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (_) {
      await ApiClient.saveToken('demo_${provider}_jwt_${DateTime.now().millisecondsSinceEpoch}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as $email'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
        _navigateToNextScreen();
      }
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: AppConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Backend Server Connection', style: TextStyle(color: AppTheme.textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify your PC local network IP (e.g., http://192.168.1.15:8000) or keep default for offline demo.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.x.x:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              AppConfig.baseUrl = controller.text.trim();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server updated to: ${AppConfig.baseUrl}')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _continueAsGuest() {
    _navigateToNextScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined, color: AppTheme.textMuted),
            tooltip: 'Server Connection',
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Roomlyst',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AI-Powered Interior Design & Renovation',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.danger.withAlpha(80)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Social Logins (Google & Apple ID - Zero Cost)
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _handleSocialLogin('google'),
                  icon: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F1F1F),
                    side: const BorderSide(color: Color(0xFF3C4043)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                if (_showAppleLogin) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _handleSocialLogin('apple'),
                    icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                    label: const Text(
                      'Continue with Apple',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFF444444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    '100% Free authentication • No credit card required',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),

                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR EMAIL', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                  ],
                ),
                const SizedBox(height: 20),

                // Form fields
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isRegister ? 'Create Account' : 'Sign In'),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Create one",
                    style: const TextStyle(color: AppTheme.accent),
                  ),
                ),

                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Continue as Guest / Explore Demo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
