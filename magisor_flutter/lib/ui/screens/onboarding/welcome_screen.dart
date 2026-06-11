import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.backgroundPrimary, Color(0xFF1E1E2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .tint(color: AppColors.accentViolet.withOpacity(0.2), duration: 4.seconds),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'MAGISOR',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),
                const SizedBox(height: 60),
                GlassCard(
                  width: 300,
                  child: Column(
                    children: [
                      _buildAuthButton(
                        icon: Icons.email,
                        label: 'Email and Password',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                        },
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          final auth = context.read<AuthService>();
                          await auth.signInAsGuest();
                        },
                        child: const Text(
                          'Continue without account',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}