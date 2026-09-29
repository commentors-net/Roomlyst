import 'package:flutter/material.dart';
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

  Future<void> _handleSocialLogin(String provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.isDemo) {
      await ApiClient.saveToken('demo_${provider}_jwt_token_2026');
      if (mounted) {
        _navigateToNextScreen();
      }
      return;
    }

    final defaultEmail = provider == 'google' ? 'user.homeowner@gmail.com' : 'user.apple@privaterelay.appleid.com';
    final defaultName = provider == 'google' ? 'Google Account User' : 'Apple ID User';

    try {
      final res = await ApiClient.loginWithSocial(
        provider: provider,
        email: defaultEmail,
        name: defaultName,
        role: 'homeowner',
      ).timeout(const Duration(milliseconds: 500));

      if (res is Map && res.containsKey('access_token')) {
        await ApiClient.saveToken(res['access_token'].toString());
      } else {
        // Fallback demo token if offline
        await ApiClient.saveToken('demo_${provider}_jwt_token_2026');
      }

      if (mounted) {
        _navigateToNextScreen();
      }
    } catch (_) {
      // In offline / standalone mobile demo mode, gracefully issue authenticated token
      await ApiClient.saveToken('demo_${provider}_jwt_token_2026');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in via ${provider == 'google' ? 'Google' : 'Apple ID'} (Offline Demo Mode)'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.accent,
          ),
        );
        _navigateToNextScreen();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continueAsGuest() {
    _navigateToNextScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
