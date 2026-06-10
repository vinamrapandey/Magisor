import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Items'), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3, // Mock data
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              child: ListTile(
                leading: const Icon(Icons.bookmark, color: AppColors.accentCyan),
                title: Text('Saved Item ${index + 1}', style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Captured text...', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          );
        },
      ),
    );
  }
}