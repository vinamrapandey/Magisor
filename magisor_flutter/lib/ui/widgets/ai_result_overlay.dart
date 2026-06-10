import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/models/magisor_response.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class AIResultOverlay extends StatelessWidget {
  final bool isLoading;
  final MagisorResponse? result;
  final VoidCallback onClose;
  final Function(String followUpText) onFollowUp;

  const AIResultOverlay({
    super.key,
    required this.isLoading,
    this.result,
    required this.onClose,
    required this.onFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: const CircularProgressIndicator(color: AppColors.accentViolet)
            .animate()
            .scale(duration: 400.ms, curve: Curves.easeOutBack),
      );
    }

    if (result == null) return const SizedBox();

    return Center(
      child: GlassCard(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.accentCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Magisor (${result!.providerUsed})',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: onClose,
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              result!.summary,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
            ),
            if (result!.actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Suggested Actions:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result!.actions.map((action) => _buildActionChip(action)).toList(),
              ),
            ]
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }

  Widget _buildActionChip(String label) {
    return InkWell(
      onTap: () => onFollowUp(label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentViolet.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentViolet.withOpacity(0.5)),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.accentViolet, fontSize: 12)),
      ),
    );
  }
}