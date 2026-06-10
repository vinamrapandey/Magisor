import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History'), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // Mock data
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              child: ListTile(
                leading: const Icon(Icons.history, color: AppColors.accentViolet),
                title: Text('Analyzed at 10:${index}0 AM', style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Summarized screen content...', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          );
        },
      ),
    );
  }
}