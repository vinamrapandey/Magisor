import 'package:flutter/material.dart';
import '../../core/models/saved_item.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// A glass card rendering one stored AI interaction, shared by the History
/// and Saved screens.
class HistoryEntryCard extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onToggleSaved;
  final VoidCallback onDelete;

  const HistoryEntryCard({
    super.key,
    required this.item,
    required this.onToggleSaved,
    required this.onDelete,
  });

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.providerUsed,
                    style: const TextStyle(color: AppColors.accentViolet, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.query,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _timeAgo(item.timestamp),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: item.saved ? 'Unsave' : 'Save',
                  icon: Icon(
                    item.saved ? Icons.bookmark : Icons.bookmark_border,
                    color: item.saved ? AppColors.accentCyan : AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: onToggleSaved,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
