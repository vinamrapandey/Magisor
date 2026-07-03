import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/editorial.dart';
import '../widgets/history_entry_card.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final items = storage.saved;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: items.isEmpty
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.bookmark_border, color: AppColors.textMuted, size: 48),
                      SizedBox(height: 16),
                      Text('No saved items',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text(
                        'Tap the bookmark on any history entry\nto keep it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : CenteredPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(eyebrow: 'Saved', title: 'Your bookmarks.'),
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
}
