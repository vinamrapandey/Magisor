import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/editorial.dart';
import '../widgets/history_entry_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final items = storage.history;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: items.isEmpty
          ? const _EmptyState(
              icon: Icons.history,
              title: 'No history yet',
              message:
                  'Shake your mouse and ask Magisor about your screen.\nYour results will appear here.',
            )
          : CenteredPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: PageHeader(eyebrow: 'History', title: 'Past interactions.'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmClear(context, storage),
                        icon: const Icon(Icons.delete_sweep_outlined,
                            color: AppColors.textMuted, size: 18),
                        label: const Text('Clear',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...items.map((item) => HistoryEntryCard(
                        item: item,
                        onToggleSaved: () => storage.toggleSaved(item),
                        onDelete: () => storage.deleteEntry(item),
                      )),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, StorageService storage) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurface,
        title: const Text('Clear history?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Saved (starred) items are kept.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (ok == true) await storage.clearHistory();
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
