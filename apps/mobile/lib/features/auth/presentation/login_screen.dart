import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/presentation/project_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'homeowner@roomlyst.com');
  final _passwordController = TextEditingController(text: 'Password123!');
  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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

  void _continueAsGuest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProjectListScreen()),
    );
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
                const SizedBox(height: 36),

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

                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                  ],
                ),
                const SizedBox(height: 16),

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
