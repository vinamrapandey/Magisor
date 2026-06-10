import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      final auth = context.read<AuthService>();
      if (_isLogin) {
        await auth.signInWithEmail(_emailCtrl.text, _passCtrl.text);
      } else {
        await auth.signUpWithEmail(_emailCtrl.text, _passCtrl.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: GlassCard(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isLogin = true),
                    child: Text('Login', style: TextStyle(color: _isLogin ? AppColors.accentViolet : AppColors.textMuted)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = false),
                    child: Text('Sign Up', style: TextStyle(color: !_isLogin ? AppColors.accentCyan : AppColors.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentViolet),
                child: Text(_isLogin ? 'Login' : 'Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}